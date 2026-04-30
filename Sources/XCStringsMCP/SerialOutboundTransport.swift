import Foundation
import Logging
import MCP

/// Wraps an MCP transport so only one outbound message is in flight at a time.
///
/// `StdioTransport` uses nonblocking stdout writes. Large responses can suspend
/// after a partial write, and actor reentrancy then allows another response to
/// start writing before the first message finishes. Chaining sends here keeps
/// each JSON-RPC line contiguous on stdout.
actor SerialOutboundTransport: Transport {
    private let base: any Transport
    private let inboundMessages: AsyncThrowingStream<Data, Swift.Error>
    private let sendDidQueue: (@Sendable (Int) async -> Void)?
    private var nextSendID = 0
    private var sendTail: (id: Int, task: Task<Void, Swift.Error>)?

    nonisolated let logger: Logger

    init(
        base: any Transport,
        inboundMessages: AsyncThrowingStream<Data, Swift.Error>,
        logger: Logger,
        sendDidQueue: (@Sendable (Int) async -> Void)? = nil
    ) {
        self.base = base
        self.inboundMessages = inboundMessages
        self.logger = logger
        self.sendDidQueue = sendDidQueue
    }

    func connect() async throws {
        try await base.connect()
    }

    func disconnect() async {
        await base.disconnect()
    }

    func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        inboundMessages
    }

    func send(_ data: Data) async throws {
        let previousSend = sendTail?.task
        let base = self.base
        let sendID = nextSendID
        nextSendID += 1
        let currentSend = Task {
            if let previousSend {
                do {
                    try await previousSend.value
                } catch {
                    // A failed predecessor should not poison later sends.
                }
            }

            try await base.send(data)
        }

        sendTail = (id: sendID, task: currentSend)
        if let sendDidQueue {
            await sendDidQueue(sendID)
        }

        // Await the underlying task's completion via `.result` so caller
        // cancellation cannot surface a `CancellationError` here while
        // `base.send(data)` is still writing. Releasing `sendTail` before the
        // inner task finishes would let the next `send(_:)` interleave bytes
        // on stdout, breaking the single-in-flight guarantee this type exists
        // to provide.
        let result = await currentSend.result

        if sendTail?.id == sendID {
            sendTail = nil
        }

        try result.get()
    }
}
