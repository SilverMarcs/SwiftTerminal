import SwiftUI

struct InspectorView: View {
    let directoryURL: URL
    @Environment(AppState.self) private var appState

    var body: some View {
        tabContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                if appState.showingInspector {
                    ToolbarItem(placement: .primaryAction) {
                        Picker("Inspector", selection: Bindable(appState).selectedInspectorTab) {
                            ForEach(InspectorTab.allCases) { tab in
                                Image(systemName: tab.icon)
                                    .help(tab.label)
                                    .tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        appState.showingInspector.toggle()
                    } label: {
                        Image(systemName: "sidebar.trailing")
                    }
                }
            }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch appState.selectedInspectorTab {
        case .files:
            FileTreeView(directoryURL: directoryURL)
        case .git:
            GitInspectorView(directoryURL: directoryURL)
        case .search:
            SearchInspectorView(directoryURL: directoryURL)
        }
    }
}
