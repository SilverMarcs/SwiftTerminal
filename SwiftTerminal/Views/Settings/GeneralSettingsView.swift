import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("hideTabBarWithSingleTab") private var hideTabBarWithSingleTab = false
    @AppStorage("editorWrapLines") private var editorWrapLines = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Form {
            Section {
                Toggle("Hide tab bar when only one tab is open", isOn: $hideTabBarWithSingleTab)
            } header: {
                Text("Tabs")
            } footer: {
                Text("When enabled, the tab bar is hidden in workspaces that have a single terminal tab.")
            }

            Section {
                Toggle("Wrap long lines", isOn: $editorWrapLines)
            } header: {
                Text("Editor")
            } footer: {
                Text("When enabled, lines that exceed the editor width wrap to the next line instead of scrolling horizontally.")
            }

            #if DEBUG
            Section {
                Button("Reset Onboarding Flag") {
                    hasCompletedOnboarding = false
                }
            } header: {
                Text("Debug")
            } footer: {
                Text("Resets the onboarding flag so the welcome sheet appears again on next launch.")
            }
            #endif

            LynkSphereByline()
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
        }
        .formStyle(.grouped)
    }
}

#Preview {
    GeneralSettingsView()
}
