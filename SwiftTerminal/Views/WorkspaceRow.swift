import SwiftUI

struct WorkspaceRow: View {
    @Environment(AppState.self) private var appState

    let workspace: Workspace

    @State private var isRenaming = false
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")

            if isRenaming {
                TextField("Workspace Name", text: Bindable(workspace).name)
                    .textFieldStyle(.plain)
                    .focused($isNameFieldFocused)
                    .onSubmit { isRenaming = false }
                    .onExitCommand { isRenaming = false }
                    .onAppear { isNameFieldFocused = true }
            } else {
                Text(workspace.name)
                    .lineLimit(1)
            }
        }
        .contextMenu {
            Button {
                let session = workspace.newSession()
                appState.sidebarSelection = .session(workspaceID: workspace.id, sessionID: session.id)
            } label: {
                Label("New Session", systemImage: "plus.bubble")
            }
            Divider()
            RenameButton()
            Divider()
            Button(role: .destructive) {
                appState.removeWorkspace(workspace)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .renameAction {
            appState.selectedWorkspace = workspace
            isRenaming = true
        }
    }
}
