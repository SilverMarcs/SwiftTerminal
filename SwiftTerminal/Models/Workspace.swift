import Foundation
import SwiftTerm

@Observable
final class Workspace: Identifiable {
    let id: UUID
    var name: String {
        didSet {
            guard name != oldValue else { return }
            onPersistChange?()
        }
    }
    var tabs: [TerminalTab] = [] {
        didSet {
            configureTabPersistence()
            onPersistChange?()
        }
    }
    var selectedTab: TerminalTab? {
        didSet {
            guard selectedTab?.id != oldValue?.id else { return }
            selectedTab?.hasBellNotification = false
            onPersistChange?()
        }
    }
    var onPersistChange: (() -> Void)? {
        didSet {
            configureTabPersistence()
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        tabs: [TerminalTab] = [],
        selectedTabID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.tabs = tabs
        self.selectedTab = tabs.first { $0.id == selectedTabID } ?? tabs.first
        for tab in tabs { tab.workspaceID = id }
        configureTabPersistence()
    }

    @discardableResult
    func addTab(currentDirectory: String? = nil) -> TerminalTab {
        let tab = TerminalTab(currentDirectory: currentDirectory)
        tab.workspaceID = id
        tabs.append(tab)
        selectedTab = tab
        return tab
    }

    @discardableResult
    func addTabFromSelectedDirectory() -> TerminalTab {
        addTab(currentDirectory: selectedTab?.liveCurrentDirectory)
    }

    func closeTab(_ tab: TerminalTab) {
        tab.terminate()
        tabs.removeAll { $0.id == tab.id }
        if selectedTab === tab {
            selectedTab = tabs.last
        }
    }

    func closeSelectedTab() {
        guard let selectedTab, tabs.count > 1 else { return }
        closeTab(selectedTab)
    }

    func moveTab(_ tab: TerminalTab, before destinationTab: TerminalTab) {
        guard tab !== destinationTab,
              let sourceIndex = tabs.firstIndex(of: tab),
              let destinationIndex = tabs.firstIndex(of: destinationTab) else {
            return
        }

        moveTab(tab, to: sourceIndex < destinationIndex ? destinationIndex - 1 : destinationIndex)
    }

    func moveTab(_ tab: TerminalTab, to destinationIndex: Int) {
        guard let sourceIndex = tabs.firstIndex(of: tab) else {
            return
        }

        var reorderedTabs = tabs
        let movingTab = reorderedTabs.remove(at: sourceIndex)
        let clampedDestinationIndex = max(0, min(destinationIndex, reorderedTabs.count))
        reorderedTabs.insert(movingTab, at: clampedDestinationIndex)
        tabs = reorderedTabs
    }

    func rename(to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard self.name != trimmedName else { return }
        self.name = trimmedName
    }

    func selectNextTab() {
        selectTab(movingBy: 1)
    }

    func selectPreviousTab() {
        selectTab(movingBy: -1)
    }

    var hasNotification: Bool {
        tabs.contains { $0.hasBellNotification }
    }

    var notificationCount: Int {
        tabs.filter { $0.hasBellNotification }.count
    }

    /// Number of tabs that have at least one child process running under their shell.
    /// Uses a single sysctl snapshot for efficiency.
    var runningProcessCount: Int {
        let shellPids: [pid_t] = tabs.compactMap { tab in
            guard let tv = tab.localProcessTerminalView else { return nil }
            let pid = tv.process.shellPid
            return pid > 0 ? pid : nil
        }
        guard !shellPids.isEmpty else { return 0 }

        let shellPidSet = Set(shellPids)

        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: Int = 0
        sysctl(&mib, 3, nil, &size, nil, 0)
        let count = size / MemoryLayout<kinfo_proc>.stride
        let procs = UnsafeMutablePointer<kinfo_proc>.allocate(capacity: count)
        defer { procs.deallocate() }
        sysctl(&mib, 3, procs, &size, nil, 0)
        let actualCount = size / MemoryLayout<kinfo_proc>.stride

        var pidsWithChildren = Set<pid_t>()
        for i in 0..<actualCount {
            let parentPid = procs[i].kp_eproc.e_ppid
            if shellPidSet.contains(parentPid) {
                pidsWithChildren.insert(parentPid)
            }
        }
        return pidsWithChildren.count
    }

    func terminateAll() {
        for tab in tabs {
            tab.terminate()
        }
    }

    private func configureTabPersistence() {
        for tab in tabs {
            tab.onPersistChange = onPersistChange
        }
    }

    private func selectTab(movingBy offset: Int) {
        guard !tabs.isEmpty else { return }

        guard let selectedTab,
              let currentIndex = tabs.firstIndex(of: selectedTab) else {
            self.selectedTab = tabs.first
            return
        }

        let nextIndex = (currentIndex + offset).positiveModulo(tabs.count)
        self.selectedTab = tabs[nextIndex]
    }
}

extension Workspace: Hashable {
    static func == (lhs: Workspace, rhs: Workspace) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private extension Int {
    func positiveModulo(_ divisor: Int) -> Int {
        let remainder = self % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
