import SwiftUI

// MARK: - Claude Label

struct ClaudeLabel: View {
    @Environment(\.colorScheme) var colorScheme

    private let claudeColor = "#D6683B"

    var body: some View {
        Label {
            Text("Claude")
                .font(.subheadline)
                .bold()
                .foregroundStyle(.secondary)
                .foregroundStyle(Color(hex: claudeColor))
                .brightness(colorScheme == .dark ? 1.1 : -0.5)
        } icon: {
            Image("claude.symbols")
                .imageScale(.large)
                .foregroundStyle(Color(hex: claudeColor).gradient)
        }
        .labelIconToTitleSpacing(5)
    }
}

// MARK: - Tool Group (collapsed popover with sub-agent tasks)

struct ToolGroupView: View {
    let tools: [ToolUseInfo]
    var activeTasks: [String: TaskEvent] = [:]
    var onStopTask: ((String) -> Void)?
    @State private var showingPopover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                showingPopover.toggle()
            } label: {
                HStack(spacing: 6) {
                    ForEach(uniqueCategories, id: \.iconName) { cat in
                        Image(systemName: cat.iconName)
                            .font(.caption2)
                    }

                    Text(summary)
                        .font(.caption)
                        .lineLimit(1)

                    if hasRunningTool {
                        ProgressView()
                            .scaleEffect(0.4)
                            .frame(width: 10, height: 10)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPopover) {
                toolList
            }

            // Sub-agent tasks shown inline
            ForEach(agentTools, id: \.id) { tool in
                if let tasks = tasksForTool(tool.id), !tasks.isEmpty {
                    SubAgentTasksView(
                        toolName: tool.inputSummary,
                        tasks: tasks,
                        onStopTask: onStopTask
                    )
                }
            }
        }
    }

    private var toolList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(tools) { tool in
                HStack(spacing: 6) {
                    Image(systemName: tool.category.iconName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 14)

                    Text(tool.name)
                        .font(.caption)
                        .fontWeight(.medium)

                    Text(tool.inputSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    if !tool.isComplete {
                        ProgressView()
                            .scaleEffect(0.35)
                            .frame(width: 10, height: 10)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding(10)
        .frame(minWidth: 300)
    }

    private var summary: String {
        if tools.count == 1 {
            return "\(tools[0].name): \(tools[0].inputSummary)"
        }
        return "\(tools.count) tool calls"
    }

    private var uniqueCategories: [ToolCategory] {
        var seen = Set<String>()
        return tools.compactMap { tool in
            let icon = tool.category.iconName
            if seen.contains(icon) { return nil }
            seen.insert(icon)
            return tool.category
        }
    }

    private var hasRunningTool: Bool {
        tools.contains { !$0.isComplete }
    }

    private var agentTools: [ToolUseInfo] {
        tools.filter { $0.category == .agent }
    }

    private func tasksForTool(_ toolID: String) -> [TaskEvent]? {
        let tasks = activeTasks.values.filter { $0.toolUseID == toolID }
        return tasks.isEmpty ? nil : tasks.sorted { $0.taskID < $1.taskID }
    }
}

// MARK: - Sub-Agent Tasks (disclosure under Agent tool)

struct SubAgentTasksView: View {
    let toolName: String
    let tasks: [TaskEvent]
    var onStopTask: ((String) -> Void)?
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.2")
                        .font(.caption2)
                        .foregroundStyle(.blue)

                    Text(toolName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Spacer()

                    if hasRunningTask {
                        ProgressView()
                            .scaleEffect(0.35)
                            .frame(width: 10, height: 10)
                    }

                    Text("\(tasks.count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(tasks) { task in
                        HStack(spacing: 6) {
                            statusIcon(task.status)

                            if let summary = task.summary, !summary.isEmpty {
                                Text(summary)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            if task.status == .started || task.status == .inProgress {
                                if let onStop = onStopTask {
                                    Button {
                                        onStop(task.taskID)
                                    } label: {
                                        Image(systemName: "stop.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            Text(task.status.label)
                                .font(.caption2)
                                .foregroundStyle(statusColor(task.status))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .background(.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.blue.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var hasRunningTask: Bool {
        tasks.contains { $0.status == .started || $0.status == .inProgress }
    }

    @ViewBuilder
    private func statusIcon(_ status: TaskStatus) -> some View {
        switch status {
        case .started, .inProgress:
            ProgressView()
                .scaleEffect(0.35)
                .frame(width: 12, height: 12)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        case .stopped:
            Image(systemName: "stop.circle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }

    private func statusColor(_ status: TaskStatus) -> Color {
        switch status {
        case .started, .inProgress: .blue
        case .completed: .green
        case .failed: .red
        case .stopped: .orange
        }
    }
}

// MARK: - Expandable Text

struct ExpandableText: View {
    let text: String
    let maxCharacters: Int

    @State private var isExpanded = false
    private let needsExpansion: Bool

    init(text: String, maxCharacters: Int = 400) {
        self.text = text
        self.maxCharacters = maxCharacters
        self.needsExpansion = text.count > maxCharacters
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(displayedText)
                .textSelection(.enabled)
                .lineSpacing(2)

            if needsExpansion {
                Button {
                    isExpanded.toggle()
                } label: {
                    Text(isExpanded ? "Show Less" : "Show More")
                }
                .buttonBorderShape(.capsule)
            }
        }
    }

    private var displayedText: String {
        guard needsExpansion && !isExpanded else { return text }
        return String(text.prefix(maxCharacters))
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
