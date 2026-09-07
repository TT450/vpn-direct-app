import Foundation

/// Panel / Remnawave HTTP response classification (REQ-P022 / REQ-P058).
///
/// Mirror of Library/Service/VPNDirect/VPNDirectSubscriptionHTTPClassifier.swift for SPM tests.
/// Keep in sync with the Library source (symlink preferred when disk allows).
///
/// Does not invent panel-specific meaning for arbitrary HTML 403 bodies —
/// only classifies when status, headers, or evidence-backed body markers match.
public enum VPNDirectImportHTTPCategory: String, Sendable, Equatable, CaseIterable {
    case ok
    case deviceLimitReached
    case subscriptionExpired
    case subscriptionDisabled
    case hwidRejected
    case panelBlocked
    case notFound
    case unauthorized
    case unavailableForLegalReasons
    case socketDrop
    case browserPayload
    case malformedResponse
    case unsupportedFormat
    case networkError
    case httpError
}

public enum VPNDirectRemnawaveResponseType: String, Sendable, Equatable, CaseIterable {
    case xrayJSON = "XRAY_JSON"
    case xrayBase64 = "XRAY_BASE64"
    case mihomo = "MIHOMO"
    case stash = "STASH"
    case clash = "CLASH"
    case singbox = "SINGBOX"
    case browser = "BROWSER"
    case block = "BLOCK"
    case status404 = "STATUS_CODE_404"
    case status451 = "STATUS_CODE_451"
    case socketDrop = "SOCKET_DROP"
    case unknown = "UNKNOWN"
}

public enum VPNDirectSubscriptionHTTPClassifier {
    public struct Classification: Equatable, Sendable {
        public var category: VPNDirectImportHTTPCategory
        public var responseType: VPNDirectRemnawaveResponseType
        public var userSafeMessage: String
        public var retryable: Bool
        public var evidence: String
    }

    public static func classifyHTTPError(statusCode: Int, headers: [String: String], body: String, userAgent: String = "") -> Classification {
        let normalized = normalizeHeaders(headers)
        let bodyLower = body.lowercased()
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if looksLikeBrowserHTML(trimmed) {
            return Classification(category: .browserPayload, responseType: .browser, userSafeMessage: String(localized: "Server returned a web page instead of a VPN subscription."), retryable: true, evidence: "html_body status=\(statusCode)")
        }
        if statusCode == 451 {
            return Classification(category: .unavailableForLegalReasons, responseType: .status451, userSafeMessage: String(localized: "Subscription is unavailable (HTTP 451)."), retryable: false, evidence: "status=451")
        }
        if statusCode == 404 {
            return Classification(category: .notFound, responseType: .status404, userSafeMessage: String(localized: "Subscription was not found (HTTP 404)."), retryable: false, evidence: "status=404")
        }
        if statusCode == 401 || statusCode == 403 {
            if hwidDeviceLimitReached(normalized) { return Classification(category: .deviceLimitReached, responseType: .block, userSafeMessage: String(localized: "Device limit reached for this subscription."), retryable: false, evidence: "hwid_device_limit headers") }
            if hwidRejected(normalized, bodyLower: bodyLower) { return Classification(category: .hwidRejected, responseType: .block, userSafeMessage: String(localized: "This device was rejected by the subscription provider."), retryable: false, evidence: "hwid_rejected") }
            if subscriptionExpired(normalized, bodyLower: bodyLower) { return Classification(category: .subscriptionExpired, responseType: .block, userSafeMessage: String(localized: "Subscription has expired."), retryable: false, evidence: "expired") }
            if subscriptionDisabled(normalized, bodyLower: bodyLower) { return Classification(category: .subscriptionDisabled, responseType: .block, userSafeMessage: String(localized: "Subscription is disabled."), retryable: false, evidence: "disabled") }
            if panelBlocked(normalized, bodyLower: bodyLower) { return Classification(category: .panelBlocked, responseType: .block, userSafeMessage: String(localized: "Subscription access is blocked by the provider."), retryable: false, evidence: "blocked") }
            if statusCode == 401 { return Classification(category: .unauthorized, responseType: .block, userSafeMessage: String(localized: "Subscription authorization failed."), retryable: false, evidence: "status=401") }
            return Classification(category: .httpError, responseType: .block, userSafeMessage: String(localized: "Subscription server returned HTTP \(statusCode)."), retryable: false, evidence: "status=\(statusCode) no_panel_evidence")
        }
        if statusCode == 0 || statusCode == -1 {
            return Classification(category: .networkError, responseType: .unknown, userSafeMessage: String(localized: "Network error while downloading subscription."), retryable: true, evidence: "status=\(statusCode) ua=\(userAgent.prefix(24))")
        }
        if statusCode >= 500 {
            return Classification(category: .networkError, responseType: .unknown, userSafeMessage: String(localized: "Subscription server error (HTTP \(statusCode))."), retryable: true, evidence: "status=\(statusCode)")
        }
        return Classification(category: .httpError, responseType: .unknown, userSafeMessage: String(localized: "Subscription server returned HTTP \(statusCode)."), retryable: false, evidence: "status=\(statusCode)")
    }

