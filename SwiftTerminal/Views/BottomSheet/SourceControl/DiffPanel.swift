import SwiftUI

struct DiffPanel: View {
    let reference: GitDiffReference
    @State private var presentation: DiffFilePresentation?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = presentation?.message, presentation?.hunks.isEmpty == true {
                ContentUnavailableView {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            } else if let presentation {
                DiffHunkListView(
                    hunks: presentation.hunks,
                    reference: reference,
                    fileExtension: reference.fileURL.pathExtension.lowercased(),
                    onReload: { await loadDiff() }
                )
            }
        }
        .task(id: reference) { await loadDiff() }
    }

    private func loadDiff() async {
        isLoading = true
        do {
            presentation = try await GitRepository.shared.diffFilePresentation(for: reference)
        } catch {
            presentation = DiffFilePresentation(message: "Failed to load diff: \(error.localizedDescription)")
        }
        isLoading = false
    }
}
