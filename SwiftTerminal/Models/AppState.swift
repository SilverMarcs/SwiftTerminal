import SwiftUI

@Observable
final class AppState {
    var workspaces: [Workspace] = []
    var selectedWorkspaceID: UUID?

    var selectedWorkspace: Workspace? {
        workspaces.first { $0.id == selectedWorkspaceID }
    }

    @discardableResult
    func addWorkspace(name: String? = nil) -> Workspace {
        let workspace = Workspace(name: name ?? "Workspace \(workspaces.count + 1)")
        workspace.addTab()
        workspaces.append(workspace)
        selectedWorkspaceID = workspace.id
        return workspace
    }

    func removeWorkspace(_ workspace: Workspace) {
        workspace.terminateAll()
        workspaces.removeAll { $0.id == workspace.id }
        if selectedWorkspaceID == workspace.id {
            selectedWorkspaceID = workspaces.first?.id
        }
    }
}
