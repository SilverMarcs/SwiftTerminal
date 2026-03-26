import SwiftUI

struct FileRowView: View {
    let item: FileItem

    var body: some View {
        HStack(spacing: 4) {
            Label {
                Text(item.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } icon: {
                Image(nsImage: item.icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            }

            Spacer()

            if let status = item.gitStatus {
                Text(status.statusSymbol)
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
