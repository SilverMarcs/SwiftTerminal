import SwiftUI
import SwiftData

struct WorkspaceRow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workspace.sortOrder) private var workspaces: [Workspace]

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
                removeWorkspace()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .renameAction {
            isRenaming = true
        }
    }

    private func removeWorkspace() {
        modelContext.delete(workspace)
        if appState.sidebarSelection?.workspaceID == workspace.id {
            appState.sidebarSelection = workspaces.first(where: { $0.id != workspace.id }).map { .workspace($0.id) }
        }
    }
}
