import SwiftUI

struct DiffPopoverHeaderView: View {
    let addedCount: Int
    let removedCount: Int
    let stage: GutterHunkStage
    var onDiscard: (() -> Void)?
    var onUnstage: (() -> Void)?
    var onStage: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                if addedCount > 0 {
                    Text("+\(addedCount)")
                        .foregroundStyle(.green)
                }
                if removedCount > 0 {
                    Text("-\(removedCount)")
                        .foregroundStyle(.red)
                }
            }
            .font(.caption.monospacedDigit())

            Spacer()

            switch stage {
            case .unstaged:
                if let onDiscard {
                    Button("Discard", role: .destructive, action: onDiscard)
                        .controlSize(.small)
                }
                if let onStage {
                    Button("Stage", action: onStage)
                        .controlSize(.small)
                }
            case .staged:
                if let onUnstage {
                    Button("Unstage", action: onUnstage)
                        .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
