import Foundation

/// Happ / Remnawave / XTLS subscription HTTP metadata.
public struct SubscriptionMetadata: Codable, Equatable {
    public var title: String?
    public var expireTimestamp: Int64?
    public var uploadBytes: Int64?
    public var downloadBytes: Int64?
    public var totalBytes: Int64?
    public var deviceLimit: Int?
    public var deviceUsed: Int?
    public var hwidLimitEnabled: Bool?
    public var unlimitedDevices: Bool = false

    public init(
        title: String? = nil,
        expireTimestamp: Int64? = nil,
        uploadBytes: Int64? = nil,
        downloadBytes: Int64? = nil,
        totalBytes: Int64? = nil,
        deviceLimit: Int? = nil,
        deviceUsed: Int? = nil,
        hwidLimitEnabled: Bool? = nil,
        unlimitedDevices: Bool = false
    ) {
        self.title = title
        self.expireTimestamp = expireTimestamp
        self.uploadBytes = uploadBytes
        self.downloadBytes = downloadBytes
        self.totalBytes = totalBytes
        self.deviceLimit = deviceLimit
        self.deviceUsed = deviceUsed
        self.hwidLimitEnabled = hwidLimitEnabled
        self.unlimitedDevices = unlimitedDevices
    }

    public var expiryLabel: String {
        guard let raw = expireTimestamp, raw > 0 else { return "—" }
        let seconds = raw > 9_999_999_999 ? raw / 1000 : raw
        let date = Date(timeIntervalSince1970: TimeInterval(seconds))
        if date < Date() {
            return "Истекла"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    public var trafficUsedBytes: Int64 {
        (uploadBytes ?? 0) &+ (downloadBytes ?? 0)
    }

    /// Primary metric value for home «Доступный трафик» (e.g. `1,7` or `1,7 ГБ`).
    public var trafficQuotaLabel: String {
        if let total = trafficQuotaTotalBytes {
            // Same unit as quota: "1,7" + unit "из 5 ГБ"
            return Self.formatTrafficAmount(trafficUsedBytes, aligningWith: total)
        }
        // Unlimited: keep unit on the value → "1,7 ГБ" + "из ∞"
        return Self.formatTraffic(trafficUsedBytes)
    }

    /// Secondary metric unit: `из 5 ГБ` or `из ∞`.
    public var trafficQuotaUnit: String {
        if let total = trafficQuotaTotalBytes {
            return "из \(Self.formatTraffic(total))"
        }
        return "из ∞"
    }

    /// Full line for lists / details: `1,7 из 5 ГБ` / `1,7 ГБ из ∞`.
    public var trafficQuotaFullLabel: String {
        "\(trafficQuotaLabel) \(trafficQuotaUnit)"
    }

    /// `nil` means unlimited (`total` missing or ≤ 0 — Remnawave convention).
    private var trafficQuotaTotalBytes: Int64? {
        guard let total = totalBytes, total > 0 else { return nil }
        return total
    }

    public var shortExpiryLabel: String {
        guard let raw = expireTimestamp, raw > 0 else { return "—" }
        let seconds = raw > 9_999_999_999 ? raw / 1000 : raw
        let date = Date(timeIntervalSince1970: TimeInterval(seconds))
        if date < Date() { return "Истекла" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("d MMM yy")
        return formatter.string(from: date)
    }

    public var devicesLabel: String {
        if unlimitedDevices || Self.isUnlimitedDeviceLimit(deviceLimit) {
            if let deviceUsed, deviceUsed > 0 {
                return "\(deviceUsed)/∞"
            }
            return "∞"
        }

        if hwidLimitEnabled == false {
            return "∞"
        }

        if let deviceUsed, let deviceLimit, deviceLimit > 0 {
            return "\(deviceUsed)/\(deviceLimit)"
        }
        if let deviceLimit, deviceLimit > 0 {
            return "до \(deviceLimit)"
        }
        if let deviceUsed, deviceUsed > 0 {
            return "\(deviceUsed)"
        }

        if hwidLimitEnabled == true {
            return "активен"
        }

        return "∞"
    }

    /// Decodes Happ `base64:…` profile titles and trims empty values.
    public static func sanitizedTitle(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return decodeHeaderValue(trimmed)
    }

    /// True when a stored profile name is still an undecoded `base64:…` title.
    public static func isEncodedProfileTitle(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("base64:")
    }

    public static func parse(headers: [String: String], body: String = "") -> SubscriptionMetadata {
        let normalized = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })
        var meta = SubscriptionMetadata()

        if let rawTitle = normalized["profile-title"]
            ?? normalized["profile-update-title"]
            ?? normalized["subscription-name"]
        {
            meta.title = decodeHeaderValue(rawTitle)
        }

        if let userInfo = normalized["subscription-userinfo"] {
            mergeUserInfo(userInfo, into: &meta)
        }

        applyDeviceHeaders(normalized, into: &meta)

        if meta.title == nil, let disposition = normalized["content-disposition"],
           let filename = filenameFromContentDisposition(disposition)
        {
            meta.title = filename
        }

        if meta.title == nil {
            meta.title = parseBodyParameter(named: "profile-title", in: body)
                ?? parseBodyParameter(named: "subscription-name", in: body)
        }

        if meta.expireTimestamp == nil || meta.deviceLimit == nil {
            if let userInfo = parseBodyParameter(named: "subscription-userinfo", in: body) {
                mergeUserInfo(userInfo, into: &meta)
            }
        }

        finalizeDeviceState(&meta)
        return meta
    }

    public static func fetch(from url: String) async throws -> SubscriptionMetadata {
        var lastMeta = SubscriptionMetadata()
        for agent in SubscriptionHTTP.userAgents {
            do {
                let response = try await SubscriptionHTTP.fetch(url: url, userAgent: agent)
                let meta = parse(headers: response.headers, body: response.body)
                if meta.title != nil || meta.expireTimestamp != nil || meta.deviceLimit != nil || meta.hwidLimitEnabled != nil {
                    return meta
                }
                lastMeta = meta
            } catch {
                continue
            }
        }
        return lastMeta
    }

    private static func applyDeviceHeaders(_ normalized: [String: String], into meta: inout SubscriptionMetadata) {
        if let active = normalized["x-hwid-active"] {
            meta.hwidLimitEnabled = parseBool(active)
        }

        for key in ["x-hwid-device-limit", "x-device-limit", "x-devices-limit", "device-limit", "devices-limit", "hwid-device-limit"] {
            if let value = normalized[key] {
                applyDeviceLimitValue(value, into: &meta)
            }
        }

        for key in ["x-hwid-device-used", "x-device-used", "x-devices-used", "device-used", "devices-used", "hwid-device-used"] {
            if let value = normalized[key], let used = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                meta.deviceUsed = used
            }
        }

        if parseBool(normalized["x-hwid-max-devices-reached"] ?? "") == true ||
            parseBool(normalized["x-hwid-limit"] ?? "") == true
        {
            meta.hwidLimitEnabled = true
        }
    }

