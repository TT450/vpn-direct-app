import Foundation
import Libbox

/// Typed validation result for sing-box JSON produced by VPN Direct builders.
public struct VPNDirectValidationResult: Equatable, Sendable {
    public enum Code: String, Sendable {
        case valid
        case malformed
        case unsupportedProtocol
        case unsupportedTransport
        case unsupportedSecurity
        case unsupportedFeature
        case coreRejected
    }

    public var code: Code
    public var ecosystem: String?
    public var protocolID: String?
    public var component: String?
    public var userMessage: String
    public var debugMessage: String
    public var json: String

    public var isValid: Bool { code == .valid }

    public init(
        code: Code,
        ecosystem: String? = nil,
        protocolID: String? = nil,
        component: String? = nil,
        userMessage: String,
        debugMessage: String,
        json: String = ""
    ) {
        self.code = code
        self.ecosystem = ecosystem
        self.protocolID = protocolID
        self.component = component
        self.userMessage = userMessage
        self.debugMessage = debugMessage
        self.json = json
    }
}

public enum VPNDirectConfigValidator {
    /// Validates config via LibboxCheckConfig. Strips any leftover `_vpndirect_*` keys first.
    public static func validateSingBoxJSON(
        _ json: String,
        ecosystem: String? = nil,
        protocolID: String? = nil
    ) throws -> VPNDirectValidationResult {
        let cleaned = try stripInternalKeys(json)
        var error: NSError?
        LibboxCheckConfig(cleaned, &error)
        if let error {
            let detail = error.localizedDescription
            VPNDirectLog.validator.error("coreRejected: \(VPNDirectRedactor.redact(detail))")
            throw VPNDirectCoreError.coreRejected(
                ecosystem: ecosystem,
                protocolID: protocolID,
                detail: detail
            )
        }
        return VPNDirectValidationResult(
            code: .valid,
            ecosystem: ecosystem,
            protocolID: protocolID,
            userMessage: "Configuration is valid",
            debugMessage: "LibboxCheckConfig OK",
            json: cleaned
        )
    }

    private static func stripInternalKeys(_ json: String) throws -> String {
        guard let data = json.data(using: .utf8),
              var root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw VPNDirectCoreError.malformedConfig(component: "json", detail: "Invalid JSON")
        }
        if var outbounds = root["outbounds"] as? [[String: Any]] {
            for i in outbounds.indices {
                outbounds[i] = outbounds[i].filter { !$0.key.hasPrefix("_vpndirect_") }
            }
            root["outbounds"] = outbounds
        }
        let out = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        guard let text = String(data: out, encoding: .utf8) else {
            throw VPNDirectCoreError.malformedConfig(component: "json", detail: "UTF-8 encode failed")
        }
        return text
    }
}
