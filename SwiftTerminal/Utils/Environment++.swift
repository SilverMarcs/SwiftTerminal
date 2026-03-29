import SwiftUI

extension EnvironmentValues {
    @Entry var isDetachedEditor: Bool = false
}

extension FocusedValues {
    @Entry var editorPanel: EditorPanel?
}
