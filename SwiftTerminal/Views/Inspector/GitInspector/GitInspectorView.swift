import SwiftUI
import UniformTypeIdentifiers

struct GitInspectorView: View {
    let directoryURL: URL

    @State private var model = GitInspectorModel()
    @State private var expandedRepos: Set<URL> = []
    @State private var selectedFiles: Set<GitChangedFile> = []
    @State private var showCommitSheet = false
    @State private var commitMessage = ""
    @State private var discardTarget: DiscardTarget?

    var body: some View {
        changesList
            .overlay {
                if model.isLoading && model.snapshots.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .task(id: directoryURL) {
                await model.refresh(directoryURL: directoryURL)
                expandAllRepos()
            }
            .task(id: directoryURL, priority: .low) {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled else { break }
                    await model.refresh(directoryURL: directoryURL)
                }
            }
            .sheet(isPresented: $showCommitSheet) {
                GitCommitSheet(message: $commitMessage, isPresented: $showCommitSheet) { msg in
                    guard let snapshot = model.snapshots.first(where: { !$0.stagedFiles.isEmpty }) else { return }
                    Task {
                        await model.commit(message: msg, snapshot: snapshot)
                        await model.refresh(directoryURL: directoryURL)
                    }
                }
            }
            .alert("Discard Changes?", isPresented: discardAlertBinding) {
                Button("Discard", role: .destructive) {
                    guard let target = discardTarget else { return }
                    Task {
                        await performDiscard(target)
                        await model.refresh(directoryURL: directoryURL)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(discardAlertMessage)
            }
    }

    // MARK: - List

    private var changesList: some View {
        List(selection: $selectedFiles) {
            ForEach(model.snapshots, id: \.repositoryRootURL) { snapshot in
                DisclosureGroup(isExpanded: repoBinding(snapshot.repositoryRootURL)) {
                    fileRows(snapshot.stagedFiles, staged: true, snapshot: snapshot)
                    fileRows(snapshot.unstagedFiles, staged: false, snapshot: snapshot)
                } label: {
                    repoHeader(snapshot)
                        .contextMenu { GitRepoContextMenu(snapshot: snapshot, onAction: handleAction) }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Repo Header

    private func repoHeader(_ snapshot: GitRepositoryStatusSnapshot) -> some View {
        Label {
            Text(snapshot.repositoryRootURL.lastPathComponent)
                .fontWeight(.medium)
            Text(snapshot.branchName ?? "branch")
                .foregroundStyle(.secondary)
        } icon: {
            Image(nsImage: NSWorkspace.shared.icon(for: .folder))
                .resizable()
                .frame(width: 16, height: 16)
        }
        .lineLimit(1)
    }

    // MARK: - File Rows

    @ViewBuilder
    private func fileRows(_ files: [GitChangedFile], staged: Bool, snapshot: GitRepositoryStatusSnapshot) -> some View {
        ForEach(files, id: \.self) { file in
            FileLabel(name: file.repositoryRelativePath, icon: file.fileURL.fileIcon) {
                GitStatusBadge(kind: file.kind, staged: staged)
            }
            .id("\(staged ? "staged" : "unstaged"):\(file.repositoryRelativePath)")
            .tag(file)
            .contextMenu {
                let targets = contextMenuTargets(for: file)
                GitFileContextMenu(files: targets, snapshot: snapshot, onAction: handleAction)
            }
        }
    }

    /// If the right-clicked file is in the selection, act on the whole selection.
    /// Otherwise act on just the clicked file.
    private func contextMenuTargets(for file: GitChangedFile) -> [GitChangedFile] {
        if selectedFiles.contains(file) {
            Array(selectedFiles)
        } else {
            [file]
        }
    }

    // MARK: - Actions

    private func handleAction(_ action: GitAction) {
        switch action {
        case .stage(let files, let snapshot):
            Task { await model.stage(files: files, snapshot: snapshot); await model.refresh(directoryURL: directoryURL) }
        case .unstage(let files, let snapshot):
            Task { await model.unstage(files: files, snapshot: snapshot); await model.refresh(directoryURL: directoryURL) }
        case .stageAll(let snapshot):
            Task { await model.stageAll(snapshot: snapshot); await model.refresh(directoryURL: directoryURL) }
        case .unstageAll(let snapshot):
            Task { await model.unstageAll(snapshot: snapshot); await model.refresh(directoryURL: directoryURL) }
        case .discard(let files, let snapshot):
            discardTarget = .files(files, snapshot)
        case .discardAll(let snapshot):
            discardTarget = .all(snapshot)
        case .commit:
            commitMessage = ""
            showCommitSheet = true
        }
    }

    // MARK: - Discard

    private enum DiscardTarget {
        case files([GitChangedFile], GitRepositoryStatusSnapshot)
        case all(GitRepositoryStatusSnapshot)
    }

    private var discardAlertBinding: Binding<Bool> {
        Binding(get: { discardTarget != nil }, set: { if !$0 { discardTarget = nil } })
    }

    private var discardAlertMessage: String {
        switch discardTarget {
        case .files(let files, _) where files.count == 1:
            "This will discard changes to \"\(files[0].repositoryRelativePath)\". This cannot be undone."
        case .files(let files, _):
            "This will discard changes to \(files.count) files. This cannot be undone."
        case .all:
            "This will discard all unstaged changes. This cannot be undone."
        case .none:
            ""
        }
    }

    private func performDiscard(_ target: DiscardTarget) async {
        switch target {
        case .files(let files, let snapshot): await model.discardChanges(files: files, snapshot: snapshot)
        case .all(let snapshot): await model.discardAllChanges(snapshot: snapshot)
        }
    }

    // MARK: - Helpers

    private func expandAllRepos() {
        for snapshot in model.snapshots {
            expandedRepos.insert(snapshot.repositoryRootURL)
        }
    }

    private func repoBinding(_ url: URL) -> Binding<Bool> {
        Binding(
            get: { expandedRepos.contains(url) },
            set: { if $0 { expandedRepos.insert(url) } else { expandedRepos.remove(url) } }
        )
    }
}
