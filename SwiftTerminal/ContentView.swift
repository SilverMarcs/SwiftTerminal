#if os(macOS)
import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        NavigationSplitView {
            SidebarView(appState: appState)
                .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 300)
        } detail: {
            if let workspace = appState.selectedWorkspace {
                WorkspaceDetailView(workspace: workspace)
//                    .backgroundExtensionEffect()
            } else {
                ContentUnavailableView(
                    "No Workspace Selected",
                    systemImage: "sidebar.left",
                    description: Text("Select or create a workspace to get started.")
                )
            }
        }
        .onAppear {
            if appState.workspaces.isEmpty {
                appState.addWorkspace(name: "Default")
            }
        }
    }
}

#Preview {
    ContentView()
}
#endif
