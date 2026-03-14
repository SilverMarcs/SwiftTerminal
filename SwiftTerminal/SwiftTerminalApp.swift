import SwiftUI

@main
struct SwiftTerminalApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        Window("main", id: "main") {
            ContentView()
                .environment(appState)
                .frame(minWidth: 600, minHeight: 400)
        }
        .defaultSize(width: 900, height: 600)
        .commands {
            AppCommands(appState: appState)
        }
    }
}
