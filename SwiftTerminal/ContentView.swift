import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Workspace.sortOrder) private var workspaces: [Workspace]

    private var selectedWorkspace: Workspace? {
        guard let sel = appState.sidebarSelection else { return nil }
        return workspaces.first { $0.id == sel.workspaceID }
    }

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            WorkspaceList()
                .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 300)
        } detail: {
            if let workspace = selectedWorkspace {
                WorkspaceDetailView(workspace: workspace)
                    .id(workspace.id)
            } else {
                ContentUnavailableView(
                    "No Workspace Selected",
                    systemImage: "sidebar.left",
                    description: Text("Select or create a workspace to get started.")
                )
            }
        }
    }
}
