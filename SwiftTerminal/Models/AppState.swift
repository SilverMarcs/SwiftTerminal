import SwiftUI

enum SidebarSelection: Hashable {
    case workspace(Workspace)
    case session(ClaudeSession)
}

@Observable
final class AppState {
    var selectedItem: SidebarSelection?

    var selectedSession: ClaudeSession? {
        if case .session(let session) = selectedItem {
            return session
        }
        return nil
    }

    // Inspector state
    var showingInspector = true
    var selectedInspectorTab: InspectorTab = .files

    /// Bumped by Cmd+J; observed by SessionDetailView to toggle the editor panel.
    var panelToggleToken = UUID()
}
