import Foundation
import SwiftTerm

/// Owns the live `LocalProcessTerminalView` for each terminal tab.
///
/// SwiftData `@Model` instances can be refaulted or replaced when nothing is
/// observing them — for example after a workspace switch — which would tear
/// down any `@Transient` view reference and kill the underlying shell process.
/// Keying the views off `Terminal.id` in a static registry decouples shell
/// process lifetime from SwiftData instance lifetime, mirroring the pattern
/// `CommandRunner` already uses for command execution state.
enum TerminalProcessRegistry {
    private static var views: [UUID: LocalProcessTerminalView] = [:]

    static func view(for id: UUID) -> LocalProcessTerminalView? {
        views[id]
    }

    static func register(_ view: LocalProcessTerminalView, for id: UUID) {
        views[id] = view
    }

    static func remove(for id: UUID) {
        views.removeValue(forKey: id)
    }
}
