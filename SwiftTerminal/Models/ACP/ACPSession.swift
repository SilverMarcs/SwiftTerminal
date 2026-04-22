import Foundation
import ACP

@Observable
final class ACPSession {
    var isConnected = false
    var isConnecting = false
    var isProcessing = false
    var error: String?
    var provider: AgentProvider = .codex
    var sessionTitle: String?

    var onTurnComplete: (() async -> Void)?
    var onSessionIdChanged: ((String) -> Void)?
    var onTitleChanged: ((String) -> Void)?
    var onSessionUpdate: ((SessionUpdate) -> Void)?

    @ObservationIgnored private(set) var client: Client?
    @ObservationIgnored private(set) var sessionId: SessionId?
    @ObservationIgnored var notificationTask: Task<Void, Never>?
    @ObservationIgnored private(set) var workingDirectory: String = ""
    @ObservationIgnored let autoApproveDelegate = AutoApproveDelegate()

    func connect(workingDirectory: String) {
        self.workingDirectory = workingDirectory
        Task {
            await launchAndCreateSession()
        }
    }

    func disconnect() {
        notificationTask?.cancel()
        notificationTask = nil
        onTurnComplete = nil
        onSessionIdChanged = nil
        onTitleChanged = nil
        onSessionUpdate = nil
        let clientToTerminate = client
        client = nil
        sessionId = nil
        isConnected = false
        sessionTitle = nil
        Task {
            await clientToTerminate?.terminate()
        }
    }

    func stopStreaming() {
        guard let client, let sessionId else { return }
        isProcessing = false
        Task {
            try? await client.cancelSession(sessionId: sessionId)
        }
    }

    func send(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let client, let sessionId else {
            error = "Not connected"
            return
        }

        isProcessing = true

        Task {
            do {
                let content: [ContentBlock] = [.text(TextContent(text: text))]
                _ = try await client.sendPrompt(sessionId: sessionId, content: content)
                isProcessing = false
                await onTurnComplete?()
            } catch {
                isProcessing = false
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Session Discovery

    /// Lists existing sessions for the given working directory.
    /// Requires a running, initialized client.
    func listExistingSessions(workingDirectory: String) async throws -> [SessionInfo] {
        let tempClient = try await launchAndInitialize()
        defer {
            Task { await tempClient.terminate() }
        }
        let response = try await tempClient.listSessions(cwd: workingDirectory, timeout: 30)
        return response.sessions
    }

    // MARK: - Internal Setters

    func setClient(_ client: Client?) {
        self.client = client
    }

    func setSessionId(_ id: SessionId?) {
        self.sessionId = id
        if let value = id?.value {
            onSessionIdChanged?(value)
        }
    }

    func setWorkingDirectory(_ dir: String) {
        self.workingDirectory = dir
    }
}
