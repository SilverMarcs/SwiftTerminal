import Foundation
import SwiftData

enum ChatProvider: String, Codable {
    case claude
    case codex
}

@Model
final class ChatSession {
    var id = UUID()
    var externalSessionID: String?
    var name: String?
    var createdAt: Date = Date()
    var providerRaw: String = ChatProvider.claude.rawValue

    var workspace: Workspace

    @Attribute(.ephemeral) var hasNotification = false

    @Transient var service: ClaudeService?

    var provider: ChatProvider {
        get { ChatProvider(rawValue: providerRaw) ?? .claude }
        set { providerRaw = newValue.rawValue }
    }

    var workingDirectory: String { workspace.directory }

    init(workspace: Workspace, provider: ChatProvider = .claude) {
        self.workspace = workspace
        self.providerRaw = provider.rawValue
    }

    /// Returns the existing service or creates one on first access.
    func resolveService() -> ClaudeService {
        if let service { return service }
        let s = ClaudeService(chatSession: self)
        service = s
        return s
    }
}
