import Foundation
import Library

#if os(iOS)

public enum AppTab: Int, CaseIterable {
    case home = 1
    case subscriptions
    case profile

    public var title: String {
        switch self {
        case .home: "Главная"
        case .subscriptions: "Подписки"
        case .profile: "Профиль"
        }
    }
}

public enum ConnectionPhase: Equatable {
    case idle, connecting, disconnecting, switching
}

public enum DetailPage: Equatable {
    case subscription(Int64)
    case security
    case connection
    case diagnostics
    case activity
    case systemSettings
    case systemWarning
    case about
    case serviceLog
    case newConfiguration
    case applicationSettings
    case coreSettings
    case tunnelSettings
    case onDemandSettings
    case accessChoice
    case freeAccess
    case premiumPlans
    case payment
    case addOns
}

public enum AccessSource: Equatable {
    case free
    case premium
    case imported(Int64)
}

public enum PaymentMethod: String, CaseIterable {
    case apple = "Покупка через Apple"
    case external = "Другие способы"
}

public enum DirectBuiltinProfile {
    public static let freeURL = "vpndirect://builtin/free"
    public static let premiumURL = "vpndirect://builtin/premium"
    public static let freeName = "VPN Direct Free"
    public static let premiumName = "VPN Direct Premium"

    public static func kind(for remoteURL: String?) -> AccessSource? {
        switch remoteURL {
        case freeURL: return .free
        case premiumURL: return .premium
        default: return nil
        }
    }

    public static func isBuiltin(_ remoteURL: String?) -> Bool {
        kind(for: remoteURL) != nil
    }
}

public enum AppSheet: String, Identifiable {
    case serverPicker
    case connectionReport
    case profiles
    case recovery

    public var id: String { rawValue }
}

public struct VPNServer: Identifiable, Hashable {
    public let id: String
    public let city: String
    public let country: String
    public let countryCode: String
    public let ping: Int
    public let load: Int
    public let groupTag: String

    public init(
        id: String,
        city: String,
        country: String,
        countryCode: String,
        ping: Int = 0,
        load: Int = 0,
        groupTag: String = "proxy"
    ) {
        self.id = id
        self.city = city
        self.country = country
        self.countryCode = countryCode
        self.ping = ping
        self.load = load
        self.groupTag = groupTag
    }

    public var pingLabel: String {
        ping > 0 ? "\(ping) MS" : "— MS"
    }

    /// Single location line — never "Швеция, Швеция" / "USA / США".
    public var locationLabel: String {
        let cityName = Self.normalizeLocationToken(city)
        let countryName = Self.normalizeLocationToken(country)
        let raw: String
        if cityName.isEmpty {
            raw = countryName.isEmpty ? "—" : countryName
        } else if countryName.isEmpty || cityName.caseInsensitiveCompare(countryName) == .orderedSame {
            raw = cityName
        } else if Self.looksLikeCountryAlias(cityName, countryName) {
            raw = preferredLocaleName(city: cityName, country: countryName)
        } else {
            raw = "\(cityName), \(countryName)"
        }
        return Self.collapseDuplicatedCommaPair(raw)
    }

    private static func normalizeLocationToken(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func collapseDuplicatedCommaPair(_ value: String) -> String {
        let parts = value
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { normalizeLocationToken(String($0)) }
            .filter { !$0.isEmpty }
        guard parts.count == 2, parts[0].caseInsensitiveCompare(parts[1]) == .orderedSame else {
            return value
        }
        return parts[0]
    }

    private static func looksLikeCountryAlias(_ a: String, _ b: String) -> Bool {
        // Short labels without separators are usually country-level, not "City, Country".
        !a.contains(",") && !b.contains(",") && a.count <= 16 && b.count <= 16
    }

    private func preferredLocaleName(city: String, country: String) -> String {
        // Prefer Cyrillic when present (app UI is Russian).
        let cityCyrillic = city.unicodeScalars.contains { (0x0400 ... 0x04FF).contains($0.value) }
        let countryCyrillic = country.unicodeScalars.contains { (0x0400 ... 0x04FF).contains($0.value) }
        if countryCyrillic, !cityCyrillic { return country }
        if cityCyrillic, !countryCyrillic { return city }
        return city
    }
}

public struct VPNSubscriptionItem: Identifiable, Hashable {
    public let id: Int64
    public let name: String
    public let source: String
    public let updated: String
    public let expiry: String
    public let devices: String
    public let servers: [VPNServer]
    public let profile: ProfilePreview

