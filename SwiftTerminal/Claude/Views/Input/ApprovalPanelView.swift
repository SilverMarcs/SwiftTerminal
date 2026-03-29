import SwiftUI

struct ApprovalPanelView: View {
    let service: ClaudeService
    let approval: ApprovalRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.caption)
                    .foregroundStyle(.orange)

                Text("Permission Required")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
            }
            
            if let title = approval.title {
                Text(title)
                    .font(.callout)
            } else {
                Text("Claude wants to use **\(approval.toolName)**")
                    .font(.callout)
            }

            if let desc = approval.description {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !approval.input.isEmpty {
                inputSummary
            }

            HStack(spacing: 8) {
                Button("Allow") {
                    service.respondToApproval(allow: true)
                }
                .keyboardShortcut(.return, modifiers: [])

                Button("Always Allow") {
                    service.respondToApproval(allow: true, forSession: true)
                }

                Button("Deny", role: .destructive) {
                    service.respondToApproval(allow: false)
                }
                .tint(.red)
            }
            .controlSize(.small)
        }
        .padding(12)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private var inputSummary: some View {
        let summary = formatApprovalInput(approval.toolName, approval.input)
        if !summary.isEmpty {
            Text(summary)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(8)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private func formatApprovalInput(_ tool: String, _ input: [String: Any]) -> String {
        switch tool {
        case "Bash":
            let cmd = (input["command"] as? String) ?? ""
            let desc = (input["description"] as? String)
            if let desc { return "\(desc)\n\(cmd)" }
            return cmd
        case "Write", "Edit", "Read":
            return (input["file_path"] as? String) ?? ""
        default:
            let relevant = input.filter { !["description"].contains($0.key) }
            return relevant.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        }
    }
}
