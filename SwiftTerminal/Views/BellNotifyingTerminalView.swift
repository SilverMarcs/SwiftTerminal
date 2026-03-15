import Foundation
import SwiftTerm

final class BellNotifyingTerminalView: LocalProcessTerminalView {
    /// Single callback for any attention-requesting event (bell, OSC 9, OSC 777).
    /// Parameters: (title, body) — for plain bell, both are empty.
    var onAttention: ((String, String) -> Void)?

    override func bell(source: Terminal) {
        super.bell(source: source)
        onAttention?("", "")
    }
}
