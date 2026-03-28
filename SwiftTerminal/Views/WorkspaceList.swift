import SwiftUI
import SwiftData
import AppKit

struct SidebarItem: Identifiable, Hashable {
    let id: SidebarSelection
    let label: String
    let icon: String
    var children: [SidebarItem]?
}

struct WorkspaceList: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workspace.sortOrder) private var workspaces: [Workspace]
    @State private var searchText = ""

    private var filteredWorkspaces: [Workspace] {
        guard !searchText.isEmpty else { return workspaces }
        return workspaces.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var sidebarItems: [SidebarItem] {
        filteredWorkspaces.map { workspace in
            let sessionChildren = workspace.sessions.map { cs in
                let label = if let sid = cs.sdkSessionID {
                    String(sid.prefix(8))
                } else {
                    "New Session"
                }
                return SidebarItem(
                    id: .session(workspaceID: workspace.id, sessionID: cs.id),
                    label: label,
                    icon: "bubble.left"
                )
            }
            return SidebarItem(
                id: .workspace(workspace.id),
                label: workspace.name,
                icon: "folder",
                children: sessionChildren.isEmpty ? nil : sessionChildren
            )
        }
    }

    var body: some View {
        @Bindable var appState = appState

        List(sidebarItems, children: \.children, selection: $appState.sidebarSelection) { item in
            sidebarRow(for: item)
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Filter workspaces")
        .safeAreaInset(edge: .bottom) {
            Button {
                chooseDirectoryForNewWorkspace()
            } label: {
                Label("New Workspace", systemImage: "plus")
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .onAppear {
            if appState.sidebarSelection == nil {
                appState.sidebarSelection = workspaces.first.map { .workspace($0.id) }
            }
        }
    }

    @ViewBuilder
    private func sidebarRow(for item: SidebarItem) -> some View {
        switch item.id {
        case .workspace(let id):
            if let workspace = workspaces.first(where: { $0.id == id }) {
                WorkspaceRow(workspace: workspace)
            }
        case .session(let workspaceID, let sessionID):
            if let workspace = workspaces.first(where: { $0.id == workspaceID }),
               let cs = workspace.unsortedSessions.first(where: { $0.id == sessionID }) {
                Label(
                    cs.sdkSessionID.map { String($0.prefix(8)) } ?? "New Session",
                    systemImage: "bubble.left"
                )
                .contextMenu {
                    Button(role: .destructive) {
                        workspace.removeSession(cs)
                        if appState.sidebarSelection == .session(workspaceID: workspaceID, sessionID: sessionID) {
                            appState.sidebarSelection = .workspace(workspaceID)
                        }
                    } label: {
                        Label("Delete Session", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func chooseDirectoryForNewWorkspace() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a directory for the new workspace"
        panel.prompt = "Select"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        addWorkspace(directory: url.path)
    }

    private func addWorkspace(directory: String) {
        let name = URL(fileURLWithPath: directory).lastPathComponent
        let workspace = Workspace(name: name, directory: directory, sortOrder: workspaces.count)
        modelContext.insert(workspace)
        appState.sidebarSelection = .workspace(workspace.id)
    }
}
