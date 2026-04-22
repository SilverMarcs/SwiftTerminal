import SwiftUI
import ACP

struct ToolCallsButton: View {
    let items: [MessageBlock]
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            HStack(spacing: 4) {
                ForEach(uniqueIcons, id: \.self) { icon in
                    Image(systemName: icon)
                }
                Text(summaryLabel)
                overallStatus
            }
        }
        .popover(isPresented: $showPopover) {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(items) { item in
                    HStack(spacing: 6) {
                        statusIcon(for: item)
                        Text(item.toolTitle ?? "Tool")
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 300)
            .padding(12)
        }
    }

    private var uniqueIcons: [String] {
        var seen = Set<String>()
        var icons: [String] = []
        for item in items {
            let icon = item.toolSymbolName
            if seen.insert(icon).inserted {
                icons.append(icon)
            }
        }
        return icons
    }

    private var summaryLabel: String {
        if items.count == 1 {
            return items[0].toolTitle ?? "Tool"
        }
        return "\(items.count) tool calls"
    }

    @ViewBuilder
    private var overallStatus: some View {
        if items.contains(where: { $0.toolStatus == .inProgress }) {
            ProgressView().controlSize(.mini)
        } else if items.contains(where: { $0.toolStatus == .failed }) {
            Image(systemName: "xmark").foregroundStyle(.red).font(.caption2)
        } else {
            Image(systemName: "checkmark").foregroundStyle(.green).font(.caption2)
        }
    }

    @ViewBuilder
    private func statusIcon(for item: MessageBlock) -> some View {
        if let status = item.toolStatus {
            switch status {
            case .pending:
                Image(systemName: "clock").font(.caption2).foregroundStyle(.secondary)
            case .inProgress:
                ProgressView().controlSize(.mini)
            case .completed:
                Image(systemName: "checkmark").font(.caption2).foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark").font(.caption2).foregroundStyle(.red)
            }
        }
    }
}
