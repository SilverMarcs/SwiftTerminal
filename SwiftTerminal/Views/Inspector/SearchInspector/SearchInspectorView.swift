import SwiftUI

struct SearchInspectorView: View {
    let directoryURL: URL

    @State private var model = SearchInspectorModel()
    @State private var expandedIDs: Set<UUID> = []
    @State private var selectedMatch: SearchMatch.ID?

    var body: some View {
        List(selection: $selectedMatch) {
            ForEach(model.results) { fileResult in
                DisclosureGroup(isExpanded: binding(for: fileResult.id)) {
                    ForEach(fileResult.matches) { match in
                        matchRow(match)
                    }
                } label: {
                    FileLabel(name: fileResult.relativePath, icon: fileResult.fileURL.fileIcon)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .safeAreaBar(edge: .top) {
            SearchField(text: $model.query) {
                Task {
                    await model.search(in: directoryURL)
                    expandedIDs = Set(model.results.map(\.id))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
        }
    }
    private func matchRow(_ match: SearchMatch) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("\(match.lineNumber)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(minWidth: 28, alignment: .trailing)

            Text(match.highlightedContent)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedIDs.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedIDs.insert(id)
                } else {
                    expandedIDs.remove(id)
                }
            }
        )
    }
}
