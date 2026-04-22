import SwiftUI

struct WorkspaceSessionsView: View {
    let workspace: Workspace
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            if workspace.chats.isEmpty {
                ContentUnavailableView {
                    Label("No Sessions", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("Start a new chat from the sidebar context menu.")
                }
            } else {
                ForEach(workspace.chats) { tracked in
                    Button {
                        appState.selectedSession = tracked
                    } label: {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(tracked.title)
                                        .lineLimit(1)

                                    HStack(spacing: 8) {
                                        Text(tracked.provider.rawValue)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)

                                        if tracked.turnCount > 0 {
                                            Text("\(tracked.turnCount) turns")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }

                                        Text(tracked.date, style: .relative)
                                            .font(.caption2)
                                            .foregroundStyle(.quaternary)
                                    }
                                }
                            } icon: {
                                Image(tracked.provider.imageName)
                                    .foregroundStyle(
                                        tracked.isActive
                                            ? tracked.provider.color
                                            : .secondary
                                    )
                            }

                            Spacer()

                            if tracked.isActive {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if tracked.isActive {
                            Button {
                                tracked.disconnect()
                            } label: {
                                Label("Disconnect", systemImage: "bolt.slash")
                            }
                        }

                        Button(role: .destructive) {
                            if appState.selectedSession?.id == tracked.id {
                                appState.selectedSession = nil
                            }
                            workspace.removeSession(tracked)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}
