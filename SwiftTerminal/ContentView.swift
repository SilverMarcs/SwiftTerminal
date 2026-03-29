import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Workspace.sortOrder) private var workspaces: [Workspace]
    
    var body: some View {
        NavigationSplitView {
            WorkspaceListView()
                .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 300)
        } detail: {
            if let session = appState.selectedSession {
                WorkspaceView(session: session)
                    .id(session.id)
            } else {
                ContentUnavailableView(
                    "No Workspace Selected",
                    systemImage: "sidebar.left",
                    description: Text("Select a session to get started.")
                )
            }
        }
    }
}
