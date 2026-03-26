import Foundation

/// What the bottom editor panel should display.
enum EditorPanelContent {
    case file(URL)
    case diff(GitDiffReference)
}

/// Shared state for the bottom slide-up editor panel in the workspace.
@Observable
final class EditorPanel {
    var content: EditorPanelContent?

    var isOpen: Bool { content != nil }

    func openFile(_ url: URL) {
        content = .file(url)
    }

    func openDiff(_ reference: GitDiffReference) {
        content = .diff(reference)
    }

    func close() {
        content = nil
    }
}
