import SwiftUI

extension EnvironmentValues {
    @Entry var isDetachedEditor: Bool = false
    @Entry var editorFontSize: CGFloat = 12
}

extension FocusedValues {
    @Entry var editorPanel: EditorPanel?
    @Entry var isMainWindow: Bool?
}
