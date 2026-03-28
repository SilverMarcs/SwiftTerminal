import Foundation
import SwiftData

@Model
final class ClaudeSession {
    var id = UUID()
    var sdkSessionID: String?
    var createdAt: Date = Date()

    @Relationship(inverse: \Workspace.unsortedSessions)
    var workspace: Workspace?

    @Transient var service: ClaudeService?

    init(workspace: Workspace? = nil) {
        self.workspace = workspace
    }

    /// Returns the existing service or creates one on first access.
    func resolveService() -> ClaudeService {
        if let service { return service }
        let s = ClaudeService(workspace: workspace!, claudeSession: self)
        service = s
        return s
    }
}
