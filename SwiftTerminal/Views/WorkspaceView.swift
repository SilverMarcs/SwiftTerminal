import SwiftUI

struct TerminalDetailView: View {
    var terminal: Terminal

    private var workspace: Workspace { terminal.workspace }

    var body: some View {
        TerminalContainerRepresentable(tab: terminal)
//            .prefersDefaultFocus(in: <#T##Namespace.ID#>)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            .padding(.top, -8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                Button("") { terminal.clearTerminal() }
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
