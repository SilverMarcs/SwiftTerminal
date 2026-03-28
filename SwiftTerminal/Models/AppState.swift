import SwiftUI

@Observable
final class AppState {
    var selectedSession: ClaudeSession?

    // Inspector state
    var showingInspector = true
    var selectedInspectorTab: InspectorTab = .files
    var searchFocusToken: UUID?
    var inspectorWidth: CGFloat = 0

    /// Bumped by Cmd+J; observed by SessionDetailView to toggle the editor panel.
    var panelToggleToken = UUID()
}
