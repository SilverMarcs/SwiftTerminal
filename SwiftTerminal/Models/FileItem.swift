import AppKit
import UniformTypeIdentifiers

struct FileItem: Identifiable, Hashable {
    var id: String { url.path }
    let name: String
    let url: URL
    let isDirectory: Bool
    var children: [FileItem]?
    var gitStatus: GitChangeKind?

    var icon: NSImage {
        if isDirectory {
            return NSWorkspace.shared.icon(for: .folder)
        }
        let type = UTType(filenameExtension: url.pathExtension.lowercased()) ?? .data
        return NSWorkspace.shared.icon(for: type)
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    /// Returns a filtered copy of the tree.
    func filtered(searchText: String, changedURLs: Set<URL>?, showChangedOnly: Bool) -> FileItem? {
        if !isDirectory {
            let nameMatch = searchText.isEmpty || name.localizedCaseInsensitiveContains(searchText)
            let gitMatch = !showChangedOnly || changedURLs?.contains(url.standardizedFileURL) == true
            return (nameMatch && gitMatch) ? self : nil
        }

        let filteredChildren = children?.compactMap {
            $0.filtered(searchText: searchText, changedURLs: changedURLs, showChangedOnly: showChangedOnly)
        }

        guard let filteredChildren, !filteredChildren.isEmpty else { return nil }

        var copy = self
        copy.children = filteredChildren
        return copy
    }

    /// Applies git statuses to this item and all descendants.
    /// Directories bubble up the highest-priority status from their children.
    mutating func applyGitStatuses(_ statuses: [URL: GitChangeKind]) {
        let resolved = url.standardizedFileURL
        if let status = statuses[resolved] {
            gitStatus = status
        }

        if var kids = children {
            for i in kids.indices {
                kids[i].applyGitStatuses(statuses)
            }
            children = kids

            // Bubble up: take the highest-priority child status
            if gitStatus == nil {
                let childStatuses = kids.compactMap(\.gitStatus)
                gitStatus = childStatuses.max(by: { $0.priority < $1.priority })
            }
        }
    }

    static func buildTree(at directoryURL: URL) -> [FileItem] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents
            .filter { !ignoredNames.contains($0.lastPathComponent) }
            .compactMap { url -> FileItem? in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                let isDir = values?.isDirectory ?? false
                return FileItem(
                    name: url.lastPathComponent,
                    url: url,
                    isDirectory: isDir,
                    children: isDir ? buildTree(at: url) : nil
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    private static let ignoredNames: Set<String> = [
        ".DS_Store", ".git", "node_modules", ".build", "DerivedData",
        "Pods", "__pycache__", ".venv", "venv", ".svn", ".hg",
    ]
}


extension GitChangeKind {

    /// Higher = more important. Used to pick the dominant status for folders.
    var priority: Int {
        switch self {
            case .typeChanged: 0
            case .copied: 1
            case .renamed: 2
            case .modified: 3
            case .added, .untracked: 4
            case .deleted: 5
            case .conflicted: 6
        }
    }
}
