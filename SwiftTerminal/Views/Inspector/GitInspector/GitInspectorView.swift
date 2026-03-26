import SwiftUI

struct GitInspectorView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Git", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
        } description: {
            Text("Git changes will appear here.")
        }
    }
}
