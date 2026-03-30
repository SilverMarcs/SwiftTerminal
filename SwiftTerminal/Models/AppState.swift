import SwiftUI

@Observable
final class AppState {
    var selectedTerminal: TerminalTab?

    // Inspector state
    var showingInspector = true
    var selectedInspectorTab: InspectorTab = .files
}
