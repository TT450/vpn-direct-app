import Foundation

/// Shared validation for Remnawave / panel stub endpoints.
public enum EndpointValidator {
    /// Hosts that mean “panel refused this client” or invalid placeholder nodes.
    public static let blockedLoopbackHosts: Set<String> = [
        "127.0.0.1",
        "::1",
        "0.0.0.0",
        "localhost",
    ]

    public static func isBlockedLoopbackHost(_ host: String) -> Bool {
        blockedLoopbackHosts.contains(host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    public static func isPanelStubLink(_ link: String) -> Bool {
        let lower = link.lowercased()
        if lower.contains("@127.0.0.1:1") { return true }
        if lower.contains("00000000-0000-0000-0000-000000000000") { return true }
        return false
    }
}
