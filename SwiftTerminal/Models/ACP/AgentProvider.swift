import SwiftUI

enum AgentProvider: String, Codable, CaseIterable {
    case claude = "Claude"
    case codex = "Codex"

    var acpPackage: String {
        switch self {
        case .claude: return "@agentclientprotocol/claude-agent-acp@latest"
        case .codex: return "@zed-industries/codex-acp@latest"
        }
    }

    var imageName: String {
        switch self {
        case .claude: return "claude.symbols"
        case .codex: return "openai.symbols"
        }
    }

    var color: Color {
        switch self {
        case .claude: return Color(red: 0.84, green: 0.41, blue: 0.23)
        case .codex: return Color(red: 0.0, green: 0.58, blue: 0.48)
        }
    }
}
