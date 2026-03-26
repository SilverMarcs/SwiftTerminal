import SwiftUI

struct FileTreeFilterBar: View {
    @Binding var searchText: String
    @Binding var showChangedOnly: Bool
    var onToggleChanged: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            FilterField(text: $searchText)
            
            Button {
                onToggleChanged()
            } label: {
                Image(systemName: showChangedOnly ? "externaldrive.fill.badge.checkmark" : "externaldrive.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(showChangedOnly ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Show only git-changed files")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}
