import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image("claude.symbols")
                .font(.largeTitle)
            Text("Claude Code")
                .font(.title.bold())
            Text("Ask anything about this workspace")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
