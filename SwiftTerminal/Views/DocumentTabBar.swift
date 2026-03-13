import SwiftUI

struct DocumentTabBar: View {
    @Bindable var workspace: Workspace

    var body: some View {
        HStack(spacing: 5) {
            tabStrip
            addButton
        }
        .padding(.horizontal, 5)
        .padding(.bottom, 3)
    }

    private var tabStrip: some View {
        HStack(spacing: 2) {
            ForEach(workspace.tabs) { tab in
                tabItem(tab)
            }
        }
        .padding(2)
        .background(
            Capsule()
                .fill(.background.quinary)
        )
    }

    @ViewBuilder
    private func tabItem(_ tab: TerminalTab) -> some View {
        let isSelected = workspace.selectedTab === tab

        Text(
            tab.title
        )
        .font(.system(size: 12))
        .lineLimit(1)
        .truncationMode(.middle)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
            if workspace.tabs.count > 1 {
                Button {
                    workspace.closeTab(tab)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(
            Capsule()
                .fill(isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
        )
        .contentShape(.capsule)
        .onTapGesture {
            workspace.selectedTab = tab
        }
    }

    private var addButton: some View {
        Button {
            workspace.addTab()
        } label: {
            Image(systemName: "plus")
        }
        .controlSize(.large)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }
}
