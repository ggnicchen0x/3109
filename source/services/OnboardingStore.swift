// OnboardingStore.swift — First-launch onboarding state
// Reconstructed from 5013 v3.2.17 binary

import Foundation

enum OnboardingStore {

    private static let key = "hasCompletedOnboarding"

    static var shouldShowOnboarding: Bool {
        !UserDefaults.standard.bool(forKey: key)
    }

    static func markComplete() {
        UserDefaults.standard.set(true, forKey: key)
    }
}