    public static func classifySuccessBody(_ body: String, headers: [String: String] = [:]) -> VPNDirectRemnawaveResponseType {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if looksLikeBrowserHTML(trimmed) { return .browser }
        let detection = VPNDirectContentDetector.detect(text: trimmed)
        switch detection.kind {
        case .xrayJSON: return .xrayJSON
        case .singBoxJSON: return .singbox
        case .clashYAML:
            let normalized = normalizeHeaders(headers)
            if (normalized["content-disposition"] ?? "").lowercased().contains("stash") || (normalized["x-subscription-format"] ?? "").lowercased().contains("stash") { return .stash }
            if (normalized["x-subscription-format"] ?? "").lowercased().contains("mihomo") || (normalized["profile-web-page-url"] ?? "").lowercased().contains("mihomo") { return .mihomo }
            return .clash
        case .base64URIList: return .xrayBase64
        case .uriList, .wireGuardConf, .mieruJSON, .recognizedUnsupported, .unknown: return .unknown
        }
    }

    private static func normalizeHeaders(_ headers: [String: String]) -> [String: String] { Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) }) }
    private static func parseBool(_ raw: String?) -> Bool? {
        guard let raw else { return nil }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on": return true
        case "0", "false", "no", "off": return false
        default: return nil
        }
    }
    private static func hwidDeviceLimitReached(_ headers: [String: String]) -> Bool {
        if parseBool(headers["x-hwid-max-devices-reached"]) == true { return true }
        if let limit = Int(headers["x-hwid-device-limit"] ?? headers["x-device-limit"] ?? ""), let used = Int(headers["x-hwid-device-used"] ?? headers["x-device-used"] ?? ""), limit > 0, used >= limit { return true }
        return false
    }
    private static func hwidRejected(_ headers: [String: String], bodyLower: String) -> Bool {
        if parseBool(headers["x-hwid-not-supported"]) == true { return true }
        return bodyLower.contains("hwid") && (bodyLower.contains("reject") || bodyLower.contains("invalid"))
    }
    private static func subscriptionExpired(_ headers: [String: String], bodyLower: String) -> Bool {
        if parseBool(headers["x-subscription-expired"]) == true { return true }
        return bodyLower.contains("expired") || (bodyLower.contains("expire") && bodyLower.contains("subscription"))
    }
    private static func subscriptionDisabled(_ headers: [String: String], bodyLower: String) -> Bool {
        if parseBool(headers["x-subscription-disabled"]) == true { return true }
        return bodyLower.contains("subscription disabled") || bodyLower.contains("\"disabled\":true")
    }
    private static func panelBlocked(_ headers: [String: String], bodyLower: String) -> Bool {
        if parseBool(headers["x-subscription-blocked"]) == true { return true }
        if (headers["x-remnawave-response-type"] ?? "").uppercased() == "BLOCK" { return true }
        return bodyLower.contains("\"responseType\":\"block\"") || bodyLower.contains("\"responsetype\":\"block\"")
    }
    private static func looksLikeBrowserHTML(_ trimmed: String) -> Bool {
        let lower = trimmed.lowercased()
        return lower.hasPrefix("<!doctype") || lower.hasPrefix("<html") || lower.hasPrefix("<head")
    }
}
