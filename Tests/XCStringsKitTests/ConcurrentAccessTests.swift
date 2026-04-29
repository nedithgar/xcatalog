import Foundation
import Testing
@testable import XCStringsKit

@Suite("Thread safety for concurrent catalog access")
struct ConcurrentAccessTests {
    @Test("Concurrent reads are safe")
    func concurrentReads() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.manyKeys)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)

        // Perform concurrent reads
        await withTaskGroup(of: [String].self) { group in
            for _ in 0 ..< 10 {
                group.addTask {
                    (try? await parser.listKeys()) ?? []
                }
            }

            var results: [[String]] = []
            for await result in group {
                results.append(result)
            }

            // All results should be identical
            let first = results.first ?? []
            for result in results {
                #expect(result == first)
            }
        }
    }

    @Test("Concurrent writes through separate parser instances preserve every change")
    func concurrentWritesThroughSeparateParserInstancesAreSerialized() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.empty)
        defer { TestHelper.removeTempFile(at: path) }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0 ..< 50 {
                group.addTask {
                    let parser = XCStringsParser(path: path)
                    try await parser.addTranslation(
                        key: "sample.concurrent.\(index)",
                        language: "es",
                        value: "Valor \(index)"
                    )
                }
            }

            try await group.waitForAll()
        }

        let parser = XCStringsParser(path: path)
        let keys = try await parser.listKeys()
        #expect(keys.count == 50)

        for index in 0 ..< 50 {
            let translations = try await parser.getTranslation(key: "sample.concurrent.\(index)", language: "es")
            #expect(translations["es"]?.value == "Valor \(index)")
        }
    }

    @Test("Nonblocking exclusive access reports a retryable conflict")
    func nonblockingExclusiveAccessReportsRetryableConflict() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.empty)
        defer { TestHelper.removeTempFile(at: path) }

        let lockEntered = AsyncStream<Void>.makeStream()
        let releaseLock = AsyncStream<Void>.makeStream()
        let canonicalPath = XCStringsFileAccessCoordinator.canonicalPath(path)

        try await withThrowingTaskGroup(of: Void.self) { group in
            func releaseLockHolder() {
                releaseLock.continuation.yield(())
                releaseLock.continuation.finish()
            }

            group.addTask {
                try await XCStringsFileAccessCoordinator.withExclusiveAccess(to: path) {
                    lockEntered.continuation.yield(())
                    lockEntered.continuation.finish()
                    _ = await Self.waitForSignal(releaseLock.stream)
                }
            }

            guard await Self.waitForSignal(lockEntered.stream) else {
                Issue.record("Timed out waiting for exclusive access to start for \(canonicalPath)")
                releaseLockHolder()
                try await group.waitForAll()
                return
            }

            do {
                try await XCStringsFileAccessCoordinator.withExclusiveAccess(to: path, wait: false) {}
                Issue.record("Expected a concurrent write conflict for \(canonicalPath) after the lock holder signaled entry")
            } catch let error as XCStringsError {
                guard case let .concurrentWriteConflict(conflictPath) = error else {
                    Issue.record("Expected concurrentWriteConflict for \(canonicalPath), got \(error)")
                    releaseLockHolder()
                    try await group.waitForAll()
                    return
                }
                #expect(conflictPath == canonicalPath)
            } catch {
                releaseLockHolder()
                try await group.waitForAll()
                throw error
            }

            releaseLockHolder()
            try await group.waitForAll()
        }
    }

    @Test("Cancelled queued exclusive access does not run its write operation")
    func cancelledQueuedExclusiveAccessDoesNotRunWriteOperation() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.empty)
        defer { TestHelper.removeTempFile(at: path) }

        let lockEntered = AsyncStream<Void>.makeStream()
        let releaseLock = AsyncStream<Void>.makeStream()
        let operationProbe = ExclusiveAccessOperationProbe()

        func releaseLockHolder() {
            releaseLock.continuation.yield(())
            releaseLock.continuation.finish()
        }

        let lockHolder = Task {
            try await XCStringsFileAccessCoordinator.withExclusiveAccess(to: path) {
                lockEntered.continuation.yield(())
                lockEntered.continuation.finish()
                _ = await Self.waitForSignal(releaseLock.stream)
            }
        }

        guard await Self.waitForSignal(lockEntered.stream) else {
            Issue.record("Timed out waiting for exclusive access holder to start")
            releaseLockHolder()
            try await lockHolder.value
            return
        }

        let queuedWriter = Task {
            try await XCStringsFileAccessCoordinator.withExclusiveAccess(to: path) {
                await operationProbe.markOperationRan()
            }
        }

        guard await Self.waitForQueuedWaiters(path: path, count: 1) else {
            Issue.record("Timed out waiting for queued exclusive access waiter")
            queuedWriter.cancel()
            releaseLockHolder()
            try? await queuedWriter.value
            try await lockHolder.value
            return
        }

        queuedWriter.cancel()

        guard await Self.waitForQueuedWaiters(path: path, count: 0) else {
            Issue.record("Timed out waiting for cancelled waiter to leave the queue")
            releaseLockHolder()
            try? await queuedWriter.value
            try await lockHolder.value
            return
        }

        do {
            try await queuedWriter.value
            Issue.record("Expected queued writer to throw CancellationError")
        } catch is CancellationError {
            #expect(await operationProbe.didRun == false)
        } catch {
            Issue.record("Expected CancellationError from queued writer, got \(error)")
        }

        releaseLockHolder()
        try await lockHolder.value

        try await XCStringsFileAccessCoordinator.withExclusiveAccess(to: path, wait: false) {}
    }

    private static func waitForSignal(
        _ stream: AsyncStream<Void>,
        timeoutNanoseconds: UInt64 = 1_000_000_000
    ) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                return await iterator.next() != nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return false
            }

            let signaled = await group.next() ?? false
            group.cancelAll()
            return signaled
        }
    }

    private static func waitForQueuedWaiters(
        path: String,
        count expectedCount: Int,
        timeoutNanoseconds: UInt64 = 1_000_000_000
    ) async -> Bool {
        let deadline = ContinuousClock.now + .nanoseconds(Int(timeoutNanoseconds))

        while ContinuousClock.now < deadline {
            let queuedCount = await XCStringsFileAccessCoordinator.queuedWaiterCount(for: path)
            if queuedCount == expectedCount {
                return true
            }

            await Task.yield()
        }

        return await XCStringsFileAccessCoordinator.queuedWaiterCount(for: path) == expectedCount
    }
}

private actor ExclusiveAccessOperationProbe {
    private var operationRan = false

    var didRun: Bool {
        operationRan
    }

    func markOperationRan() {
        operationRan = true
    }
}
