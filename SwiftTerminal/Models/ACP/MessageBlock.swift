import Foundation
import ACP

struct MessageBlock: Codable, Identifiable {
    var id = UUID()
    var type: BlockType
    var text: String = ""

    var toolCallId: String?
    var toolTitle: String?
    var toolKind: ToolKind?
    var toolStatus: ToolStatus?

    enum BlockType: String, Codable {
        case text
        case thought
        case toolCall
    }

    var isText: Bool { type == .text }
    var isThought: Bool { type == .thought }
    var isToolCall: Bool { type == .toolCall }

    var toolSymbolName: String {
        toolKind?.symbolName ?? "wrench.and.screwdriver"
    }
}