    public init(
        profile: ProfilePreview,
        servers: [VPNServer],
        source: String,
        updated: String,
        expiry: String = "—",
        devices: String = "—",
        displayName: String? = nil
    ) {
        id = profile.id
        name = displayName ?? profile.name
        self.source = source
        self.updated = updated
        self.expiry = expiry
        self.devices = devices
        self.servers = servers
        self.profile = profile
    }
}

public enum VPNServerNameParser {
    private static let knownCountryCodes: Set<String> = [
        "DE", "NL", "FI", "SE", "US", "GB", "UK", "FR", "TR", "PL", "LV", "LT", "EE", "CZ",
        "AT", "CH", "IT", "ES", "CA", "JP", "SG", "HK", "AE", "RU", "KZ", "UA", "AM", "GE",
        "AZ", "RO", "IL", "TW", "NO", "DK", "BE", "PT", "IE", "BG", "HR", "SK", "HU", "GR",
    ]

    public static func parse(tag: String, groupTag: String = "proxy", ping: Int = 0, load: Int = 0) -> VPNServer {
        var working = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip leading flag emoji if present in tag — we never display emoji.
        working = stripLeadingFlagEmoji(working)

        working = working
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "|", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = working
            .components(separatedBy: CharacterSet.whitespaces)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var countryCode = ""
        var remaining = parts
        if let first = parts.first, first.count == 2 {
            let candidate = first.uppercased()
            if knownCountryCodes.contains(candidate) {
                countryCode = candidate
                remaining = Array(parts.dropFirst())
            }
        }

        if countryCode.isEmpty {
            for part in parts where part.count == 2 {
                let candidate = part.uppercased()
                if knownCountryCodes.contains(candidate) {
                    countryCode = candidate
                    remaining = parts.filter { $0.uppercased() != candidate }
                    break
                }
            }
        }

        let city: String
        let country: String
        if remaining.count >= 2 {
            let last = remaining.last!
            let head = remaining.dropLast().joined(separator: " ")
            if head.caseInsensitiveCompare(last) == .orderedSame {
                city = last
                country = countryName(for: countryCode) ?? last
            } else {
                city = head
                country = last
            }
        } else if remaining.count == 1 {
            city = remaining[0]
            country = countryName(for: countryCode) ?? remaining[0]
        } else {
            city = tag
            country = "Сервер"
        }

        if countryCode.isEmpty {
            countryCode = inferCountryCode(from: country) ?? inferCountryCode(from: city) ?? inferCountryCode(from: tag) ?? "XX"
        }

        let normalized = normalizeCountryCode(countryCode, country: country, city: city, tag: tag)

        return VPNServer(
            id: tag,
            city: city,
            country: countryName(for: normalized) ?? country,
            countryCode: normalized,
            ping: ping,
            load: load,
            groupTag: groupTag
        )
    }

    private static func normalizeCountryCode(_ code: String, country: String, city: String, tag: String) -> String {
        let haystack = "\(country) \(city) \(tag)".lowercased()
        if haystack.contains("usa") || haystack.contains("united states") || haystack.contains("сша") || haystack.contains("america") {
            return "US"
        }
        if code == "UK" { return "GB" }
        if knownCountryCodes.contains(code) { return code }
        if let inferred = inferCountryCode(from: haystack) {
            return inferred
        }
        return code.isEmpty ? "XX" : code
    }

    public static func servers(fromJSON json: String) -> [VPNServer] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let outbounds = root["outbounds"] as? [[String: Any]]
        else { return [] }

        if let selector = outbounds.first(where: { ($0["type"] as? String) == "selector" }) {
            let groupTag = (selector["tag"] as? String) ?? "proxy"
            let tags = (selector["outbounds"] as? [String]) ?? []
            let typeByTag: [String: String] = Dictionary(uniqueKeysWithValues: outbounds.compactMap { outbound in
                guard let tag = outbound["tag"] as? String,
                      let type = outbound["type"] as? String
                else { return nil }
                return (tag, type.lowercased())
            })
            return tags
                .filter { tag in
                    let type = typeByTag[tag] ?? ""
                    return !["direct", "block", "dns", "selector", "urltest", "auto"].contains(tag.lowercased())
                        && !["direct", "block", "dns", "selector", "urltest"].contains(type)
                }
                .map { parse(tag: $0, groupTag: groupTag) }
        }

