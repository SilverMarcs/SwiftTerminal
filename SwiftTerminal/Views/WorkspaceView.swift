import SwiftUI

struct WorkspaceView: View {
    var session: ChatSession
    @Environment(AppState.self) private var appState
    @State private var editorPanel = EditorPanel()

    private var workspace: Workspace { session.workspace }

    var body: some View {
        SessionDetailView(session: session)
            .id(session.id)
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
