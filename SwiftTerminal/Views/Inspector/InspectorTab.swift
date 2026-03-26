import Foundation

enum InspectorTab: Int, CaseIterable, Identifiable {
    case files
    case git
    case search

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .files: "Files"
        case .git: "Git"
        case .search: "Search"
        }
    }

    var icon: String {
        switch self {
        case .files: "folder"
        case .git: "point.topleft.down.curvedto.point.bottomright.up"
        case .search: "magnifyingglass"
        }
    }

    var selectedIcon: String {
        switch self {
        case .files: "folder.fill"
        case .git: "point.topleft.down.curvedto.point.bottomright.up.fill"
        case .search: "magnifyingglass.circle.fill"
        }
    }
}
