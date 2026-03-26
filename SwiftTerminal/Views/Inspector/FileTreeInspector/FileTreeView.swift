import SwiftUI

struct FileTreeView: View {
    let directoryURL: URL

    @State private var model = FileTreeModel()
    @State private var selectedItem: FileItem?
    @State private var expandedIDs: Set<String> = []
    @State private var savedExpandedIDs: Set<String>?

    var body: some View {
        VStack(spacing: 0) {
            if model.displayItems.isEmpty {
                ContentUnavailableView {
                    Label(
                        model.isFiltering ? "No Results" : "No Files",
                        systemImage: model.isFiltering ? "magnifyingglass" : "folder"
                    )
                }
                .frame(maxHeight: .infinity)
            } else {
                List(selection: $selectedItem) {
                    ForEach(model.displayItems) { item in
                        FileNodeView(item: item, expandedIDs: $expandedIDs)
                            .tag(item)
                    }
                }
                .scrollContentBackground(.hidden)
            }

            Divider()

            FileTreeFilterBar(
                searchText: $model.searchText,
                showChangedOnly: $model.showChangedOnly,
                onToggleChanged: toggleChangedFilter
            )
        }
        .task(id: directoryURL) {
            model.load(directoryURL: directoryURL)
            await model.refreshGit(directoryURL: directoryURL)
        }
        .task(id: directoryURL, priority: .low) {
            await pollGitStatus()
        }
    }

    private func pollGitStatus() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { break }
            await model.refreshGit(directoryURL: directoryURL)
        }
    }

    private func toggleChangedFilter() {
        if !model.showChangedOnly {
            savedExpandedIDs = expandedIDs
            expandAllFolders(in: model.displayItems)
        } else if let saved = savedExpandedIDs {
            expandedIDs = saved
            savedExpandedIDs = nil
        }
        model.showChangedOnly.toggle()
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
}
