import SwiftUI

struct CommandEntrySheet: View {
    let workspace: Workspace
    var entry: CommandEntry?

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var command = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !command.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)

                TextField("Command", text: $command, axis: .vertical)
                    .lineLimit(5, reservesSpace: true)
                    .font(.system(.body, design: .monospaced))
                    .labelsHidden()
            }
            .formStyle(.grouped)
            .navigationTitle(entry == nil ? "New Command" : "Edit Command")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(entry == nil ? "Add" : "Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .onAppear {
            if let entry {
                name = entry.name
                command = entry.command
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedCommand = command.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedCommand.isEmpty else { return }

        if let entry {
            entry.name = trimmedName
            entry.command = trimmedCommand
        } else {
            workspace.addCommand(name: trimmedName, command: trimmedCommand)
        }
    }
}
