import SwiftUI

struct FileTreeView: View {
    let directoryURL: URL

    @State private var items: [FileItem] = []
    @State private var gitStatuses: [URL: GitChangeKind] = [:]
    @State private var changedURLs: Set<URL>?
    @State private var selectedItem: FileItem?
    @State private var searchText = ""
    @State private var showChangedOnly = false
    @State private var expandedIDs: Set<String> = []
    @State private var savedExpandedIDs: Set<String>?
    @Environment(\.scenePhase) private var scenePhase

    private let gitRepository = GitRepository()

    private var isFiltering: Bool {
        !searchText.isEmpty || showChangedOnly
    }

    private var displayItems: [FileItem] {
        guard isFiltering else { return items }

        return items.compactMap {
            $0.filtered(searchText: searchText, changedURLs: changedURLs, showChangedOnly: showChangedOnly)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if displayItems.isEmpty {
                ContentUnavailableView {
                    Label(isFiltering ? "No Results" : "No Files", systemImage: isFiltering ? "magnifyingglass" : "folder")
                }
                .frame(maxHeight: .infinity)
            } else {
                List(selection: $selectedItem) {
                    ForEach(displayItems) { item in
                        FileNodeView(item: item, expandedIDs: $expandedIDs)
                            .tag(item)
                    }
                }
                .scrollContentBackground(.hidden)
            }

            Divider()

            FileTreeFilterBar(
                searchText: $searchText,
                showChangedOnly: $showChangedOnly,
                onToggleChanged: toggleChangedFilter
            )
        }
        .task(id: directoryURL) {
            await loadTree()
            await refreshGitStatuses()
        }
        .task(id: scenePhase) {
            if scenePhase == .active { await refreshGitStatuses() }
        }
    }

    private func loadTree() async {
        var tree = FileItem.buildTree(at: directoryURL)
        if !gitStatuses.isEmpty {
            for i in tree.indices {
                tree[i].applyGitStatuses(gitStatuses)
            }
        }
        items = tree
    }

    private func expandAllFolders(in items: [FileItem]) {
        for item in items {
            if item.children != nil {
                expandedIDs.insert(item.id)
                if let children = item.children {
                    expandAllFolders(in: children)
                }
            }
        }
    }

    private func toggleChangedFilter() {
        if !showChangedOnly {
            savedExpandedIDs = expandedIDs
            expandAllFolders(in: displayItems)
        } else if let saved = savedExpandedIDs {
            expandedIDs = saved
            savedExpandedIDs = nil
        }
        showChangedOnly.toggle()
    }

    private func refreshGitStatuses() async {
        do {
            let statuses = try await gitRepository.changedFileStatuses(in: directoryURL)
            let urls = try await gitRepository.changedFileURLs(in: directoryURL)
            gitStatuses = statuses
            changedURLs = urls

            var tree = FileItem.buildTree(at: directoryURL)
            for i in tree.indices {
                tree[i].applyGitStatuses(statuses)
            }
            items = tree
        } catch {
            // Git not available
        }
    }
}
