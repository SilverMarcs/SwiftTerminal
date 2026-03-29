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
        }
        .overlay {
            if service.messages.isEmpty {
                ContentUnavailableView {
                    Label("Claude Code", image: "claude.symbols")
                } description: {
                    Text("Do anything about this workspace")
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: service.pendingApproval != nil)
        .toolbar {
            ToolbarContentView(service: service)
        }
        .safeAreaBar(edge: .bottom) {
            InputBarView(service: service)
        }
    }
}
