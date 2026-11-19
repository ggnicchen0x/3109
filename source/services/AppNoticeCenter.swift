import Foundation
import UIKit
import SwiftUI

final class AppNoticeCenter {

    static let shared = AppNoticeCenter()

    private var windowManager: GlassToastWindowManager?
    private let lock = NSLock()
    private var pendingQueue: [(String, NoticeLevel)] = []

    private init() {}

    func configure(windowScene: UIWindowScene) {
        lock.lock()
        defer { lock.unlock() }
        windowManager = GlassToastWindowManager(windowScene: windowScene)
        for (message, level) in pendingQueue {
            windowManager?.show(message: message, level: level)
        }
        pendingQueue.removeAll()
    }

    func post(_ message: String, level: NoticeLevel = .info) {
        lock.lock()
        if let wm = windowManager {
            lock.unlock()
            wm.show(message: message, level: level)
        } else {
            pendingQueue.append((message, level))
            lock.unlock()
        }
    }

    func postError(_ error: Error) {
        post(error.localizedDescription, level: .error)
    }

    func dismiss() {
        windowManager?.dismissCurrent()
    }
}

enum NoticeLevel {
    case info
    case success
    case warning
    case error
}

final class GlassToastWindowManager {

    private var toastWindow: GlassToastPassthroughWindow?
    private let windowScene: UIWindowScene
    private var dismissWork: DispatchWorkItem?

    init(windowScene: UIWindowScene) {
        self.windowScene = windowScene
    }

    func show(message: String, level: NoticeLevel, duration: TimeInterval = 3.0) {
        DispatchQueue.main.async { [weak self] in
            self?.dismissWork?.cancel()
            self?.presentToast(message: message, level: level, duration: duration)
        }
    }

    func dismissCurrent() {
        DispatchQueue.main.async { [weak self] in
            self?.hideToast()
        }
    }

    private func presentToast(message: String, level: NoticeLevel, duration: TimeInterval) {
        let window: GlassToastPassthroughWindow
        if let existing = toastWindow {
            window = existing
        } else {
            window = GlassToastPassthroughWindow(windowScene: windowScene)
            window.windowLevel = .alert + 1
            window.isHidden = false
            toastWindow = window
        }

        let hosting = UIHostingController(rootView: GlassToastView(message: message, level: level))
        hosting.view.backgroundColor = .clear
        window.rootViewController = hosting

        let work = DispatchWorkItem { [weak self] in
            self?.hideToast()
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func hideToast() {
        dismissWork?.cancel()
        dismissWork = nil
        UIView.animate(withDuration: 0.25) {
            self.toastWindow?.alpha = 0
        } completion: { _ in
            self.toastWindow?.isHidden = true
            self.toastWindow?.alpha = 1
            self.toastWindow = nil
        }
    }
}

final class GlassToastPassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view === self ? nil : view
    }
}

struct GlassToastView: View {
    let message: String
    let level: NoticeLevel

    private var iconName: String {
        switch level {
        case .info:    return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error:   return "xmark.octagon.fill"
        }
    }

    private var tintColor: Color {
        switch level {
        case .info:    return .blue
        case .success: return .green
        case .warning: return .orange
        case .error:   return .red
        }
    }

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .foregroundColor(tintColor)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
