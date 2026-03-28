import SwiftUI

struct SessionBarView: View {
    let service: ClaudeService

    @State private var showingSessions = false

    var body: some View {
        HStack(spacing: 8) {
            if service.isStreaming {
                ProgressView()
                    .scaleEffect(0.4)
                    .frame(width: 12, height: 12)
            }

            modelButton

            effortPicker

            contextWindowPicker

            if service.session.turnCount > 0 {
                Text("\(service.session.turnCount) turns")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if service.session.totalCost > 0 {
                Text(formatCost(service.session.totalCost))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fontDesign(.monospaced)
            }

            if service.session.isCompacting {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.35)
                        .frame(width: 10, height: 10)
                    Text("Compacting...")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            permissionPicker

            Button {
                showingSessions = true
                Task { await service.listSessions() }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .popover(isPresented: $showingSessions) {
                SessionListView(
                    sessions: service.availableSessions,
                    onResume: { id in
                        showingSessions = false
                        service.resumeSession(id)
                    }
                )
            }

            if service.session.sessionID == nil {
                Button("Continue") { service.continueLastSession() }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
            }

            if service.session.sessionID != nil {
                Button("New") { service.clearSession() }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var modelButton: some View {
        Menu {
            ForEach(ModelOption.allCases, id: \.self) { model in
                Button {
                    service.setModel(model)
                } label: {
                    HStack {
                        Text(model.label)
                        if model == service.selectedModel {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(formatModel(service.session.model, fallback: service.selectedModel))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fontDesign(.monospaced)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var effortPicker: some View {
        Menu {
            ForEach(EffortLevel.allCases, id: \.self) { effort in
                Button {
                    service.selectedEffort = effort
                } label: {
                    HStack {
                        Text(effort.label)
                        if effort == service.selectedEffort {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(service.selectedEffort.label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var contextWindowPicker: some View {
        Menu {
            ForEach(ContextWindow.allCases, id: \.self) { window in
                Button {
                    service.setContextWindow(window)
                } label: {
                    HStack {
                        Text(window.label)
                        if window == service.selectedContextWindow {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(service.selectedContextWindow.label)
                .font(.caption2)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var permissionPicker: some View {
        Menu {
            ForEach(PermissionModeOption.allCases, id: \.self) { mode in
                Button {
                    service.setPermissionMode(mode)
                } label: {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(mode.label)
                            if mode == service.session.permissionMode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: permissionIcon)
                .font(.caption2)
                .foregroundStyle(permissionColor)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var permissionIcon: String {
        switch service.session.permissionMode {
        case .default: "shield.lefthalf.filled"
        case .acceptEdits: "shield.checkered"
        case .plan: "doc.text.magnifyingglass"
        case .bypassPermissions: "shield.slash"
        }
    }

    private var permissionColor: Color {
        switch service.session.permissionMode {
        case .default: .secondary
        case .acceptEdits: .orange
        case .plan: .blue
        case .bypassPermissions: .red
        }
    }

    private func formatModel(_ model: String?, fallback: ModelOption) -> String {
        guard let model else { return fallback.label.lowercased() }
        if model.contains("opus") { return "opus 4.6" }
        if model.contains("sonnet") { return "sonnet 4.6" }
        if model.contains("haiku") { return "haiku 4.5" }
        return model
    }

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.4f", cost)
        }
        return String(format: "$%.2f", cost)
    }
}
