// AppLogo.swift — App logo view
// Reconstructed from 5013 v3.2.17 binary
// Used in ContentView sidebarList header (titaniumCard)

import SwiftUI

struct AppLogo: View {
    var body: some View {
        Image("AppIcon")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
