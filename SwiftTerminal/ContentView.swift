import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        NavigationSplitView {
            WorkspaceListView()
                .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 300)
        } detail: {
            if let terminal = appState.selectedTerminal {
                WorkspaceView(workspace: terminal.workspace, selectedTerminal: terminal)
            } else {
                ContentUnavailableView(
                    "No Workspace Selected",
                    systemImage: "sidebar.left",
                    description: Text("Select a terminal to get started.")
                )
            }
        }
    }
}
