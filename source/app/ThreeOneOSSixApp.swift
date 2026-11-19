// ThreeOneOSSixApp.swift — Main App entry point
// Reconstructed from 5013 v3.2.17 binary
//
// SwiftUI App struct with UIApplicationDelegateAdaptor.
// 8 @StateObject environment objects injected into the view hierarchy.
// At launch: LegacyStorageMigration, SandboxAccess.prepare(), TempSpaceRegistry.purgeExpired()

import SwiftUI

@main
struct ThreeOneOSSixApp: App {

    @UIApplicationDelegateAdaptor(ThreeOneOSSixAppDelegate.self) var appDelegate

    @StateObject private var appState = AppState()
    @StateObject private var incomingURLRouter = IncomingURLRouter.shared
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @StateObject private var patchStore = PatchProjectStore()
    @StateObject private var repositoryStore = PackageRepositoryStore()
    @StateObject private var migrationTaskCenter = MigrationTaskCenter()
    @StateObject private var themeManager = AppThemeManager()

    @AppStorage("appLanguage") private var appLanguage: String = ""

    @State private var showOnboarding: Bool = false
    @State private var showOtherFlag: Bool = false
    @State private var updateOffer: AppUpdateChecker.Offer?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    init() {
        let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "5013"
        let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        log("app: 5013 \(displayName) (\(bundleVersion)) iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")

        LegacyStorageMigration.migrateIfNeeded(fileManager: .default)
        SandboxAccess.prepare()
        TempSpaceRegistry.purgeExpired(now: Date())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(incomingURLRouter)
                .environmentObject(patchDraftCoordinator)
                .environmentObject(fileOperationCoordinator)
                .environmentObject(patchStore)
                .environmentObject(repositoryStore)
                .environmentObject(migrationTaskCenter)
                .environmentObject(themeManager)
                .onAppear {
                    appState.detectSupport()
                    if OnboardingStore.shouldShowOnboarding {
                        showOnboarding = true
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        checkForUpdateThrottled()
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    // OnboardingView()
                }
        }
    }

    // MARK: - Update checking

    private func checkForUpdateThrottled() {
        Task {
            await AppUpdateChecker.checkThrottled { offer in
                updateOffer = offer
            }
        }
    }

    private func checkForUpdate() {
        Task {
            await AppUpdateChecker.check { offer in
                updateOffer = offer
            }
        }
    }

    // MARK: - URL handling

    private func consumeIncomingURL() {
        Task {
            guard let request = incomingURLRouter.currentRequest else { return }
            // Massive URL routing (56+ async continuations in binary)
            // Routes include: patch import, wallpaper staging, migration config backup,
            // external document kinds, shared destinations
            incomingURLRouter.finish(request.id)
        }
    }

    private func consumeExternalImport() {
        Task {
            // Handles external document import with multiple async continuations
        }
    }

    private func presentSharedDestination(_ destination: PatchDraftCoordinator.SharedDestination) async throws {
        // Presents shared content via PatchDraftCoordinator
    }

    private func showSharedImportSuccess(_ url: URL) {
        // Shows success indicator after shared import
    }

    var hasBlockingPresentation: Bool {
        // Checks UIWindowScene for blocking presentations
        return false
    }
}
