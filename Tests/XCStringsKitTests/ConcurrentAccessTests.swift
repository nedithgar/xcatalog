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

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await XCStringsFileAccessCoordinator.withExclusiveAccess(to: path) {
                    Thread.sleep(forTimeInterval: 0.2)
                }
            }

            try await Task.sleep(nanoseconds: 20_000_000)

            do {
                try await XCStringsFileAccessCoordinator.withExclusiveAccess(to: path, wait: false) {}
                Issue.record("Expected a concurrent write conflict")
            } catch let error as XCStringsError {
                guard case let .concurrentWriteConflict(conflictPath) = error else {
                    Issue.record("Expected concurrentWriteConflict, got \(error)")
                    try await group.waitForAll()
                    return
                }
                #expect(conflictPath == XCStringsFileAccessCoordinator.canonicalPath(path))
            }

            try await group.waitForAll()
        }
    }
}
