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
        await base.waitUntilFirstSendStarts()
        let secondSend = Task {
            try await transport.send(Data("second".utf8))
        }

        try await firstSend.value
        try await secondSend.value

        let snapshot = await base.snapshot()
        #expect(snapshot.messages == ["first", "second"])
        #expect(snapshot.maximumActiveSends == 1)
    }

    @Test("later sends recover after a failed send")
    func laterSendsRecoverAfterFailedSend() async throws {
        let base = FailingThenRecordingTransport()
        let transport = SerialOutboundTransport(
            base: base,
            inboundMessages: await base.receive(),
            logger: base.logger
        )

        let firstSend = Task {
            try await transport.send(Data("first".utf8))
        }
        await base.waitUntilFirstSendStarts()

        await #expect(throws: TestSendError.self) {
            try await firstSend.value
        }

        try await transport.send(Data("second".utf8))

        let messages = await base.snapshot()
        #expect(messages == ["second"])
    }

    @Test("queued sends proceed after an earlier send fails")
    func queuedSendsProceedAfterEarlierSendFails() async throws {
        let base = FailingThenRecordingTransport()
        let transport = SerialOutboundTransport(
            base: base,
            inboundMessages: await base.receive(),
            logger: base.logger
        )

        let firstSend = Task {
            try await transport.send(Data("first".utf8))
        }
        await base.waitUntilFirstSendStarts()
        let secondSend = Task {
            try await transport.send(Data("second".utf8))
        }

        await #expect(throws: TestSendError.self) {
            try await firstSend.value
        }
        try await secondSend.value

        let messages = await base.snapshot()
        #expect(messages == ["second"])
    }
}

private actor ReentrantRecordingTransport: Transport {
    private let inboundMessages: AsyncThrowingStream<Data, Swift.Error>
    private var activeSends = 0
    private var maximumActiveSends = 0
    private var messages: [String] = []
    private var firstSendDidStart = false
    private var firstSendStartedContinuation: CheckedContinuation<Void, Never>?

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

    func waitUntilFirstSendStarts() async {
        if firstSendDidStart {
            return
        }

        await withCheckedContinuation { continuation in
            if firstSendDidStart {
                continuation.resume()
            } else {
                firstSendStartedContinuation = continuation
            }
        }
    }

    func send(_ data: Data) async throws {
        activeSends += 1
        maximumActiveSends = max(maximumActiveSends, activeSends)

        if !firstSendDidStart {
            firstSendDidStart = true
            firstSendStartedContinuation?.resume()
            firstSendStartedContinuation = nil
        }

        try await Task.sleep(for: .milliseconds(25))
        messages.append(String(decoding: data, as: UTF8.self))
        activeSends -= 1
    }

    func snapshot() -> (messages: [String], maximumActiveSends: Int) {
        (messages, maximumActiveSends)
    }
}

private actor FailingThenRecordingTransport: Transport {
    private let inboundMessages: AsyncThrowingStream<Data, Swift.Error>
    private var attemptCount = 0
    private var messages: [String] = []
    private var firstSendDidStart = false
    private var firstSendStartedContinuation: CheckedContinuation<Void, Never>?

    nonisolated let logger = Logger(label: "xcatalog.tests.failing-then-recording-transport")

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

    func waitUntilFirstSendStarts() async {
        if firstSendDidStart {
            return
        }

        await withCheckedContinuation { continuation in
            if firstSendDidStart {
                continuation.resume()
            } else {
                firstSendStartedContinuation = continuation
            }
        }
    }

    func send(_ data: Data) async throws {
        attemptCount += 1

        if attemptCount == 1 {
            if !firstSendDidStart {
                firstSendDidStart = true
                firstSendStartedContinuation?.resume()
                firstSendStartedContinuation = nil
            }

            try await Task.sleep(for: .milliseconds(25))
            throw TestSendError.expectedFailure
        }

        messages.append(String(decoding: data, as: UTF8.self))
    }

    func snapshot() -> [String] {
        messages
    }
}

private enum TestSendError: Error {
    case expectedFailure
}
