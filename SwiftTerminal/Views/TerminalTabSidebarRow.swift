import SwiftUI

struct TerminalTabSidebarRow: View {
    @Environment(AppState.self) private var appState

    let tab: TerminalTab
    let workspace: Workspace

    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tab.hasChildProcess ? "terminal.fill" : "terminal")

            if isRenaming {
                TextField("Terminal Name", text: $renameText)
                    .textFieldStyle(.plain)
                    .focused($isNameFieldFocused)
                    .onSubmit { commitRename() }
                    .onExitCommand { isRenaming = false }
                    .onAppear {
                        renameText = tab.title
                        isNameFieldFocused = true
                    }
            } else {
                Text(tab.title)
                    .lineLimit(1)
            }
        }
        .badge(tab.hasBellNotification ? "" : nil)
        .badgeProminence(.increased)
        .tag(tab)
        .contextMenu {
            RenameButton()

            Divider()

            Button("Close Terminal", systemImage: "trash", role: .destructive) {
                closeTerminal()
            }
        }
        .renameAction {
            isRenaming = true
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                closeTerminal()
            } label: {
                Label("Close", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
        }
    }

    private func commitRename() {
        isRenaming = false
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != tab.title else { return }
        tab.title = trimmed
    }

    private func closeTerminal() {
        if appState.selectedTerminal == tab {
            appState.selectedTerminal = nil
        }
        workspace.closeTerminal(tab)
    }
}
