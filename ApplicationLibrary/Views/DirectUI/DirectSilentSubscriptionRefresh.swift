import Foundation
import Library

/// Handles silent APNs `cmd=refresh_subscription` — refresh remote profiles + reload tunnel if needed.
@MainActor
public enum DirectSilentSubscriptionRefresh {
    private static var inFlight = false

    public static func handleFromPush() async {
        guard !inFlight else { return }
        inFlight = true
        defer { inFlight = false }
        do {
            let profiles = try await ProfileManager.list()
            var refreshed = 0
            for profile in profiles {
                guard profile.type == .remote,
                      let url = profile.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !url.isEmpty,
                      !DirectBuiltinProfile.isBuiltin(profile.remoteURL)
                else { continue }
                do {
                    try await profile.updateRemoteProfile()
                    refreshed += 1
                } catch {
                    print("silent refresh profile \(profile.id) failed: \(error.localizedDescription)")
                }
            }
            if refreshed > 0 {
                NotificationCenter.default.post(name: .vpnDirectSilentSubscriptionRefreshed, object: nil)
                if let extensionProfile = try? await ExtensionProfile.load(),
                   await extensionProfile.status.isConnected
                {
                    try? await extensionProfile.reloadService()
                }
            }
            print("silent refresh done profiles=\(refreshed)")
        } catch {
            print("silent refresh list failed: \(error.localizedDescription)")
        }
    }
}
