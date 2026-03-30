import SwiftUI

struct SidebarSelection: Hashable {
    let workspace: Workspace
    var terminal: Terminal?
}

@Observable
final class AppState {
    var selection: SidebarSelection?

    var selectedWorkspace: Workspace? { selection?.workspace }
    var selectedTerminal: Terminal? { selection?.terminal }

    // Inspector state
    var showingInspector = true
    var selectedInspectorTab: InspectorTab = .files
}
