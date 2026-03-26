import SwiftUI

struct SearchInspectorView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Search", systemImage: "magnifyingglass")
        } description: {
            Text("Workspace search will appear here.")
        }
    }
}
