import SwiftUI
import SwiftData

// MARK: - Sidebar Selection

enum SidebarSelection: Hashable {
    case workspace(UUID)
    case session(workspaceID: UUID, sessionID: String)

    var workspaceID: UUID {
        switch self {
        case .workspace(let id): id
        case .session(let id, _): id
        }
    }
}

// MARK: - App State

@Observable
final class AppState {
    var workspaces: [Workspace] = []
    var sidebarSelection: SidebarSelection?
    var tabToClose: TerminalTab?
    var showCloseConfirmation = false

    // Inspector state
    var showingInspector = true
    var selectedInspectorTab: InspectorTab = .files
    var searchFocusToken: UUID?
    var inspectorWidth: CGFloat = 0

    /// Bumped by Cmd+J; observed by WorkspaceDetailView to toggle the editor panel.
    var panelToggleToken = UUID()

    /// The active service for each workspace. Observed so views update on switch.
    var activeServices: [UUID: ClaudeService] = [:]

    let modelContext: ModelContext

    /// All services keyed by their serviceKey. Keeps processes alive.
    @ObservationIgnored private var services: [String: ClaudeService] = [:]

    /// SDK session ID → service key, for sidebar session lookups.
    @ObservationIgnored private var sdkSessionMap: [String: String] = [:]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let descriptor = FetchDescriptor<Workspace>(sortBy: [SortDescriptor(\.sortOrder)])
        workspaces = (try? modelContext.fetch(descriptor)) ?? []
        sidebarSelection = workspaces.first.map { .workspace($0.id) }
    }

    // MARK: - Selection

    var selectedWorkspace: Workspace? {
        get {
            guard let sel = sidebarSelection else { return nil }
            return workspaces.first { $0.id == sel.workspaceID }
        }
        set {
            sidebarSelection = newValue.map { .workspace($0.id) }
        }
    }

    var selectedSessionID: String? {
        if case .session(_, let sid) = sidebarSelection {
            return sid
        }
        return nil
    }

    // MARK: - Claude Service

    func claudeService(for workspace: Workspace) -> ClaudeService {
        if let service = activeServices[workspace.id] {
            return service
        }
        return makeService(for: workspace)
    }

    func newSession(for workspace: Workspace) {
        makeService(for: workspace)
        sidebarSelection = .workspace(workspace.id)
    }

    func activateSession(_ sdkSessionID: String, for workspace: Workspace) {
        // Already showing this session?
        if activeServices[workspace.id]?.session.sessionID == sdkSessionID { return }

        // Find existing service running this session
        if let key = sdkSessionMap[sdkSessionID], let service = services[key] {
            activeServices[workspace.id] = service
            return
        }

        // Create new service and resume into it
        let service = makeService(for: workspace)
        service.resumeSession(sdkSessionID)
    }

    func registerSDKSession(_ sdkSessionID: String, serviceKey: String) {
        sdkSessionMap[sdkSessionID] = serviceKey
    }

    @discardableResult
    private func makeService(for workspace: Workspace) -> ClaudeService {
        let service = ClaudeService(
            workspaceID: workspace.id,
            workingDirectory: workspace.directory ?? NSHomeDirectory()
        )
        services[service.serviceKey] = service
        activeServices[workspace.id] = service
        return service
    }

    // MARK: - Workspace Management

    @discardableResult
    func addWorkspace(name: String? = nil, directory: String? = nil) -> Workspace {
        let resolvedName = name ?? directory.flatMap { URL(fileURLWithPath: $0).lastPathComponent } ?? "Workspace \(workspaces.count + 1)"
        let workspace = Workspace(name: resolvedName, directory: directory, sortOrder: workspaces.count)
        modelContext.insert(workspace)
        workspace.addTab(currentDirectory: directory)
        workspaces.append(workspace)
        sidebarSelection = .workspace(workspace.id)
        return workspace
    }

    func removeWorkspace(_ workspace: Workspace) {
        workspace.terminateAll()
        // Remove all services for this workspace
        let keys = services.filter { $0.value.workspaceID == workspace.id }.map(\.key)
        for key in keys {
            services.removeValue(forKey: key)
        }
        for sessionID in workspace.claudeSessionIDs {
            sdkSessionMap.removeValue(forKey: sessionID)
        }
        activeServices.removeValue(forKey: workspace.id)

        workspaces.removeAll { $0.id == workspace.id }
        modelContext.delete(workspace)
        if sidebarSelection?.workspaceID == workspace.id {
            sidebarSelection = workspaces.first.map { .workspace($0.id) }
        }
    }

    func moveWorkspaces(from source: IndexSet, to destination: Int) {
        withAnimation {
            workspaces.move(fromOffsets: source, toOffset: destination)
            for (i, ws) in workspaces.enumerated() {
                ws.sortOrder = i
            }
        }
    }
}
