import SwiftUI

struct FileTreeView: View {
    let directoryURL: URL
    @Bindable var state: FileTreeInspectorState

    @Environment(EditorPanel.self) private var editorPanel
    @AppStorage("showHiddenFiles") private var showHiddenFiles = false

    var body: some View {
        List(selection: $state.selectedID) {
            ForEach(state.model.displayItems) { item in
                FileNodeView(item: item, expandedIDs: $state.expandedIDs, onAction: handleAction)
                    .tag(item.id)
            }
        }
        .scrollContentBackground(.hidden)
        .contextMenu {
            Button { handleAction(.newFile(directoryURL)) } label: {
                Label("New File", systemImage: "doc.badge.plus")
            }
            Button { handleAction(.newFolder(directoryURL)) } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
            Divider()
            Toggle("Show Hidden Files", isOn: $showHiddenFiles)
        }
        .safeAreaBar(edge: .bottom) {
            SearchBar(text: $state.model.searchText, placeholder: "Search for Files", focusTrigger: state.searchFocusTrigger) {
                Button(action: toggleChangedFilter) {
                    Image(systemName: state.model.showChangedOnly ? "plusminus.circle.fill" : "plusminus.circle")
                        .foregroundStyle(state.model.showChangedOnly ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("Show only git-changed files")
            }
            .padding(11)
        }
        .task(id: directoryURL) {
            state.model.showHiddenFiles = showHiddenFiles
            state.model.load(directoryURL: directoryURL)
            await state.model.refreshGit(directoryURL: directoryURL)
        }
        .gitPolling(id: directoryURL) {
            await state.model.refreshGit(directoryURL: directoryURL)
        }
        .onChange(of: state.model.searchText) { oldValue, newValue in
            if !newValue.isEmpty && oldValue.isEmpty {
                // Starting a search — save expansion state and expand all
                if state.savedExpandedIDs == nil {
                    state.savedExpandedIDs = state.expandedIDs
                }
                expandAllFolders(in: state.model.displayItems)
            } else if !newValue.isEmpty {
                // Search text changed — expand all filtered results
                expandAllFolders(in: state.model.displayItems)
            } else if newValue.isEmpty && !oldValue.isEmpty && !state.model.showChangedOnly {
                // Search cleared and no other filter active — restore
                if let saved = state.savedExpandedIDs {
                    state.expandedIDs = saved
                    state.savedExpandedIDs = nil
                }
            }
        }
        .onChange(of: showHiddenFiles) {
            state.model.showHiddenFiles = showHiddenFiles
            state.model.load(directoryURL: directoryURL)
        }
        .onChange(of: state.selectedID) { _, newID in
            guard let id = newID,
                  let item = state.model.findItem(id: id),
                  !item.isDirectory
            else { return }
            editorPanel.openFile(item.url)
        }
    }

    private func toggleChangedFilter() {
        if !state.model.showChangedOnly {
            if state.savedExpandedIDs == nil {
                state.savedExpandedIDs = state.expandedIDs
            }
            expandAllFolders(in: state.model.displayItems)
        } else if state.model.searchText.isEmpty, let saved = state.savedExpandedIDs {
            // Only restore if search is also inactive
            state.expandedIDs = saved
            state.savedExpandedIDs = nil
        }
        state.model.showChangedOnly.toggle()
    }

    private func expandAllFolders(in items: [FileItem]) {
        for item in items {
            if item.children != nil {
                state.expandedIDs.insert(item.id)
                if let children = item.children {
                    expandAllFolders(in: children)
                }
            }
        }
    }

    // MARK: - Context Menu Actions

    private func handleAction(_ action: FileTreeAction) {
        switch action {
        case .revealInFinder(let url):
            NSWorkspace.shared.activateFileViewerSelecting([url])

        case .moveToTrash(let url):
            state.model.moveToTrash(url: url, directoryURL: directoryURL)

        case .duplicate(let url):
            state.model.duplicate(url: url, directoryURL: directoryURL)

        case .newFile(let parentURL):
            let parent = state.model.createNewFile(in: parentURL, directoryURL: directoryURL)
            state.expandedIDs.insert(parent.path)

        case .newFolder(let parentURL):
            let parent = state.model.createNewFolder(in: parentURL, directoryURL: directoryURL)
            state.expandedIDs.insert(parent.path)
        }
    }
}