        return outbounds.compactMap { outbound in
            guard let tag = outbound["tag"] as? String,
                  let type = outbound["type"] as? String,
                  !["direct", "block", "dns", "selector", "urltest"].contains(type)
            else { return nil }
            return parse(tag: tag)
        }
    }

    private static func stripLeadingFlagEmoji(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        guard scalars.count >= 2 else { return text }
        let a = scalars[0].value
        let b = scalars[1].value
        if (0x1F1E6 ... 0x1F1FF).contains(a), (0x1F1E6 ... 0x1F1FF).contains(b) {
            return String(String.UnicodeScalarView(scalars.dropFirst(2)))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private static func countryName(for code: String) -> String? {
        switch code.uppercased() {
        case "DE": return "Германия"
        case "NL": return "Нидерланды"
        case "FI": return "Финляндия"
        case "SE": return "Швеция"
        case "US": return "США"
        case "GB", "UK": return "Великобритания"
        case "FR": return "Франция"
        case "TR": return "Турция"
        case "PL": return "Польша"
        case "LV": return "Латвия"
        case "LT": return "Литва"
        case "EE": return "Эстония"
        case "CZ": return "Чехия"
        case "AT": return "Австрия"
        case "CH": return "Швейцария"
        case "IT": return "Италия"
        case "ES": return "Испания"
        case "CA": return "Канада"
        case "JP": return "Япония"
        case "SG": return "Сингапур"
        case "HK": return "Гонконг"
        case "AE": return "ОАЭ"
        case "RU": return "Россия"
        case "KZ": return "Казахстан"
        case "UA": return "Украина"
        case "AM": return "Армения"
        case "GE": return "Грузия"
        case "AZ": return "Азербайджан"
        case "RO": return "Румыния"
        case "IL": return "Израиль"
        default: return nil
        }
    }

    private static func inferCountryCode(from name: String) -> String? {
        let lower = name.lowercased()
        let map: [(String, String)] = [
            ("герман", "DE"), ("frankfur", "DE"), ("berlin", "DE"),
            ("нидерл", "NL"), ("amster", "NL"),
            ("финлянд", "FI"), ("helsink", "FI"),
            ("швец", "SE"), ("stockhol", "SE"),
            ("сша", "US"), ("new york", "US"), ("america", "US"), ("usa", "US"), ("united states", "US"),
            ("britain", "GB"), ("london", "GB"), ("великобритан", "GB"), ("england", "GB"),
            ("франц", "FR"), ("paris", "FR"), ("france", "FR"),
            ("турц", "TR"), ("istanbul", "TR"), ("стамбул", "TR"), ("turkey", "TR"),
            ("польш", "PL"), ("warsaw", "PL"), ("варшав", "PL"), ("poland", "PL"),
            ("латви", "LV"), ("riga", "LV"), ("рига", "LV"), ("latvia", "LV"),
            ("литв", "LT"), ("vilnius", "LT"), ("lithuania", "LT"),
            ("эстон", "EE"), ("tallinn", "EE"), ("estonia", "EE"),
            ("нидерл", "NL"), ("amster", "NL"), ("netherlands", "NL"), ("holland", "NL"),
            ("швец", "SE"), ("stockhol", "SE"), ("sweden", "SE"),
            ("финлянд", "FI"), ("helsink", "FI"), ("finland", "FI"),
            ("герман", "DE"), ("frankfur", "DE"), ("berlin", "DE"), ("germany", "DE"),
            ("япон", "JP"), ("tokyo", "JP"), ("токио", "JP"),
            ("сингапур", "SG"),
            ("гонконг", "HK"),
            ("росси", "RU"), ("moscow", "RU"),
            ("казах", "KZ"), ("алматы", "KZ"),
            ("украин", "UA"),
            ("армен", "AM"),
            ("грузи", "GE"), ("тбилис", "GE"),
            ("азербайдж", "AZ"), ("баку", "AZ"),
            ("румын", "RO"), ("бухарест", "RO"),
            ("израил", "IL"), ("тель", "IL"),
            ("оаэ", "AE"), ("дубай", "AE"),
            ("австр", "AT"), ("вена", "AT"),
            ("швейцар", "CH"), ("цюрих", "CH"),
            ("чехи", "CZ"), ("праг", "CZ"),
            ("испан", "ES"), ("мадрид", "ES"),
            ("итал", "IT"), ("милан", "IT"),
            ("канад", "CA"), ("торонто", "CA"),
        ]
        for (key, code) in map where lower.contains(key) {
            return code
        }
        return nil
    }
}

#endif
