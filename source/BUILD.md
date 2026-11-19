# 5013 — Reconstructed Source Build Guide

## Source Structure (70 files)

```
source/
├── app/                                # App entry point and delegates
│   ├── ThreeOneOSSixApp.swift          # @main SwiftUI App struct (8 @StateObject, init, body)
│   ├── ThreeOneOSSixAppDelegate.swift  # UIKit delegate (URL handling, scene config)
│   ├── ThreeOneOSSixSceneDelegate.swift # UIWindowSceneDelegate
│   ├── app_info.h                      # ObjC app enumeration API
│   └── app_info.m                      # MobileInstallation + LSApplicationWorkspace
│
├── services/                           # Business logic and state (38 files)
│   ├── AppState.swift                  # Main exploit orchestration (~270 lines)
│   ├── ExploitSupportPolicy.swift      # OS version support matrix (iOS 15–27)
│   ├── SandboxBackend.swift            # 6-case enum (legacyContainerNote, kernel, etc.)
│   ├── ExploitStatus.swift             # idle/running/failed/ready lifecycle
│   ├── KernelExploit.swift             # Kernel exploit applicability
│   ├── SandboxAccess.swift             # Sandbox state + @_cdecl C bridge
│   ├── IncomingURLRouter.swift         # URL intake queue with full routing engine
│   ├── AppInfo.swift                   # Device/OS info (sysctl wrappers)
│   ├── Logger.swift                    # os.log wrapper
│   ├── AppLog.swift                    # In-memory log with export
│   ├── ScanCoordinator.swift           # File scan orchestration with results
│   ├── ScanToken.swift                 # Cancellation token for scans
│   ├── AppUpdateChecker.swift          # Throttled version check with Offer struct
│   ├── LegacyStorageMigration.swift    # One-shot legacy data migration
│   ├── TempSpaceRegistry.swift         # Temp file lease registry (61 symbols)
│   ├── OnboardingStore.swift           # First-launch flag
│   ├── AppThemeManager.swift           # Theme management with 7 color themes
│   ├── AppThemePalette.swift           # Theme color palette (ObservableObject)
│   ├── PatchDraftCoordinator.swift     # Patch draft lifecycle with apply()
│   ├── FileOperationCoordinator.swift  # File copy/move/delete with progress
│   ├── PatchProjectStore.swift         # Patch project CRUD persistence
│   ├── PatchProgressMailbox.swift      # Patch progress reporting
│   ├── PackageRepositoryStore.swift    # Repository list management
│   ├── MigrationTaskCenter.swift       # Migration task orchestration
│   ├── MigrationEngine.swift           # File migration with plans/resume/cancel
│   ├── MigrationConfigBackupService.swift # Config backup import/export/apply
│   ├── AirLiftService.swift            # AirLift sandbox escape (singleton, serial queue)
│   ├── BackupCenter.swift              # File backup/restore/versioning (241 functions)
│   ├── SQLiteReader.swift              # Direct SQLite3 read access
│   ├── SQLiteSidecarPolicy.swift       # WAL/SHM/journal sidecar handling
│   ├── AppNoticeCenter.swift           # Toast notification system (glass overlay)
│   ├── ContainerPathCache.swift        # Codable container path cache + MCM bridge
│   ├── FileFavoritesStore.swift        # Bookmark/favorites system
│   ├── GestaltBaselineStore.swift      # Device gestalt baseline comparison
│   ├── SharedURLAccess.swift           # Security-scoped URL bookmark manager
│   ├── SharedFilePreparation.swift     # Staging files for operations
│   ├── Pathleak.swift                  # Inode-based path enumeration (multi-threaded)
│   ├── PlistDocument.swift             # Plist read/write/keyPath access
│   ├── CleanerSafetyPolicy.swift       # System path risk classification
│   ├── StoreIconFallbackService.swift  # App Store icon fetching with cache
│   ├── RepositoryImageLoader.swift     # Async image loader + pipeline with NSCache
│   └── ExternalDocumentInbox.swift     # Document inbox file acceptance
│
├── views/                              # SwiftUI views (9 files)
│   ├── ContentView.swift               # Main adaptive layout (regular + compact)
│   ├── AppSection.swift                # Navigation section enum (5 cases)
│   ├── AppLogo.swift                   # App logo view
│   ├── CompactTabLabel.swift           # Tab item label
│   ├── FileBrowserView.swift           # Full file manager (sort/filter/import/export/rename/delete/QuickLook)
│   ├── SettingsView.swift              # Settings with all sub-views (theme, backup, airlift, log, etc.)
│   ├── ScanProgressSheet.swift         # Scan progress + results display
│   ├── PatchEditorView.swift           # Patch project editor with detail view
│   └── RepositoryBrowserView.swift     # Repository browser with package details
│
├── exploit/                            # C kernel exploit chain (8 files)
│   ├── offsets.h                       # Kernel structure offsets declarations
│   ├── offsets.c                       # Offset initialization (~700 lines, iOS 17–26)
│   ├── exploit.h                       # Main exploit interface
│   ├── exploit.c                       # Socket PCB corruption exploit (opa334)
│   ├── krw.h                           # Kernel R/W primitives header
│   ├── krw.c                           # ICMPv6 socket kernel R/W
│   ├── physical.h                      # Physical memory R/W header
│   └── physical.c                      # IOSurface mapping + fd race
│
├── sandbox/
│   └── sandbox_escape.c                # Credential label rewriting
│
├── mcm/
│   ├── mcm_bridge.h                    # MCM private XPC API declarations
│   └── mcm_bridge.m                    # MCM bridge implementation
│
├── worse_query/
│   ├── worse_query.h                   # WQ sandbox extension declarations
│   └── worse_query.m                   # WQ grant system
│
├── 5013-Bridging-Header.h              # C/ObjC-to-Swift bridging
├── Info.plist                          # App config (com.5013.app, v3.2.17, iOS 15.0+)
├── 5013.xcodeproj/project.pbxproj      # Xcode project skeleton
└── BUILD.md                            # This file
```

## Build Requirements

- macOS with Xcode 15+
- iOS 15.0 deployment target
- Swift 5.9+
- AArch64 only (exploit code is ARM64 specific)

## Setup

1. Create new Xcode project: iOS App, SwiftUI lifecycle, bundle ID `com.5013.app`
2. Add all Swift sources from `app/`, `services/`, `views/` to the main target
3. Create a C static library target for `exploit/`, `sandbox/`, `mcm/`, `worse_query/`
4. Set bridging header to `5013-Bridging-Header.h`
5. Link the C library target to the main app target
6. Add required frameworks: `IOKit`, `IOSurface` (for exploit code)
7. Add private framework imports for `MobileContainerManager`, `MobileInstallation`, `LSApplicationWorkspace`
8. Link `libsqlite3.tbd` for SQLiteReader

## Signing

The original binary runs unsigned with entitlements granted by the jailbreak.
For development: use a signing identity with appropriate entitlements.

## Reconstruction Coverage

- **Kernel exploit chain**: Complete C implementation (offsets, exploit, krw, physical, sandbox escape)
- **Swift app lifecycle**: Complete (App struct, delegates, URL routing, state management)
- **Services layer**: 38 files covering all identified classes with full implementations
- **UI views**: 9 files covering all navigation sections with working UI
- **Utility types**: Complete (PlistDocument, SQLite, safety policies, image loading, etc.)

**Total: 70 source files reconstructed from 5682 functions in the original binary.**

Binary: 5013 v3.2.17 (AArch64, Apple Silicon)
MD5: 96a3f37255406c002519d074701fee6c
