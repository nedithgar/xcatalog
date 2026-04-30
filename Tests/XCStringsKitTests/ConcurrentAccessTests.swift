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
                try await XCStringsFileAccessCoordinator.withExclusiveAccess(to: path) { _ in
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
                try await XCStringsFileAccessCoordinator.withExclusiveAccess(to: path, wait: false) { _ in }
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

    @Test("Symlink aliases use the same exclusive access lock")
    func symlinkAliasesUseSameExclusiveAccessLock() async throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("symlink_access_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let realURL = tempDir.appendingPathComponent("Catalog.xcstrings")
        try TestFixtures.empty.write(to: realURL, atomically: true, encoding: .utf8)

        let symlinkURL = tempDir.appendingPathComponent("CatalogLink.xcstrings")
        try fileManager.createSymbolicLink(at: symlinkURL, withDestinationURL: realURL)

        let realPath = realURL.path
        let symlinkPath = symlinkURL.path
        let canonicalPath = XCStringsFileAccessCoordinator.canonicalPath(realPath)
        #expect(XCStringsFileAccessCoordinator.canonicalPath(symlinkPath) == canonicalPath)

        try await XCStringsFileAccessCoordinator.withExclusiveAccess(to: realPath) { _ in
            do {
                try await XCStringsFileAccessCoordinator.withExclusiveAccess(to: symlinkPath, wait: false) { _ in }
                Issue.record("Expected a concurrent write conflict for \(canonicalPath) through symlink alias")
            } catch let error as XCStringsError {
                guard case let .concurrentWriteConflict(conflictPath) = error else {
                    Issue.record("Expected concurrentWriteConflict for \(canonicalPath), got \(error)")
                    return
                }
                #expect(conflictPath == canonicalPath)
            }
        }
    }

    @Test("Writes through catalog symlink update resolved catalog")
    func writesThroughCatalogSymlinkUpdateResolvedCatalog() async throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("symlink_write_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let realURL = tempDir.appendingPathComponent("Catalog.xcstrings")
        try TestFixtures.empty.write(to: realURL, atomically: true, encoding: .utf8)

        let symlinkURL = tempDir.appendingPathComponent("CatalogLink.xcstrings")
        try fileManager.createSymbolicLink(at: symlinkURL, withDestinationURL: realURL)

        let symlinkParser = XCStringsParser(path: symlinkURL.path)
        try await symlinkParser.addTranslation(
            key: "sample.symlink",
            language: "es",
            value: "Valor"
        )

        let realParser = XCStringsParser(path: realURL.path)
        let translations = try await realParser.getTranslation(key: "sample.symlink", language: "es")
        #expect(translations["es"]?.value == "Valor")
        #expect((try? fileManager.destinationOfSymbolicLink(atPath: symlinkURL.path)) == realURL.path)
    }

    @Test("Canonical path resolves symlinked parent for new catalog paths")
    func canonicalPathResolvesSymlinkedParentForNewCatalogPaths() throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("symlink_parent_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let realDirectory = tempDir.appendingPathComponent("real", isDirectory: true)
        let symlinkDirectory = tempDir.appendingPathComponent("link", isDirectory: true)
        try fileManager.createDirectory(at: realDirectory, withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(at: symlinkDirectory, withDestinationURL: realDirectory)

        let realPath = realDirectory.appendingPathComponent("NewCatalog.xcstrings").path
        let symlinkPath = symlinkDirectory.appendingPathComponent("NewCatalog.xcstrings").path
        let realCanonicalPath = XCStringsFileAccessCoordinator.canonicalPath(realPath)
        let symlinkCanonicalPath = XCStringsFileAccessCoordinator.canonicalPath(symlinkPath)

        #expect(symlinkCanonicalPath == realCanonicalPath)
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
            try await XCStringsFileAccessCoordinator.withExclusiveAccess(to: path) { _ in
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
            try await XCStringsFileAccessCoordinator.withExclusiveAccess(to: path) { _ in
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

        try await XCStringsFileAccessCoordinator.withExclusiveAccess(to: path, wait: false) { _ in }
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
