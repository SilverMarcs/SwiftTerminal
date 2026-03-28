import SwiftUI

struct InputBarView: View {
    @Binding var input: String
    let service: ClaudeService
    let onSend: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("Message Claude...", text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...8)
                .focused($isFocused)
                .onSubmit { onSend() }
                .disabled(service.pendingApproval != nil)

            if service.isStreaming {
                Button { service.stop() } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(trimmedInput.isEmpty ? .secondary : .primary)
                .disabled(trimmedInput.isEmpty || service.pendingApproval != nil)
            }
        }
        .padding(12)
        .onAppear { isFocused = true }
    }

    private var trimmedInput: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
