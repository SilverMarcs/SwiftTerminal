#if os(macOS)
import SwiftUI

struct WorkspaceDetailView: View {
    @Bindable var workspace: Workspace

    var body: some View {
        Group {
            if workspace.tabs.isEmpty {
                ContentUnavailableView("No Terminal", systemImage: "terminal")
            } else {
                TerminalContainerRepresentable(
                    tabs: workspace.tabs,
                    selectedTabID: workspace.selectedTabID
                )
            }
        }
        .safeAreaBar(edge: .top, spacing: 0) {
            DocumentTabBar(workspace: workspace)
        }
//        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }
}
#endif
