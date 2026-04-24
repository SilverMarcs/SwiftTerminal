import SwiftUI

@Observable
final class AppState {
    var selectedWorkspace: Workspace?
    var selectedChat: Chat?

    // Sidebar expansion state
    var expandedWorkspaceIDs: Set<String> = []

    // Inspector state
    var showingInspector = true
}
