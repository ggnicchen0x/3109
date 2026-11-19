// AppThemePalette.swift — Theme color palette
// Reconstructed from 5013 v3.2.17 binary

import SwiftUI

class AppThemePalette: ObservableObject {

    @Published var primary: Color = .primary
    @Published var secondary: Color = .secondary
    @Published var accent: Color = .accentColor
    @Published var background: Color = Color(.systemBackground)
    @Published var surface: Color = Color(.secondarySystemBackground)
}
