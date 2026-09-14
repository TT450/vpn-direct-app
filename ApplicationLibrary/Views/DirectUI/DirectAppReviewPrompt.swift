import Foundation
import StoreKit
import UIKit

#if os(iOS)

/// Native App Store review prompt after a successful VPN connect.
///
/// Timing we control:
/// - 30s after a successful connect (disconnect does not cancel)
/// - first successful connect, then at most once every 14 days between *attempts*
///
/// Apple still rate-limits how often the system sheet actually appears
/// (typically a few times per year) — there is no native 2-week Apple timer.
@MainActor
enum DirectAppReviewPrompt {
    private static let lastPromptAtKey = "vpndirect.review.lastPromptAt.v1"
    private static let delayNanoseconds: UInt64 = 30 * 1_000_000_000
    private static let cooldown: TimeInterval = 14 * 24 * 60 * 60

    private static var scheduledTask: Task<Void, Never>?

    static func scheduleAfterSuccessfulConnect() {
        guard isEligible else { return }
        // Keep the first pending timer; reconnect must not reset the 30s wait.
        guard scheduledTask == nil else { return }
        scheduledTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            guard isEligible else { return }
            presentIfPossible()
        }
    }

    private static var isEligible: Bool {
        guard let last = UserDefaults.standard.object(forKey: lastPromptAtKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(last) >= cooldown
    }

    private static func presentIfPossible() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            scheduledTask = nil
            return
        }
        UserDefaults.standard.set(Date(), forKey: lastPromptAtKey)
        SKStoreReviewController.requestReview(in: scene)
        scheduledTask = nil
    }
}

#endif
