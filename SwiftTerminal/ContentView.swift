import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var editorPanel = EditorPanel()
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            WorkspaceListView(searchText: searchText)
                .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 300)
                .searchable(text: $searchText, placement: .sidebar, prompt: "Filter workspaces")
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
        .inspector(isPresented: Bindable(appState).showingInspector) {
            if let terminal = appState.selectedTerminal {
                InspectorView(directoryURL: terminal.workspace.url)
                    .inspectorColumnWidth(min: 240, ideal: 240, max: 360)
            }
        }
        .environment(editorPanel)
        .focusedSceneValue(\.editorPanel, editorPanel)
    }
}
