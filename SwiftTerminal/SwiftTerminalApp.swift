import SwiftUI

@main
struct SwiftTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        Window("main", id: "main") {
            ContentView()
                .environment(appState)
                .frame(minWidth: 600, minHeight: 400)
                .onAppear {
                    appDelegate.navigateToTab = { [weak appState] workspaceID, tabID in
                        guard let appState else { return }
                        if let workspace = appState.workspaces.first(where: { $0.id == workspaceID }) {
                            appState.selectedWorkspace = workspace
                            if let tab = workspace.tabs.first(where: { $0.id == tabID }) {
                                workspace.selectedTab = tab
                            }
                        }
                    }
                }
        }
        .defaultSize(width: 900, height: 600)
        .commands {
            AppCommands(appState: appState)
        }
    }
}