    private static func mergeUserInfo(_ header: String, into meta: inout SubscriptionMetadata) {
        for part in header.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard pair.count == 2 else { continue }
            let key = pair[0].lowercased()
            let value = pair[1]
            switch key {
            case "expire", "expired", "expiry":
                meta.expireTimestamp = parseTimestamp(value)
            case "upload":
                meta.uploadBytes = Int64(value)
            case "download":
                meta.downloadBytes = Int64(value)
            case "total":
                meta.totalBytes = Int64(value)
            case "device_limit", "devicelimit", "hwid_limit", "hwid-limit", "hwid_device_limit",
                 "hwiddevicelimit", "max_devices", "maxdevices", "devices_limit", "deviceslimit",
                 "limitip", "limit_ip", "limit-ip":
                applyDeviceLimitValue(value, into: &meta)
            case "device_used", "deviceused", "hwid_used", "hwid-used", "hwid_used_devices",
                 "devices_used", "devicesused", "active_devices", "activedevices", "devices", "hwid_count":
                if let used = Int(value) {
                    meta.deviceUsed = used
                } else if value.lowercased() == "unlimited" || value == "∞" {
                    meta.unlimitedDevices = true
                    meta.deviceLimit = nil
                }
            case "profile-title", "title":
                if meta.title == nil {
                    meta.title = decodeHeaderValue(value)
                }
            default:
                if key.contains("device") && key.contains("limit") {
                    applyDeviceLimitValue(value, into: &meta)
                } else if key.contains("device") && (key.contains("used") || key.contains("active") || key.contains("count")) {
                    if let used = Int(value) {
                        meta.deviceUsed = used
                    }
                }
            }
        }
    }

    private static func applyDeviceLimitValue(_ raw: String, into meta: inout SubscriptionMetadata) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.isEmpty || value == "unlimited" || value == "∞" || value == "inf" || value == "infinity" {
            meta.unlimitedDevices = true
            meta.deviceLimit = nil
            return
        }
        if let limit = Int(value) {
            if isUnlimitedDeviceLimit(limit) {
                meta.unlimitedDevices = true
                meta.deviceLimit = nil
            } else {
                meta.deviceLimit = limit
                meta.unlimitedDevices = false
            }
        }
    }

    private static func finalizeDeviceState(_ meta: inout SubscriptionMetadata) {
        if isUnlimitedDeviceLimit(meta.deviceLimit) {
            meta.unlimitedDevices = true
            meta.deviceLimit = nil
        }

        // Remnawave: HWID limit disabled for user → unlimited devices.
        if meta.hwidLimitEnabled == false {
            meta.unlimitedDevices = true
            meta.deviceLimit = nil
        }

        // No HWID tracking headers and no numeric limit → treat as unlimited (Happ behaviour for open subs).
        if meta.hwidLimitEnabled == nil, meta.deviceLimit == nil, !meta.unlimitedDevices {
            meta.unlimitedDevices = true
        }
    }

    private static func isUnlimitedDeviceLimit(_ limit: Int?) -> Bool {
        guard let limit else { return false }
        return limit <= 0
    }

    private static func formatTraffic(_ bytes: Int64) -> String {
        let amount = formatTrafficAmount(bytes, aligningWith: bytes)
        let unit = trafficUnitLabel(for: bytes)
        return "\(amount) \(unit)"
    }

    /// Numeric part only, optionally scaled to the same unit as `aligningWith` (quota total).
    private static func formatTrafficAmount(_ bytes: Int64, aligningWith reference: Int64?) -> String {
        let scaleBytes = max(reference ?? bytes, bytes)
        let value = Double(max(0, bytes))
        let divisor: Double
        if scaleBytes >= 1024 * 1024 * 1024 {
            divisor = 1024 * 1024 * 1024
        } else if scaleBytes >= 1024 * 1024 {
            divisor = 1024 * 1024
        } else {
            divisor = 1024
        }
        let amount = value / divisor
        if abs(amount - amount.rounded()) < 0.05 {
            return String(format: "%.0f", amount.rounded())
        }
        return String(format: "%.1f", amount).replacingOccurrences(of: ".", with: ",")
    }

    private static func trafficUnitLabel(for bytes: Int64) -> String {
        if bytes >= 1024 * 1024 * 1024 { return "ГБ" }
        if bytes >= 1024 * 1024 { return "МБ" }
        return "КБ"
    }

    private static func parseTimestamp(_ raw: String) -> Int64? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int64(trimmed), value > 0 else { return nil }
        return value
    }

    private static func parseBool(_ raw: String) -> Bool {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on": return true
        default: return false
        }
    }

    private static func decodeHeaderValue(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("base64:") {
            let encoded = String(trimmed.dropFirst("base64:".count))
            if let data = Data(base64Encoded: encoded.padding(toLength: ((encoded.count + 3) / 4) * 4, withPad: "=", startingAt: 0)),
               let decoded = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !decoded.isEmpty
            {
                return decoded
            }
        }
        if trimmed.range(of: #"^[A-Za-z0-9+/=_-]+$"#, options: .regularExpression) != nil,
           trimmed.count >= 8,
           let data = Data(base64Encoded: trimmed.padding(toLength: ((trimmed.count + 3) / 4) * 4, withPad: "=", startingAt: 0)),
           let decoded = String(data: data, encoding: .utf8),
           decoded.range(of: #"[\x00-\x08\x0B\x0C\x0E-\x1F]"#, options: .regularExpression) == nil,
           !decoded.isEmpty
        {
            return decoded
        }
        return trimmed
    }

    private static func filenameFromContentDisposition(_ value: String) -> String? {
        for part in value.split(separator: ";") {
            let token = part.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = token.lowercased()
            if lower.hasPrefix("filename*=") {
                let raw = token.split(separator: "=", maxSplits: 1).last.map(String.init) ?? ""
                let encoded = raw.split(separator: "'", maxSplits: 2).last.map(String.init) ?? raw
                return decodeHeaderValue(encoded.removingPercentEncoding ?? encoded)
            }
            if lower.hasPrefix("filename=") {
                let raw = token.split(separator: "=", maxSplits: 1).last.map(String.init) ?? ""
                let unquoted = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                return decodeHeaderValue(unquoted)
            }
        }
        return nil
    }

    private static func parseBodyParameter(named key: String, in body: String) -> String? {
        let marker = "#\(key)"
        for line in body.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().hasPrefix(marker.lowercased()) {
                let value = trimmed.dropFirst(marker.count).trimmingCharacters(in: CharacterSet(charactersIn: "=:"))
                return decodeHeaderValue(String(value))
            }
            if let fragment = trimmed.split(separator: "#", maxSplits: 1).last,
               fragment.lowercased().hasPrefix("\(key.lowercased())=")
            {
                let value = fragment.split(separator: "=", maxSplits: 1).last.map(String.init) ?? ""
                return decodeHeaderValue(value.removingPercentEncoding ?? value)
            }
        }
        return nil
    }
}

public enum SubscriptionMetadataStore {
    private static func key(for profileID: Int64) -> String { "vpndirect.subscription.meta.\(profileID)" }

    public static func load(profileID: Int64) -> SubscriptionMetadata? {
        guard let data = UserDefaults.standard.data(forKey: key(for: profileID)),
              let meta = try? JSONDecoder().decode(SubscriptionMetadata.self, from: data)
        else { return nil }
        return meta
    }

    public static func save(_ meta: SubscriptionMetadata, profileID: Int64) {
        guard let data = try? JSONEncoder().encode(meta) else { return }
        UserDefaults.standard.set(data, forKey: key(for: profileID))
    }
}
