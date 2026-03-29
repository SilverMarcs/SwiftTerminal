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
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSession)) { notification in
            guard let idString = notification.userInfo?["sessionID"] as? String,
                  let sessionID = UUID(uuidString: idString) else { return }
            for workspace in workspaces {
                if let session = workspace.sessions.first(where: { $0.id == sessionID }) {
                    appState.selectedItem = .session(session)
                    break
                }
            }
        }
    }
}
