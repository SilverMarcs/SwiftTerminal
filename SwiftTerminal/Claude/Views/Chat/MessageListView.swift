import SwiftUI

struct MessageListView: View {
    let service: ClaudeService

    var body: some View {
//        ScrollViewReader { proxy in
//            ScrollView {
//                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(service.messages) { message in
                        MessageView(
                            message: message,
                            isStreaming: service.isStreaming
                                && message.id == service.messages.last?.id
                                && message.role == .assistant
                        )
                        .id(message.id)
                    }

                    if !service.activeTasks.isEmpty {
                        TaskProgressView(
                            tasks: service.activeTasks,
                            onStopTask: { service.stopTask($0) }
                        )
                        .id("active-tasks")
                    }
//                }
//                .padding()
//            }
//            .onChange(of: service.messages.count) {
//                scrollToBottom(proxy: proxy)
//            }
//            .onChange(of: service.messages.last?.blocks.count) {
//                scrollToBottom(proxy: proxy)
//            }
//            .onChange(of: service.messages.last?.text) {
//                scrollToBottom(proxy: proxy)
//            }
//            .onChange(of: service.activeTasks.count) {
//                scrollToBottom(proxy: proxy)
//            }
//        }
    }

//    private func scrollToBottom(proxy: ScrollViewProxy) {
//        if !service.activeTasks.isEmpty {
//            withAnimation(.easeOut(duration: 0.15)) {
//                proxy.scrollTo("active-tasks", anchor: .bottom)
//            }
//        } else if let last = service.messages.last {
//            withAnimation(.easeOut(duration: 0.15)) {
//                proxy.scrollTo(last.id, anchor: .bottom)
//            }
//        }
//    }
}
