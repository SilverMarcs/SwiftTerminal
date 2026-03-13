import SwiftUI

@main
struct SwiftTerminalApp: App {
    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            ContentView()
                .frame(minWidth: 600, minHeight: 400)
            #else
            Text("macOS only")
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 900, height: 600)
        #endif
    }
}
