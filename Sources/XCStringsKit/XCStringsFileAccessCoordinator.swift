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
        operation: @Sendable (_ resolvedPath: String) throws -> T
    ) async throws -> T {
        let canonicalPath = canonicalPath(path)
        try await XCStringsFileAccessRegistry.shared.acquire(path: canonicalPath, wait: wait)

        do {
            try Task.checkCancellation()
            let result = try operation(canonicalPath)
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
        operation: @Sendable (_ resolvedPath: String) async throws -> T
    ) async throws -> T {
        let canonicalPath = canonicalPath(path)
        try await XCStringsFileAccessRegistry.shared.acquire(path: canonicalPath, wait: wait)

        do {
            try Task.checkCancellation()
            let result = try await operation(canonicalPath)
            await XCStringsFileAccessRegistry.shared.release(path: canonicalPath)
            return result
        } catch {
            await XCStringsFileAccessRegistry.shared.release(path: canonicalPath)
            throw error
        }
    }

    package static func canonicalPath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return canonicalURL(for: url).path
    }

    package static func queuedWaiterCount(for path: String) async -> Int {
        let canonicalPath = canonicalPath(path)
        return await XCStringsFileAccessRegistry.shared.queuedWaiterCount(path: canonicalPath)
    }

    private static func canonicalURL(for url: URL) -> URL {
        let fileManager = FileManager.default
        var candidate = url
        var missingComponents: [String] = []
        var visitedSymlinks: Set<String> = []

        // Create operations may target a file that does not exist yet, so resolve
        // symlinks through the deepest existing ancestor and then append the rest.
        while !fileManager.fileExists(atPath: candidate.path) {
            if let destination = try? fileManager.destinationOfSymbolicLink(atPath: candidate.path) {
                guard visitedSymlinks.insert(candidate.standardizedFileURL.path).inserted else {
                    return url.standardizedFileURL
                }
                candidate = symlinkDestinationURL(destination, relativeTo: candidate.deletingLastPathComponent())
                continue
            }

            let parent = candidate.deletingLastPathComponent()
            guard parent.path != candidate.path else {
                return url.standardizedFileURL
            }

            missingComponents.insert(candidate.lastPathComponent, at: 0)
            candidate = parent
        }

        var resolved = candidate.resolvingSymlinksInPath()
        for component in missingComponents {
            resolved.appendPathComponent(component)
        }
        return resolved.standardizedFileURL
    }

    private static func symlinkDestinationURL(_ destination: String, relativeTo parent: URL) -> URL {
        if destination.hasPrefix("/") {
            URL(fileURLWithPath: destination)
        } else {
            parent.appendingPathComponent(destination)
        }
    }
}

private struct XCStringsFileAccessWaiter: Sendable {
    let id: UUID
    let continuation: CheckedContinuation<Void, any Error>
}

private struct XCStringsFileAccessState {
    var isLocked = false
    var waiters: [XCStringsFileAccessWaiter] = []
}

private actor XCStringsFileAccessRegistry {
    static let shared = XCStringsFileAccessRegistry()

    private var states: [String: XCStringsFileAccessState] = [:]

    func acquire(path: String, wait: Bool) async throws {
        try Task.checkCancellation()

        var state = states[path] ?? XCStringsFileAccessState()

        guard state.isLocked else {
            state.isLocked = true
            states[path] = state
            return
        }

        guard wait else {
            throw XCStringsError.concurrentWriteConflict(path: path)
        }

        let waiterID = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                var queuedState = states[path] ?? XCStringsFileAccessState(isLocked: true)
                queuedState.isLocked = true
                queuedState.waiters.append(
                    XCStringsFileAccessWaiter(id: waiterID, continuation: continuation)
                )
                states[path] = queuedState
            }
        } onCancel: {
            Task {
                await XCStringsFileAccessRegistry.shared.cancelWaiter(path: path, id: waiterID)
            }
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
        next.continuation.resume()
    }

    func cancelWaiter(path: String, id: UUID) {
        guard var state = states[path],
              let waiterIndex = state.waiters.firstIndex(where: { $0.id == id }) else {
            return
        }

        let waiter = state.waiters.remove(at: waiterIndex)
        if state.isLocked || !state.waiters.isEmpty {
            states[path] = state
        } else {
            states.removeValue(forKey: path)
        }
        waiter.continuation.resume(throwing: CancellationError())
    }

    func queuedWaiterCount(path: String) -> Int {
        states[path]?.waiters.count ?? 0
    }
}
