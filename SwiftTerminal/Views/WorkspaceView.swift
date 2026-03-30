import SwiftUI

struct WorkspaceView: View {
    var workspace: Workspace
    var selectedTerminal: TerminalTab

    var body: some View {
        TerminalContainerRepresentable(tab: selectedTerminal)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                Button("") { selectedTerminal.clearTerminal() }
                    .keyboardShortcut("k", modifiers: .command)
                    .hidden()
            }
            .navigationTitle(workspace.name)
            .navigationSubtitle(workspace.directory.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomSheetView(directoryURL: workspace.url)
            }
    }
}
