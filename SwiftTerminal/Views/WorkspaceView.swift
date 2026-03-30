import SwiftUI

struct WorkspaceView: View {
    var workspace: Workspace
    var selectedTerminal: TerminalTab
    @Environment(AppState.self) private var appState
    @State private var editorPanel = EditorPanel()

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
            .inspector(isPresented: Bindable(appState).showingInspector) {
                InspectorView(directoryURL: workspace.url)
                    .inspectorColumnWidth(min: 240, ideal: 240, max: 360)
            }
            .environment(editorPanel)
            .focusedSceneValue(\.editorPanel, editorPanel)
    }
}
