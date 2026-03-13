import Foundation
import SwiftTerm

@Observable
final class TerminalTab: Identifiable {
    let id = UUID()
    var title: String = "Terminal"
    var localProcessTerminalView: LocalProcessTerminalView?

    func terminate() {
        // LocalProcessTerminalView cleans up its process on dealloc
        localProcessTerminalView = nil
    }
}
