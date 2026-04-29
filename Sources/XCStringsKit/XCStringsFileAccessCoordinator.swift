import Foundation

/// Coordinates package-level write access to catalog files.
///
/// `XCStringsParser` is an actor, but MCP and CLI requests commonly create a
/// fresh parser per tool call. This coordinator serializes writes by canonical
/// file path so independent parser instances cannot race through
/// load-modify-save cycles for the same catalog.
package enum XCStringsFileAccessCoordinator {
    package static func withExclusiveAccess<T: Sendable>(
        to path: String,
        wait: Bool = true,
        operation: @Sendable () throws -> T
    ) async throws -> T {
        let canonicalPath = canonicalPath(path)
        try await XCStringsFileAccessRegistry.shared.acquire(path: canonicalPath, wait: wait)

        do {
            let result = try operation()
            await XCStringsFileAccessRegistry.shared.release(path: canonicalPath)
            return result
        } catch {
            await XCStringsFileAccessRegistry.shared.release(path: canonicalPath)
            throw error
        }
    }

    package static func withExclusiveAccess<T: Sendable>(
        to path: String,
        wait: Bool = true,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        let canonicalPath = canonicalPath(path)
        try await XCStringsFileAccessRegistry.shared.acquire(path: canonicalPath, wait: wait)

        do {
            let result = try await operation()
            await XCStringsFileAccessRegistry.shared.release(path: canonicalPath)
            return result
        } catch {
            await XCStringsFileAccessRegistry.shared.release(path: canonicalPath)
            throw error
        }
    }

    package static func canonicalPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}

private struct XCStringsFileAccessState {
    var isLocked = false
    var waiters: [CheckedContinuation<Void, Never>] = []
}

private actor XCStringsFileAccessRegistry {
    static let shared = XCStringsFileAccessRegistry()

    private var states: [String: XCStringsFileAccessState] = [:]

    func acquire(path: String, wait: Bool) async throws {
        var state = states[path] ?? XCStringsFileAccessState()

        guard state.isLocked else {
            state.isLocked = true
            states[path] = state
            return
        }

        guard wait else {
            throw XCStringsError.concurrentWriteConflict(path: path)
        }

        await withCheckedContinuation { continuation in
            var queuedState = states[path] ?? XCStringsFileAccessState(isLocked: true)
            queuedState.isLocked = true
            queuedState.waiters.append(continuation)
            states[path] = queuedState
        }
    }

    func release(path: String) {
        guard var state = states[path], state.isLocked else {
            return
        }

        guard !state.waiters.isEmpty else {
            states.removeValue(forKey: path)
            return
        }

        let next = state.waiters.removeFirst()
        state.isLocked = true
        states[path] = state
        next.resume()
    }
}
