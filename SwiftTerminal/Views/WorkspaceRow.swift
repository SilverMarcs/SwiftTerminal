import SwiftUI

struct WorkspaceRow: View {
    @Environment(AppState.self) private var appState

    let workspace: Workspace
    @Binding var renamingWorkspace: Workspace?

    @State private var renameDraft = ""
    @State private var runningProcessCount = 0
    @FocusState private var isNameFieldFocused: Bool

    private var isRenaming: Bool {
        renamingWorkspace == workspace
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .overlay(alignment: .bottomTrailing) {
                    if runningProcessCount > 0 {
                        Text("\(runningProcessCount)")
                            .font(.system(size: 8, weight: .semibold))
                            .monospaced()
                            .padding(4)
                            .background(.ultraThickMaterial, in: .circle)
                            .offset(x: 5, y: 5)
                    }
                }

            if isRenaming {
                TextField("Workspace Name", text: $renameDraft)
                    .textFieldStyle(.plain)
                    .focused($isNameFieldFocused)
                    .onSubmit(commitRename)
                    .onExitCommand(perform: cancelRename)
                    .onAppear {
                        renameDraft = workspace.name
                        isNameFieldFocused = true
                    }
                    .onChange(of: isNameFieldFocused) { _, isFocused in
                        guard !isFocused else { return }
                        commitRename()
                    }
            } else {
                Text(workspace.name)
                    .lineLimit(1)
            }
        }
        .task {
            while !Task.isCancelled {
                runningProcessCount = workspace.runningProcessCount
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .badge(workspace.notificationCount)
        .badgeProminence(.increased)
        .contextMenu {
            RenameButton()
            Divider()
            Button(role: .destructive) {
                appState.removeWorkspace(workspace)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .renameAction(beginRenaming)
    }

    private func beginRenaming() {
        appState.selectedWorkspace = workspace
        renamingWorkspace = workspace
    }

    private func commitRename() {
        workspace.rename(to: renameDraft)
        renamingWorkspace = nil
    }

    private func cancelRename() {
        renamingWorkspace = nil
    }
}
