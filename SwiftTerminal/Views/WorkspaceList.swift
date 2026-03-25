import SwiftUI
import AppKit

struct WorkspaceList: View {
    @Environment(AppState.self) private var appState
    @State private var renamingWorkspace: Workspace?

    var body: some View {
        @Bindable var appState = appState

        List(selection: $appState.selectedWorkspace) {
            ForEach(appState.workspaces) { workspace in
                WorkspaceRow(
                    workspace: workspace,
                    renamingWorkspace: $renamingWorkspace
                )
                .tag(workspace)
            }
            .onMove { source, destination in
                appState.moveWorkspaces(from: source, to: destination)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                chooseDirectoryForNewWorkspace()
            } label: {
                Label("New Workspace", systemImage: "plus")
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func chooseDirectoryForNewWorkspace() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a directory for the new workspace"
        panel.prompt = "Select"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        appState.addWorkspace(directory: url.path)
    }
}

