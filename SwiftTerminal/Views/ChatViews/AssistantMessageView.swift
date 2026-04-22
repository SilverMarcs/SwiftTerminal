import SwiftUI
import ACP

struct AssistantMessageView: View {
    let message: Message

    private var chat: Chat { message.chat! }
    private var session: ACPSession { chat.session }
    private var isLastMessage: Bool { message.id == chat.messages.last?.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AssistantLabel(provider: chat.provider)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(groupedBlocks) { group in
                    switch group.type {
                    case .text:
                        MDView(content: group.blocks[0].text, isStreaming: session.isProcessing && isLastMessage)
                            .transaction { $0.animation = nil }
                    case .toolCalls:
                        ToolCallsButton(items: group.blocks)
                    case .thought:
                        EmptyView()
                    }
                }

                if session.isProcessing && isLastMessage {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.leading, 25)
        }
        .contentShape(.rect)
        .transaction { $0.animation = nil }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 30)
    }

    private var groupedBlocks: [BlockGroup] {
        var groups: [BlockGroup] = []
        for block in message.blocks {
            if block.isToolCall {
                if let last = groups.last, last.type == .toolCalls {
                    groups[groups.count - 1].blocks.append(block)
                } else {
                    groups.append(BlockGroup(type: .toolCalls, blocks: [block]))
                }
            } else if block.isThought {
                groups.append(BlockGroup(type: .thought, blocks: [block]))
            } else {
                groups.append(BlockGroup(type: .text, blocks: [block]))
            }
        }
        return groups
    }
}

private struct BlockGroup: Identifiable {
    let id = UUID()
    var type: GroupType
    var blocks: [MessageBlock]

    enum GroupType {
        case text
        case toolCalls
        case thought
    }
}
