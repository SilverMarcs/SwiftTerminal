import SwiftUI
import SwiftData
import AppKit

struct WorkspaceListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var workspaces: [Workspace]
    @State private var expandedWorkspaces: Set<UUID> = []

    var body: some View {
        List(selection: Bindable(appState).selection) {
            ForEach(workspaces) { workspace in
                DisclosureGroup(isExpanded: Binding(
                    get: { expandedWorkspaces.contains(workspace.id) },
                    set: { isExpanded in
                        if isExpanded {
                            expandedWorkspaces.insert(workspace.id)
                        } else {
                            expandedWorkspaces.remove(workspace.id)
                        }
                    }
                )) {
                    ForEach(workspace.terminals) { terminal in
                        TerminalRow(terminal: terminal)
                            .tag(SidebarSelection(workspace: workspace, terminal: terminal))
                    }
                    .onMove { source, destination in
                        moveTerminals(in: workspace, from: source, to: destination)
                    }
                } label: {
                    WorkspaceRow(workspace: workspace)
                        .tag(SidebarSelection(workspace: workspace))
                }
            }
            .onMove { source, destination in
                moveWorkspaces(from: source, to: destination)
            }
        }
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
    }

    init(searchText: String = "") {
        if searchText.isEmpty {
            _workspaces = Query(sort: \Workspace.sortOrder)
        } else {
            let predicate = #Predicate<Workspace> {
                $0.name.localizedStandardContains(searchText)
            }
            _workspaces = Query(filter: predicate, sort: \Workspace.sortOrder)
        }
    }
    
    private func moveWorkspaces(from source: IndexSet, to destination: Int) {
        var ordered = workspaces
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, workspace) in ordered.enumerated() {
            workspace.sortOrder = index
        }
    }

    private func moveTerminals(in workspace: Workspace, from source: IndexSet, to destination: Int) {
        withAnimation {
            var ordered = workspace.terminals
            ordered.move(fromOffsets: source, toOffset: destination)
            for (index, terminal) in ordered.enumerated() {
                terminal.sortOrder = index
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
        let name = URL(fileURLWithPath: url.path).lastPathComponent
        let workspace = Workspace(name: name, directory: url.path, sortOrder: workspaces.count)
        workspace.detectProjectType()
        modelContext.insert(workspace)
    }
}
