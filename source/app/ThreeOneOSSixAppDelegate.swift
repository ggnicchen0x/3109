// ThreeOneOSSixAppDelegate.swift — UIKit application delegate adapter
// Reconstructed from 5013 v3.2.17 binary
//
// Three methods:
// - didFinishLaunchingWithOptions: extracts launch URL, enqueues via IncomingURLRouter
// - openURL: enqueues URL via IncomingURLRouter
// - configurationForConnecting: returns UISceneConfiguration with ThreeOneOSSixSceneDelegate

import UIKit

class ThreeOneOSSixAppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let launchOptions = launchOptions,
           let url = launchOptions[.url] as? URL {
            IncomingURLRouter.shared.enqueue(url, at: Date())
        }
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        IncomingURLRouter.shared.enqueue(url, at: Date())
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Enqueue any URLs from the connection options
        for context in options.urlContexts {
            IncomingURLRouter.shared.enqueue(context.url, at: Date())
        }

        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )

        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = ThreeOneOSSixSceneDelegate.self
        }

        return configuration
    }
}
