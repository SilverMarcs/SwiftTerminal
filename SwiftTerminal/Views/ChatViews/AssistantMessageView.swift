import SwiftUI
import ACP

struct AssistantMessageView: View {
    @AppStorage("fontSize") private var fontSize: Double = 13

    let message: Message

    @State private var measuredHeight: CGFloat = 0

    private var chat: Chat { message.chat! }
    private var session: ACPSession { chat.session }
    private var isLastMessage: Bool { message.id == chat.messages.last?.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AssistantLabel(provider: chat.provider)

            VStack(alignment: .leading, spacing: 8) {
                AssistantBlocksRepresentable(
                    blocks: message.blocks,
                    fontSize: fontSize,
                    cachedHeight: message.height,
                    calculatedHeight: $measuredHeight
                )
                .frame(height: message.height > 0 ? message.height : nil, alignment: .top)
                .onChange(of: measuredHeight) { _, newHeight in
                    guard newHeight > 0, message.height != newHeight else { return }
                    message.height = newHeight
                }
                .transaction { $0.animation = nil }

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
}
