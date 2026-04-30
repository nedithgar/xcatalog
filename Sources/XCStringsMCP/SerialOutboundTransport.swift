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
    private var sendTail: Task<Void, Swift.Error>?

    nonisolated let logger: Logger

    init(
        base: any Transport,
        inboundMessages: AsyncThrowingStream<Data, Swift.Error>,
        logger: Logger
    ) {
        self.base = base
        self.inboundMessages = inboundMessages
        self.logger = logger
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
        let previousSend = sendTail
        let base = self.base
        let currentSend = Task {
            if let previousSend {
                try await previousSend.value
            }

            try await base.send(data)
        }

        sendTail = currentSend
        try await currentSend.value
    }
}
