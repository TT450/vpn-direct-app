import Foundation

/// Explicit honesty helpers for panel routing / smart-proxy metadata that is
/// stored but not applied to the production sing-box graph (REQ-P018 / REQ-P019).
public enum VPNDirectRoutingHonesty {
    /// Warnings when subscription metadata carries routing that the graph builder will ignore.
    public static func ignoredRoutingWarnings(for metadata: SubscriptionMetadata) -> [String] {
        var out: [String] = []
        if metadata.routingEnabled == true || !(metadata.routingRules ?? "").isEmpty {
            out.append(
                "Panel routing metadata present but not applied to production graph (nodes-only / ignored-with-warning)."
            )
        }
        return out
    }

    public static func ignoredRoutingWarnings(for subscription: NormalizedSubscription) -> [String] {
        ignoredRoutingWarnings(for: subscription.metadata)
    }
}
