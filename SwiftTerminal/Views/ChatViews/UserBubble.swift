import SwiftUI

struct UserMessageView: View {
    let message: Message

    private var chat: Chat { message.chat! }

    var body: some View {
        VStack(alignment: .trailing) {
            ExpandableText(text: message.text)
                .padding(12)
                .background(.background.secondary)
                .clipShape(.rect(cornerRadius: 20))
        }
        .contentShape(.rect)
        .transaction { $0.animation = nil }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contextMenu {
            revertButton
        }
        .padding(.leading, 160)
    }

    @ViewBuilder
    private var revertButton: some View {
        let turn = message.turnIndex
        if turn >= 1 && chat.turnCount >= turn {
            Button {
                Task { await chat.revert(toBeforeTurn: turn) }
            } label: {
                Label("Revert to this message", systemImage: "arrow.uturn.backward")
            }
        }
    }
}
