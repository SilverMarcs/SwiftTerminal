import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
        }
        .frame(width: 480, height: 220)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage("hideTabBarWithSingleTab") private var hideTabBarWithSingleTab = false

    var body: some View {
        Form {
            Section {
                Toggle("Hide tab bar when only one tab is open", isOn: $hideTabBarWithSingleTab)
            } header: {
                Text("Tabs")
            } footer: {
                Text("When enabled, the tab bar is hidden in workspaces that have a single terminal tab.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
}
