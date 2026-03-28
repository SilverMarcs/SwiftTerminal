import Foundation
import SwiftData

@Model
final class Workspace {
    var id = UUID()
    var name: String = ""
    var directory: String?
    var sortOrder: Int = 0

    @Relationship(deleteRule: .cascade)
    var unsortedSessions: [ClaudeSession] = []
    var sessions: [ClaudeSession] {
        unsortedSessions.sorted { $0.createdAt < $1.createdAt }
    }

    init(name: String, directory: String? = nil, sortOrder: Int = 0) {
        self.name = name
        self.directory = directory
        self.sortOrder = sortOrder
    }

    @discardableResult
    func newSession() -> ClaudeSession {
        let cs = ClaudeSession(workspace: self)
        unsortedSessions.append(cs)
        return cs
    }

    func removeSession(_ cs: ClaudeSession) {
        cs.service?.stop()
        unsortedSessions.removeAll { $0.id == cs.id }
        cs.modelContext?.delete(cs)
    }
}
