// CompactTabLabel.swift — Tab item label for compact layout
// Reconstructed from 5013 v3.2.17 binary

import SwiftUI

struct CompactTabLabel: View {
    let section: AppSection

    var body: some View {
        Label(section.title, systemImage: section.iconName)
    }
}
