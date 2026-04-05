import SwiftUI

struct FileEditorPanel: View {
    private struct FileGitState {
        var stagedKind: GitChangeKind?
        var unstagedKind: GitChangeKind?
    }

    let fileURL: URL
    let directoryURL: URL
    @Environment(EditorPanel.self) private var panel
    @State private var content: String = ""
    @State private var savedContent: String = ""
    @State private var isLoaded = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var gutterDiff: GutterDiffResult = .empty
    @State private var gitState = FileGitState()
    @Environment(\.showInFileTree) private var showInFileTree

    private var hasUnsavedChanges: Bool {
        isLoaded && content != savedContent
    }

    var body: some View {
        PanelLayout {
            Image(nsImage: fileURL.fileIcon)
                .resizable()
                .frame(width: 16, height: 16)
            Text(fileURL.relativePath(from: directoryURL))
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
            if let unstagedKind = gitState.unstagedKind {
                GitStatusBadge(kind: unstagedKind, staged: false)
            }
            if let stagedKind = gitState.stagedKind {
                GitStatusBadge(kind: stagedKind, staged: true)
            }
            if panel.isDirty {
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .help("Unsaved changes")
            }
        } actions: {
            Button { showInFileTree(fileURL) } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("j", modifiers: [.command, .shift])
            .help("Show in File Tree")

            // Save button removed but Cmd+S shortcut preserved
            Button { panel.saveRequested = true } label: {
                Color.clear.frame(width: 0, height: 0)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("s", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
            .allowsHitTesting(false)
        } content: {
            if isLoaded {
                CodeTextEditor(
                    text: $content,
                    fileExtension: fileURL.pathExtension.lowercased(),
                    gutterDiff: gutterDiff,
                    highlightRequest: panel.highlightRequest,
                    repositoryRootURL: directoryURL,
                    onReloadFromDisk: { loadFile() }
                )
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Cannot Open File", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: fileURL) {
            loadFile()
        }
        .onChange(of: hasUnsavedChanges) { _, dirty in
            panel.isDirty = dirty
        }
        .onChange(of: panel.saveRequested) { _, requested in
            if requested {
                saveFile()
                panel.saveRequested = false
            }
        }
        .alert("Unsaved Changes", isPresented: Binding(
            get: { panel.showUnsavedAlert },
            set: { if !$0 { panel.cancelDiscard() } }
        )) {
            Button("Save") {
                saveFile()
                panel.confirmDiscard()
            }
            Button("Discard", role: .destructive) {
                panel.confirmDiscard()
            }
            Button("Cancel", role: .cancel) {
                panel.cancelDiscard()
            }
        } message: {
            Text("Do you want to save changes to \"\(fileURL.lastPathComponent)\"?")
        }
    }

    private func loadFile() {
        content = ""
        savedContent = ""
        isLoaded = false
        errorMessage = nil
        gutterDiff = .empty
        gitState = FileGitState()
        panel.isDirty = false
        do {
            let data = try Data(contentsOf: fileURL)
            guard let string = String(data: data, encoding: .utf8) else {
                errorMessage = "Binary file — cannot display."
                return
            }
            content = string
            savedContent = string
            isLoaded = true
            refreshGitState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveFile() {
        isSaving = true
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            savedContent = content
            refreshGitState()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func refreshGitState() {
        Task {
            do {
                async let gutter = GitRepository.shared.gutterDiff(for: fileURL, in: directoryURL)
                async let snapshots = GitRepository.shared.statusSnapshots(in: directoryURL)
                gutterDiff = try await gutter
                gitState = try await fileGitState(from: snapshots)
            } catch {
                gutterDiff = .empty
                gitState = FileGitState()
            }
        }
    }

    private func fileGitState(from snapshots: [GitRepositoryStatusSnapshot]) throws -> FileGitState {
        let standardizedURL = fileURL.standardizedFileURL
        var state = FileGitState()

        for snapshot in snapshots {
            if let stagedMatch = snapshot.stagedFiles.first(where: { $0.fileURL.standardizedFileURL == standardizedURL }) {
                state.stagedKind = stagedMatch.kind
            }
            if let unstagedMatch = snapshot.unstagedFiles.first(where: { $0.fileURL.standardizedFileURL == standardizedURL }) {
                state.unstagedKind = unstagedMatch.kind
            }
        }

        return state
    }
}
