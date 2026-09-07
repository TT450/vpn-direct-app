import Foundation

/// Minimal stand-in: adapters only throw nested `SubscriptionError` cases.
public enum SubscriptionConfigBuilder {
    public enum SubscriptionError: LocalizedError {
        case empty
        case noSupportedLinks
        case unsupportedFeatures([String])
        case serializationFailed
        case panelRejected(String)
        case xrayJSONUnsupported

        public var errorDescription: String? {
            switch self {
            case .empty:
                return "Subscription is empty"
            case .noSupportedLinks:
                return "No supported share links or subscription format found"
            case let .unsupportedFeatures(components):
                return "Subscription requires unsupported features: \(components.joined(separator: ", "))"
            case .serializationFailed:
                return "Failed to serialize subscription configuration"
            case let .panelRejected(message):
                return message
            case .xrayJSONUnsupported:
                return "Unsupported XRAY JSON subscription format"
            }
        }
    }
}
