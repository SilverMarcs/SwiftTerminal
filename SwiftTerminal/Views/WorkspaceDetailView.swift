#if os(macOS)
import SwiftUI

struct WorkspaceDetailView: View {
    @Bindable var workspace: Workspace

    var body: some View {
        ZStack {
            if workspace.tabs.isEmpty {
                ContentUnavailableView("No Terminal", systemImage: "terminal")
            } else {
                ForEach(workspace.tabs) { tab in
                    TerminalRepresentable(tab: tab)
                        .zIndex(workspace.selectedTabID == tab.id ? 1 : 0)
                        .opacity(workspace.selectedTabID == tab.id ? 1 : 0)
                }
            }
        }
        .safeAreaBar(edge: .top, spacing: 0) {
            DocumentTabBar(workspace: workspace)
        }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }
}
#endif
