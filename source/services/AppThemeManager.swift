import SwiftUI
import Combine

final class AppThemeManager: ObservableObject {

    @Published var currentTheme: String = "Default"
    @Published var accentColor: Color = .blue

    private static let themeKey = "5013.selectedTheme"

    private let themes: [String: Color] = [
        "Default": .blue,
        "Red": .red,
        "Orange": .orange,
        "Green": .green,
        "Purple": .purple,
        "Pink": .pink,
        "Indigo": .indigo,
    ]

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.themeKey),
           let color = themes[saved] {
            currentTheme = saved
            accentColor = color
        }
    }

    func setTheme(_ name: String) {
        guard let color = themes[name] else { return }
        currentTheme = name
        accentColor = color
        UserDefaults.standard.set(name, forKey: Self.themeKey)
    }

    func apply(_ themeName: String) {
        setTheme(themeName)
    }

    var availableThemes: [String] {
        Array(themes.keys).sorted()
    }
}
