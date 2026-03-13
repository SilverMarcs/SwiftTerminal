import Foundation

@Observable
final class Workspace: Identifiable {
    let id = UUID()
    var name: String
    var tabs: [TerminalTab] = []
    var selectedTabID: UUID?

    var selectedTab: TerminalTab? {
        tabs.first { $0.id == selectedTabID }
    }

    init(name: String) {
        self.name = name
    }

    @discardableResult
    func addTab() -> TerminalTab {
        let tab = TerminalTab()
        tabs.append(tab)
        selectedTabID = tab.id
        return tab
    }

    func closeTab(_ tab: TerminalTab) {
        tab.terminate()
        tabs.removeAll { $0.id == tab.id }
        if selectedTabID == tab.id {
            selectedTabID = tabs.last?.id
        }
    }

    func terminateAll() {
        for tab in tabs {
            tab.terminate()
        }
    }
}
