import SwiftUI

struct DiffHunkListView: View {
    let hunks: [DiffHunk]
    let reference: GitDiffReference
    let fileExtension: String
    let onReload: () async -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                    ForEach(hunks) { hunk in
                        let wrappedHeight = HunkTextView.calculateWrappedHeight(
                            hunk: hunk,
                            fileExtension: fileExtension,
                            containerWidth: geometry.size.width
                        )
                        Section {
                            HunkTextView(hunk: hunk, fileExtension: fileExtension)
                                .frame(height: wrappedHeight)
                        } header: {
                            DiffHunkHeaderView(
                                hunk: hunk,
                                reference: reference,
                                onReload: onReload
                            )
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}
