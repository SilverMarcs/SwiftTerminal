import SwiftUI

struct QuestionPanelView: View {
    let service: ClaudeService
    let question: UserQuestion
    @State private var selections: [Int: Set<Int>] = [:]
    @State private var freeformAnswer = ""
    @FocusState private var isFocused: Bool

    private var hasOptions: Bool {
        question.questions.contains { !$0.options.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)

                Text("Claude is asking")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
            }

            ForEach(Array(question.questions.enumerated()), id: \.offset) { qIndex, item in
                questionItemView(item, index: qIndex)
            }

            if !hasOptions {
                HStack(spacing: 8) {
                    TextField("Your answer…", text: $freeformAnswer, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .focused($isFocused)
                        .onSubmit { submit() }

                    Button("Send") { submit() }
                        .disabled(freeformAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .controlSize(.small)
                }
            } else {
                Button("Submit") { submit() }
                    .disabled(!hasAnySelection)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .overlay(alignment: .top) { Divider() }
        .onAppear {
            if !hasOptions { isFocused = true }
        }
    }

    @ViewBuilder
    private func questionItemView(_ item: QuestionItem, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.question)
                .font(.callout)
                .textSelection(.enabled)

            if !item.options.isEmpty {
                ForEach(Array(item.options.enumerated()), id: \.offset) { optIndex, option in
                    optionButton(option, questionIndex: index, optionIndex: optIndex, multiSelect: item.multiSelect)
                }
            }
        }
    }

    @ViewBuilder
    private func optionButton(_ option: QuestionOption, questionIndex: Int, optionIndex: Int, multiSelect: Bool) -> some View {
        let isSelected = selections[questionIndex]?.contains(optionIndex) == true

        Button {
            var current = selections[questionIndex] ?? []
            if multiSelect {
                if current.contains(optionIndex) {
                    current.remove(optionIndex)
                } else {
                    current.insert(optionIndex)
                }
            } else {
                current = [optionIndex]
            }
            selections[questionIndex] = current
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption)

                VStack(alignment: .leading, spacing: 1) {
                    Text(option.label)
                        .font(.caption)
                        .fontWeight(.medium)

                    if !option.description.isEmpty {
                        Text(option.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var hasAnySelection: Bool {
        for (qIndex, item) in question.questions.enumerated() {
            if !item.options.isEmpty {
                guard let sel = selections[qIndex], !sel.isEmpty else { return false }
            }
        }
        return true
    }

    private func submit() {
        let answer: String

        if hasOptions {
            var parts: [String] = []
            for (qIndex, item) in question.questions.enumerated() {
                let selected = selections[qIndex] ?? []
                let labels = selected.sorted().compactMap { idx in
                    item.options.indices.contains(idx) ? item.options[idx].label : nil
                }
                if !labels.isEmpty {
                    parts.append("\(item.question) \(labels.joined(separator: ", "))")
                }
            }
            answer = parts.joined(separator: "\n")
        } else {
            answer = freeformAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !answer.isEmpty else { return }
        service.respondToQuestion(answer)
    }
}
