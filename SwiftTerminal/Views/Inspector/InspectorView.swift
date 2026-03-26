import SwiftUI

struct InspectorView: View {
    let directoryURL: URL
    @Binding var isPresented: Bool
    @State private var selectedTab: InspectorTab = .files

    var body: some View {
        tabContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                if isPresented {
                    ToolbarItem(placement: .primaryAction) {
                        Picker("Inspector", selection: $selectedTab) {
                            ForEach(InspectorTab.allCases) { tab in
                                Image(systemName: tab.icon)
                                    .help(tab.label)
                                    .tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
//                    ToolbarSpacer(.flexible, placement: .primaryAction)
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresented.toggle()
                    } label: {
                        Image(systemName: "sidebar.trailing")
                    }
                }
            }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .files:
            FileTreeView(directoryURL: directoryURL)
        case .git:
            GitInspectorView(directoryURL: directoryURL)
        case .search:
            SearchInspectorView(directoryURL: directoryURL)
        }
    }
}
