#if os(macOS)
import SwiftUI
import SwiftTerm

struct TerminalRepresentable: NSViewRepresentable {
    let tab: TerminalTab

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)
        tab.localProcessTerminalView = terminalView

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminalView.processDelegate = context.coordinator

        terminalView.startProcess(
            executable: shell,
            args: [],
            environment: nil,
            execName: nil,
            currentDirectory: home
        )

        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab)
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let tab: TerminalTab

        init(tab: TerminalTab) {
            self.tab = tab
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            Task { @MainActor in
                self.tab.title = title.isEmpty ? "Terminal" : title
            }
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {}
    }
}
#endif
