import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(WorkspaceStore.self) private var store
    @State private var searchText = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingOnboarding = false

    var body: some View {
        NavigationSplitView {
            WorkspaceListView(searchText: searchText)
                .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 300)
                .searchable(text: $searchText, placement: .sidebar, prompt: "Filter workspaces")
        } detail: {
            if let workspace = appState.selectedWorkspace {
                WorkspaceDetailView(workspace: workspace)
                    // .id(workspace.id)
            } else {
                ContentUnavailableView(
                    "No Workspace Selected",
                    systemImage: "sidebar.left",
                    description: Text("Select a workspace to get started.")
                )
            }
        }
        .inspector(isPresented: Bindable(appState).showingInspector) {
            if let workspace = appState.selectedWorkspace {
                InspectorView(workspace: workspace)
                    .environment(workspace.editorPanel)
                    // .id(workspace.url)
                    .inspectorColumnWidth(min: 240, ideal: 240, max: 360)
            } else {
                ContentUnavailableView(
                    "No Inspector",
                    systemImage: "sidebar.right"
                )
            }
        }
        .focusedSceneValue(\.editorPanel, appState.selectedWorkspace?.editorPanel)
        .focusedSceneValue(\.isMainWindow, true)
        .sheet(isPresented: $showingOnboarding) {
            hasCompletedOnboarding = true
        } content: {
            OnboardingView()
        }
        .task {
            if !hasCompletedOnboarding {
                showingOnboarding = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToChat)) { note in
            guard let info = note.userInfo,
                  let workspaceIDString = info["workspaceID"] as? String,
                  let chatIDString = info["chatID"] as? String,
                  let workspaceID = UUID(uuidString: workspaceIDString),
                  let chatID = UUID(uuidString: chatIDString),
                  let workspace = store.workspaces.first(where: { $0.id == workspaceID }),
                  let chat = workspace.chats.first(where: { $0.id == chatID })
            else { return }
            appState.selectedWorkspace = workspace
            appState.selectedChat = chat
            appState.expandedWorkspaceIDs.insert("w:\(workspace.id.uuidString)")
        }
    }
}
