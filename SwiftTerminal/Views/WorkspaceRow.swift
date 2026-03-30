import SwiftUI
import SwiftData

struct WorkspaceRow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    let workspace: Workspace

    @State private var isRenaming = false
    @FocusState private var isNameFieldFocused: Bool

    private var terminalCount: Int {
        workspace.terminals.count
    }

    var body: some View {
        HStack(spacing: 8) {
            if workspace.projectType != .unknown {
                Image(workspace.projectType.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "folder")
            }

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
        .badge(terminalCount > 0 ? terminalCount : 0)
        .contextMenu {
            Button {
                let tab = workspace.addTerminal()
                appState.selection = SidebarSelection(workspace: workspace, terminal: tab)
            } label: {
                Label("New Terminal", systemImage: "plus")
            }
            Divider()
            RenameButton()
            Divider()
            Button(role: .destructive) {
                modelContext.delete(workspace)
                appState.selection = nil
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .renameAction {
            isRenaming = true
        }
    }
}
