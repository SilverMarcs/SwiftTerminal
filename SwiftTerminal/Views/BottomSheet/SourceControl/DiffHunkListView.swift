import SwiftUI

struct DiffHunkListView: View {
    let hunks: [DiffHunk]
    let reference: GitDiffReference
    let fileExtension: String
    let onReload: () async -> Void

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(hunks) { hunk in
                    Section {
                        HunkTextView(hunk: hunk, fileExtension: fileExtension)
                            .frame(height: CGFloat(hunk.lines.count) * HunkTextViewConstants.lineHeight)
                    } header: {
                        DiffHunkHeaderView(
                            hunk: hunk,
                            reference: reference,
                            onReload: onReload
                        )
                    }
                }
            }
        }
    }
}
