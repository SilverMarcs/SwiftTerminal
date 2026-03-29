import SwiftUI

struct ClaudeChatView: View {
    let service: ClaudeService

    var body: some View {
        List {
            MessageListView(service: service)

            if let approval = service.pendingApproval {
                ApprovalPanelView(service: service, approval: approval)
                    .listRowSeparator(.hidden)
            }

            ErrorBarView(service: service)
                .listRowSeparator(.hidden)

            if !service.promptSuggestions.isEmpty && !service.isStreaming {
                promptSuggestionsBar
                    .listRowSeparator(.hidden)
            }
        }
        .overlay {
            if service.messages.isEmpty {
                EmptyStateView()
            }
        }
        .overlay(alignment: .bottom) {
            if let elicitation = service.pendingElicitation {
                ElicitationPanelView(service: service, elicitation: elicitation)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: service.pendingElicitation != nil)
        .toolbar {
            ToolbarContentView(service: service)
        }
        .safeAreaBar(edge: .bottom) {
            InputBarView(service: service)
        }
    }

    private var promptSuggestionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(service.promptSuggestions, id: \.self) { suggestion in
                    Button {
                        service.prompt = suggestion
                        service.sendMessage()
                    } label: {
                        Text(suggestion)
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }
}
