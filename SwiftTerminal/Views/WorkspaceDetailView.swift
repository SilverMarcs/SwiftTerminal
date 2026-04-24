import SwiftUI

struct WorkspaceDetailView: View {
    let workspace: Workspace
    @Environment(AppState.self) private var appState
    @State private var showingScratchPad = false

    private var directorySubtitle: String {
        workspace.directory.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private var navigationSubtitle: String {
        guard let chat = appState.selectedSession else {
            return directorySubtitle
        }
        let session = chat.session
        guard session.usedTokens > 0 else {
            return directorySubtitle
        }
        return "\(formatTokens(session.usedTokens)) / \(formatTokens(session.contextSize))"
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            let m = Double(count) / 1_000_000
            return String(format: "%.1fM", m)
        } else if count >= 1_000 {
            let k = Double(count) / 1_000
            return String(format: "%.1fK", k)
        }
        return "\(count)"
    }

    var body: some View {
        Group {
            if let chat = appState.selectedSession {
                ACPView(chat: chat)
                    // .id(chat.id)
            } else {
                SessionBrowserView(workspace: workspace)
                    // .id(workspace.id)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomSheetView(directoryURL: workspace.url)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showingScratchPad = true
                } label: {
                    Label("Scratch Pad", systemImage: "note.text")
                }
                .keyboardShortcut(".")
            }
        }
        .sheet(isPresented: $showingScratchPad) {
            ScratchPadSheet(workspace: workspace)
        }
        .navigationTitle(workspace.name)
        .navigationSubtitle(navigationSubtitle)
        .environment(workspace.editorPanel)
        .environment(\.showInFileTree) { url in
            workspace.inspectorState.revealInFileTree(url, relativeTo: workspace.url)
        }
    }
}
