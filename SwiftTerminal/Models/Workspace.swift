import Foundation
import SwiftData

@Model
final class Workspace {
    var id = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    
    var directory: String = ""
    var projectTypeRaw: String = ProjectType.unknown.rawValue

    var url: URL {
        URL(fileURLWithPath: directory)
    }

    var projectType: ProjectType {
        get { ProjectType(rawValue: projectTypeRaw) ?? .unknown }
        set { projectTypeRaw = newValue.rawValue }
    }

    func detectProjectType() {
        projectType = ProjectType.detect(at: url)
    }

    @Relationship(deleteRule: .cascade, inverse: \ChatSession.workspace)
    var unsortedSessions: [ChatSession] = []
    var sessions: [ChatSession] {
        unsortedSessions.sorted { $0.createdAt > $1.createdAt }
    }

    @Relationship(deleteRule: .cascade, inverse: \Terminal.workspace)
    var unsortedTerminals: [Terminal] = []
    var terminals: [Terminal] {
        unsortedTerminals.sorted { $0.sortOrder < $1.sortOrder }
    }

    init(name: String, directory: String, sortOrder: Int = 0) {
        self.name = name
        self.directory = directory
        self.sortOrder = sortOrder
    }
    
    // MARK: - Session Management

    @discardableResult
    func newSession() -> ChatSession {
        let cs = ChatSession(workspace: self)
        unsortedSessions.append(cs)
        return cs
    }

    /// Returns an existing empty session or creates a new one.
    func emptyOrNewSession() -> ChatSession {
        if let empty = sessions.first(where: { $0.externalSessionID == nil }) {
            return empty
        }
        return newSession()
    }

    func removeSession(_ cs: ChatSession) {
        cs.service?.stop()
        unsortedSessions.removeAll { $0.id == cs.id }
        cs.modelContext?.delete(cs)
    }

    // MARK: - Terminal Management

    @discardableResult
    func addTerminal() -> Terminal {
        let tab = Terminal(workspace: self, currentDirectory: directory, sortOrder: unsortedTerminals.count)
        unsortedTerminals.append(tab)
        return tab
    }

    func closeTerminal(_ tab: Terminal) {
        tab.terminate()
        unsortedTerminals.removeAll { $0.id == tab.id }
        tab.modelContext?.delete(tab)
    }
}
