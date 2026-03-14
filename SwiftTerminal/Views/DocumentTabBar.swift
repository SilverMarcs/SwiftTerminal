import SwiftUI

struct DocumentTabBar: View {
    let workspace: Workspace
    @State private var hoveredTabID: UUID?

    var body: some View {
        HStack(spacing: 5) {
            tabStrip
            addButton
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 3)
    }

    private var tabStrip: some View {
        HStack(spacing: 0) {
            ForEach(Array(workspace.tabs.enumerated()), id: \.element.id) { index, tab in
                if index > 0 {
                    separator(before: index)
                }
                tabItem(tab)
            }
        }
        .padding(2)
        .background(
            Capsule()
                .fill(.background.secondary)
        )
    }

    @ViewBuilder
    private func tabItem(_ tab: TerminalTab) -> some View {
        let isSelected = workspace.selectedTab === tab
        let isHovered = hoveredTabID == tab.id

        Button {
            workspace.selectedTab = tab
        } label: {
            HStack(spacing: 0) {
                tabAccessoryPlaceholder

                Text(tab.title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .center)

                tabAccessoryPlaceholder
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(backgroundStyle(isSelected: isSelected, isHovered: isHovered))
                    .strokeBorder(isSelected ? AnyShapeStyle(.separator) : AnyShapeStyle(.clear))
            )
            .contentShape(.capsule)
        }
        .overlay(alignment: .leading) {
            closeButton(for: tab, isVisible: isHovered && workspace.tabs.count > 1)
                .padding(.leading, 10)
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hoveredTabID = isHovering ? tab.id : (hoveredTabID == tab.id ? nil : hoveredTabID)
        }
    }

    private var addButton: some View {
        Button {
            openNewTab()
        } label: {
            Image(systemName: "plus")
        }
        .help("New Tab (\u{2318}T)")
        .controlSize(.large)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }

    private var tabAccessoryPlaceholder: some View {
        Color.clear
            .frame(width: 10, height: 10)
    }

    private func separator(before index: Int) -> some View {
        Rectangle()
            .fill(.separator)
            .frame(width: 1, height: 16)
            .padding(.horizontal, 2)
            .opacity(shouldShowSeparator(before: index) ? 1 : 0)
    }

    @ViewBuilder
    private func closeButton(for tab: TerminalTab, isVisible: Bool) -> some View {
        ZStack {
            if isVisible {
                Button {
                    closeTab(tab)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
            }
        }
        .frame(width: 10, height: 10)
    }

    private func shouldShowSeparator(before index: Int) -> Bool {
        guard index > 0, index < workspace.tabs.count else { return false }

        let previousTab = workspace.tabs[index - 1]
        let currentTab = workspace.tabs[index]
        return workspace.selectedTab !== previousTab && workspace.selectedTab !== currentTab
    }

    private func backgroundStyle(isSelected: Bool, isHovered: Bool) -> AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(.quaternary)
        }

        if isHovered {
            return AnyShapeStyle(.quinary)
        }

        return AnyShapeStyle(.clear)
    }

    private func openNewTab() {
        withAnimation {
            _ = workspace.addTabFromSelectedDirectory()
        }
    }

    private func closeTab(_ tab: TerminalTab) {
        withAnimation {
            workspace.closeTab(tab)
        }
    }
}
