// AppState.swift — Main exploit orchestration state
// Reconstructed from 5013 v3.2.17 binary
//
// ObservableObject that drives the UI. Manages:
// - Support detection (which backend to use)
// - Kernel exploit lifecycle
// - Query access setup (worseQuery/badQuery)
// - Auto-run logic

import Foundation
import Combine

class AppState: ObservableObject {

    @Published var exploitStatus: ExploitStatus = .ready(backend: .unsupported)
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning: Bool = false

    private var autoRunAttempted = false

    // MARK: - detectSupport

    func detectSupport() {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let build = AppInfo.osBuild

        let supported = ExploitSupportPolicy.isSupported(
            major: v.majorVersion, minor: v.minorVersion,
            patch: v.patchVersion, build: build
        )

        if !supported {
            let msg = "iOS \(AppInfo.osVersion) (\(build))"
            unsupportedMessage = msg
        } else {
            unsupportedMessage = nil
        }

        if unsupportedMessage != nil {
            exploitStatus = .failed(backend: .unsupported, message: unsupportedMessage)
            return
        }

        // Check OS major version range (16+)
        let major = v.majorVersion
        guard (1...15).contains(major - 1) else {
            // Unsupported major version
            let backend = SandboxAccess.backend
            switch backend {
            case .legacyContainerNote, .kernel, .badQuery:
                break
            case .worseQuery:
                break
            case .airLift:
                break
            case .unsupported:
                break
            }
            exploitStatus = .ready(backend: .unsupported)
            return
        }

        let backend = SandboxAccess.backend

        if backend == .airLift {
            // AirLift backend: set up directly
            exploitStatus = .ready(backend: .unsupported)
            return
        }

        if backend == .badQuery {
            // badQuery backend: run query access setup
            runQueryAccessSetup(backend: backend, forceFresh: false)
            return
        }

        if backend == .worseQuery {
            // worseQuery backend: run query access setup
            runQueryAccessSetup(backend: backend, forceFresh: false)
            return
        }

        // kernel backend: check if kernel exploit is applicable
        let kernelApplicable = KernelExploit.isApplicable(
            major: v.majorVersion, minor: v.minorVersion,
            patch: v.patchVersion, build: build
        )

        guard kernelApplicable else { return }

        refreshKernelExploitStatus()
        maybeAutoRunKernelExploit()
    }

    // MARK: - refreshKernelExploitStatus

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }

        guard KernelExploit.requiresSandboxEscape else { return }

        let backend = SandboxAccess.backend
        switch backend {
        case .legacyContainerNote, .kernel:
            // Check if sandbox access is already active
            if backend != .legacyContainerNote {
                let active = sandbox_access_is_active()
                guard active == 1 else {
                    // Not active yet — check probe cache
                    let cached = SandboxAccess.probeCachedResult()
                    if cached == nil {
                        // No cached result — set ready with current backend
                        exploitStatus = .ready(backend: backend)
                        log("app: sandbox escape not probed yet, waiting")
                        return
                    }
                    break
                }
            }
            // Sandbox access is active — existing status stands
            if case .idle = exploitStatus {
                break
            }
            if case .running = exploitStatus {
                log("app: existing \(backend.rawValue) sandbox already active")
                return
            }

        case .badQuery, .worseQuery:
            // Query backends: check probe cache
            if let cached = SandboxAccess.probeCachedResult() {
                guard cached else { break }
            } else {
                break
            }
            // Probe cache says active
            if case .idle = exploitStatus {
                break
            }
            if case .running = exploitStatus {
                log("app: existing \(backend.rawValue) sandbox already active")
                return
            }

        case .airLift, .unsupported:
            break
        }

        exploitStatus = .ready(backend: backend)
    }

    // MARK: - maybeAutoRunKernelExploit

    private func maybeAutoRunKernelExploit() {
        guard !kernelExploitRunning else { return }

        if case .idle = exploitStatus { return }
        if case .running = exploitStatus { return }

        guard !autoRunAttempted else { return }
        autoRunAttempted = true

        log("app: auto-running kernel exploit on first launch")
        runKernelExploitIfNeeded()
    }

    // MARK: - runKernelExploitIfNeeded

    func runKernelExploitIfNeeded() {
        let backend = SandboxAccess.backend

        if backend == .airLift { return }

        if backend == .badQuery {
            // badQuery: run query access setup with force fresh
            runQueryAccessSetup(backend: backend, forceFresh: true)
            return
        }

        if backend == .worseQuery {
            // worseQuery: run query access setup with force fresh
            runQueryAccessSetup(backend: backend, forceFresh: true)
            return
        }

        // Kernel backend
        refreshKernelExploitStatus()

        guard !kernelExploitRunning else { return }

        if case .idle = exploitStatus { return }
        if case .running = exploitStatus {
            // Already running — check if it's actually done
            if case .ready = exploitStatus { return }

            kernelExploitRunning = true
            exploitStatus = .ready(backend: .unsupported)

            log("app: running \(backend.rawValue) kernel exploit")

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.executeKernelExploit(backend: backend)
            }
            return
        }
    }

    // MARK: - runQueryAccessSetup

    private func runQueryAccessSetup(backend: SandboxBackend, forceFresh: Bool) {
        guard !kernelExploitRunning else { return }
        guard unsupportedMessage == nil else { return }

        let v = ProcessInfo.processInfo.operatingSystemVersion
        let build = AppInfo.osBuild

        let kernelApplicable = KernelExploit.isApplicable(
            major: v.majorVersion, minor: v.minorVersion,
            patch: v.patchVersion, build: build
        )
        guard kernelApplicable else { return }

        let currentBackend = SandboxAccess.backend
        guard currentBackend == backend else { return }

        kernelExploitRunning = true

        if !forceFresh {
            // Check probe cache
            if let cached = SandboxAccess.probeCachedResult() {
                if cached {
                    exploitStatus = .ready(backend: .unsupported)
                }
            }
        }

        exploitStatus = .ready(backend: .unsupported)

        log("app: verifying \(backend.rawValue), forceFresh=\(forceFresh)")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.executeQuerySetup(forceFresh: forceFresh, backend: backend)
        }
    }

    // MARK: - Execution (dispatched to background)

    private func executeKernelExploit(backend: SandboxBackend) {
        // Calls into the C exploit chain:
        // 1. offsets_init()
        // 2. exploit_run()
        // 3. sandbox_escape()
        // On completion, updates exploitStatus on main thread

        DispatchQueue.main.async { [weak self] in
            self?.kernelExploitRunning = false
            self?.refreshKernelExploitStatus()
        }
    }

    private func executeQuerySetup(forceFresh: Bool, backend: SandboxBackend) {
        // Calls into worse_query or bad_query C functions
        // to establish sandbox extension access

        DispatchQueue.main.async { [weak self] in
            self?.kernelExploitRunning = false
            self?.refreshKernelExploitStatus()
        }
    }
}
