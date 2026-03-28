import SwiftUI
import SwiftData

struct WorkspaceRow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

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
                appState.selectedSession = session
            } label: {
                Label("New Session", systemImage: "plus.bubble")
            }
            Divider()
            RenameButton()
            Divider()
            Button(role: .destructive) {
                modelContext.delete(workspace)
                appState.selectedSession = nil
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .renameAction {
            isRenaming = true
        }
    }
}
