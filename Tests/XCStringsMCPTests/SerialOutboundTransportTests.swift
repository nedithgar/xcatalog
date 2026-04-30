import Foundation
import Logging
import MCP
import Testing

@testable import XCStringsMCP

@Suite("Serial outbound transport tests")
struct SerialOutboundTransportTests {
    @Test("send calls do not overlap when the wrapped transport suspends")
    func sendsDoNotOverlapWhenWrappedTransportSuspends() async throws {
        let base = ReentrantRecordingTransport()
        let transport = SerialOutboundTransport(
            base: base,
            inboundMessages: await base.receive(),
            logger: base.logger
        )

        let firstSend = Task {
            try await transport.send(Data("first".utf8))
        }
        try await Task.sleep(for: .milliseconds(5))
        let secondSend = Task {
            try await transport.send(Data("second".utf8))
        }

        try await firstSend.value
        try await secondSend.value

        let snapshot = await base.snapshot()
        #expect(snapshot.messages == ["first", "second"])
        #expect(snapshot.maximumActiveSends == 1)
    }
}

private actor ReentrantRecordingTransport: Transport {
    private let inboundMessages: AsyncThrowingStream<Data, Swift.Error>
    private var activeSends = 0
    private var maximumActiveSends = 0
    private var messages: [String] = []

    nonisolated let logger = Logger(label: "xcatalog.tests.reentrant-recording-transport")

    init() {
        inboundMessages = AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func connect() async throws {}

    func disconnect() async {}

    func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        inboundMessages
    }

    func send(_ data: Data) async throws {
        activeSends += 1
        maximumActiveSends = max(maximumActiveSends, activeSends)
        try await Task.sleep(for: .milliseconds(25))
        messages.append(String(decoding: data, as: UTF8.self))
        activeSends -= 1
    }

    func snapshot() -> (messages: [String], maximumActiveSends: Int) {
        (messages, maximumActiveSends)
    }
}
