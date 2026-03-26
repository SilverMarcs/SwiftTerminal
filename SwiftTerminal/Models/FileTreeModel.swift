import Foundation
import Observation

@Observable
final class FileTreeModel {
    private(set) var items: [FileItem] = []
    private(set) var gitStatuses: [URL: GitChangeKind] = [:]

    var searchText = ""
    var showChangedOnly = false

    var changedURLs: Set<URL> { Set(gitStatuses.keys) }

    var isFiltering: Bool { !searchText.isEmpty || showChangedOnly }

    var displayItems: [FileItem] {
        guard isFiltering else { return items }
        return items.compactMap {
            $0.filtered(
                searchText: searchText,
                changedURLs: changedURLs,
                showChangedOnly: showChangedOnly
            )
        }
    }

    private let gitRepository = GitRepository()

    func load(directoryURL: URL) {
        var tree = FileItem.buildTree(at: directoryURL)
        applyStatuses(to: &tree)
        items = tree
    }

    func refreshGit(directoryURL: URL) async {
        guard let statuses = try? await gitRepository.changedFileStatuses(in: directoryURL)
        else { return }
        gitStatuses = statuses
        var tree = FileItem.buildTree(at: directoryURL)
        applyStatuses(to: &tree)
        items = tree
    }

    private func applyStatuses(to tree: inout [FileItem]) {
        guard !gitStatuses.isEmpty else { return }
        for i in tree.indices {
            tree[i].applyGitStatuses(gitStatuses)
        }
    }
}
