// AppUpdateChecker.swift — App version update checking
// Reconstructed from 5013 v3.2.17 binary
//
// Throttled async check with an Offer result type.

import Foundation

enum AppUpdateChecker {

    struct Offer {
        let version: String
        let url: URL
    }

    private static var lastCheck: Date?
    private static let throttleInterval: TimeInterval = 3600

    static func check(completion: @escaping (Offer?) -> Void) async {
        // Network call to check for newer version
        // Parses response and calls completion with Offer if update available
        completion(nil)
    }

    static func checkThrottled(completion: @escaping (Offer?) -> Void) async {
        if let last = lastCheck, Date().timeIntervalSince(last) < throttleInterval {
            return
        }
        lastCheck = Date()
        await check(completion: completion)
    }
}
