import SwiftUI

struct AppCommands: Commands {
    @Bindable var appState: AppState

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Tab") {
                withAnimation {
                    _ = appState.selectedWorkspace?.addTabFromSelectedDirectory()
                }
            }
            .keyboardShortcut("t", modifiers: .command)
            .disabled(appState.selectedWorkspace == nil)

            Button("Close Tab") {
                withAnimation {
                    appState.selectedWorkspace?.closeSelectedTab()
                }
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled((appState.selectedWorkspace?.tabs.count ?? 0) < 2)
        }

        CommandMenu("Tabs") {
            Button("Select Previous Tab") {
                appState.selectedWorkspace?.selectPreviousTab()
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])
            .disabled((appState.selectedWorkspace?.tabs.count ?? 0) < 2)

            Button("Select Next Tab") {
                appState.selectedWorkspace?.selectNextTab()
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])
            .disabled((appState.selectedWorkspace?.tabs.count ?? 0) < 2)
        }
    }
}
