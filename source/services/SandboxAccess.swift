// SandboxAccess.swift — Sandbox access state management
// Reconstructed from 5013 v3.2.17 binary
//
// Manages which sandbox backend is active and caches probe results.

import Foundation

enum SandboxAccess {

    private static let probeCacheLock = NSLock()
    private static var probeCache: (value: Bool, at: Date)?

    static var backend: SandboxBackend {
        // Determined at startup based on OS version and device capabilities.
        // The binary reads this from a global that is set during detectSupport.
        // Default to .unsupported; the real value is set by AppState.detectSupport.
        return _currentBackend
    }

    private(set) static var _currentBackend: SandboxBackend = .unsupported

    static func setBackend(_ backend: SandboxBackend) {
        _currentBackend = backend
    }

    static func prepare() {
        // Sandbox preparation: called once at app launch.
        // Ensures the sandbox environment is ready for the selected backend.
    }

    static func probeCachedResult() -> Bool? {
        probeCacheLock.lock()
        defer { probeCacheLock.unlock() }

        guard let cache = probeCache else { return nil }
        return cache.value
    }

    static func setProbeCachedResult(_ value: Bool) {
        probeCacheLock.lock()
        defer { probeCacheLock.unlock() }
        probeCache = (value: value, at: Date())
    }
}

// C bridge: called from sandbox_escape.c
@_cdecl("sandbox_access_is_active")
func sandbox_access_is_active() -> UInt8 {
    return SandboxAccess.probeCachedResult() == true ? 1 : 0
}
