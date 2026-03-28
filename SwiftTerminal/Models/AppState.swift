import SwiftUI
import SwiftData

// MARK: - Sidebar Selection

enum SidebarSelection: Hashable {
    case workspace(UUID)
    case session(workspaceID: UUID, sessionID: UUID)

    var workspaceID: UUID {
        switch self {
        case .workspace(let id): id
        case .session(let id, _): id
        }
    }
}

// MARK: - App State

@Observable
final class AppState {
    var sidebarSelection: SidebarSelection?

    // Inspector state
    var showingInspector = true
    var selectedInspectorTab: InspectorTab = .files
    var searchFocusToken: UUID?
    var inspectorWidth: CGFloat = 0

    /// Bumped by Cmd+J; observed by WorkspaceDetailView to toggle the editor panel.
    var panelToggleToken = UUID()
}
