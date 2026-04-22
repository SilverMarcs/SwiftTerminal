import SwiftUI
import ACP

struct WorkspaceRow: View {
    @Environment(AppState.self) private var appState
    @Environment(WorkspaceStore.self) private var store

    let workspace: Workspace

    @State private var isRenaming = false
    @FocusState private var isNameFieldFocused: Bool

    @State private var busyCount = 0
    @State private var hasBell = false
    @State private var showingImportSessions = false

    var body: some View {
        HStack(spacing: 8) {
            if workspace.projectType != .unknown {
                Image(workspace.projectType.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "folder")
            }

            if isRenaming {
                TextField("Workspace Name", text: Bindable(workspace).name)
                    .textFieldStyle(.plain)
                    .focused($isNameFieldFocused)
                    .onSubmit { isRenaming = false }
                    .onExitCommand { isRenaming = false }
                    .onAppear { isNameFieldFocused = true }
            } else {
                Text(workspace.name)
                    .lineLimit(1)
            }
        }
        .badge(hasBell ? Text("") : Text(busyCount > 0 ? "\(busyCount)" : ""))
        .badgeProminence(hasBell ? .increased : .standard)
        .task {
            while !Task.isCancelled {
                busyCount = workspace.terminals.filter(\.hasChildProcess).count
                hasBell = workspace.terminals.contains(where: \.hasBellNotification)
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .contextMenu {
            Button("New Chat") {
                let tracked = workspace.addSession(provider: .claude)
                appState.selectedWorkspace = workspace
                appState.selectedSession = tracked
            }

            Button("Import Existing Session...") {
                showingImportSessions = true
            }

            Divider()

            RenameButton()

            Menu("Project Type") {
                ForEach(ProjectType.allCases, id: \.self) { type in
                    Button {
                        workspace.projectType = type
                    } label: {
                        Label {
                            Text(type.displayName)
                        } icon: {
                            if workspace.projectType == type {
                                Image(systemName: "checkmark")
                            } else if !type.iconName.isEmpty {
                                Image(type.iconName)
                            }
                        }
                    }
                }

                Divider()

                Button("Auto-Detect") {
                    workspace.detectProjectType()
                }
            }

            Divider()
            Button(role: .destructive) {
                if appState.selectedWorkspace === workspace {
                    appState.selectedWorkspace = nil
                    appState.selectedTerminal = nil
                    appState.selectedSession = nil
                }
                store.deleteWorkspace(workspace)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .renameAction {
            isRenaming = true
        }
        .sheet(isPresented: $showingImportSessions) {
            ImportSessionSheet(workspace: workspace)
        }
    }
}

// MARK: - Import Session Sheet

struct ImportSessionSheet: View {
    let workspace: Workspace
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var sessions: [SessionInfo] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var importingId: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Import Session")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if isLoading {
                ProgressView("Discovering sessions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else if sessions.isEmpty {
                ContentUnavailableView {
                    Label("No Sessions Found", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("No existing Claude sessions found for this workspace directory.")
                }
            } else {
                List(sessions, id: \.sessionId) { session in
                    sessionRow(session)
                }
            }
        }
        .frame(width: 450, height: 400)
        .task {
            await discoverSessions()
        }
    }

    private func sessionRow(_ session: SessionInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title ?? session.sessionId.value.prefix(12) + "...")
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let updatedAt = session.updatedAt {
                        Text(updatedAt)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Text(session.sessionId.value.prefix(8) + "...")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                        .monospaced()
                }
            }

            Spacer()

            if importingId == session.sessionId.value {
                ProgressView()
                    .controlSize(.small)
            } else {
                let alreadyImported = workspace.chats.contains { $0.acpSessionId == session.sessionId.value }
                Button(alreadyImported ? "Imported" : "Import") {
                    Task { await importSession(session) }
                }
                .disabled(alreadyImported || importingId != nil)
            }
        }
    }

    private func discoverSessions() async {
        isLoading = true
        do {
            let tempSession = ACPSession()
            tempSession.provider = .claude
            sessions = try await tempSession.listExistingSessions(workingDirectory: workspace.directory)
            // Filter out sessions already in our workspace
            let existingIds = Set(workspace.chats.compactMap(\.acpSessionId))
            // Sort by updatedAt descending
            sessions.sort { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func importSession(_ sessionInfo: SessionInfo) async {
        importingId = sessionInfo.sessionId.value
        do {
            let chat = try await Chat.importSession(
                sessionInfo: sessionInfo,
                provider: .claude,
                workspace: workspace
            )
            workspace.appendChat(chat)
            appState.selectedWorkspace = workspace
            appState.selectedSession = chat
            dismiss()
        } catch {
            self.error = "Import failed: \(error.localizedDescription)"
        }
        importingId = nil
    }
}
