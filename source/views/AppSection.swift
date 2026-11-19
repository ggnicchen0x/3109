// AppSection.swift — Navigation section enum
// Reconstructed from 5013 v3.2.17 binary
//
// Decoded from ContentView's ForEach over AppSection array,
// sectionView switch, and compactTabs tab labels.

import Foundation

enum AppSection: Int, CaseIterable, Hashable, Identifiable {
    case files = 0
    case patches
    case repository
    case settings
    case scan

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .files:      return "Files"
        case .patches:    return "Patches"
        case .repository: return "Repository"
        case .settings:   return "Settings"
        case .scan:       return "Scan"
        }
    }

    var iconName: String {
        switch self {
        case .files:      return "folder"
        case .patches:    return "doc.text"
        case .repository: return "shippingbox"
        case .settings:   return "gear"
        case .scan:       return "magnifyingglass"
        }
    }
}
