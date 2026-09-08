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
    case importFile
    case importConfigText
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
    private static let knownCountryCodes: Set<String> = VPNCountryCatalog.isoCodes

    /// Two-letter tokens that look like ISO codes but are often hoster brands in VPN names.
    /// Example: `TW Germany` / `TW-France` → TimeWeb, not Taiwan.
    private static let ambiguousHosterCodes: Set<String> = [
        "TW", // TimeWeb
    ]

    public static func parse(tag: String, groupTag: String = "proxy", ping: Int = 0, load: Int = 0) -> VPNServer {
        var working = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        // Flag emoji anywhere in the name (Happ puts it first; some panels append it).
        let emojiCode = flagEmojiCountryCode(in: working)
        working = stripAllFlagEmoji(working)

        working = working
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "|", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = working
            .components(separatedBy: CharacterSet.whitespaces)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var countryCode = emojiCode ?? ""
        var remaining = parts
        if countryCode.isEmpty, let first = parts.first, first.count == 2 {
            let candidate = first.uppercased()
            if knownCountryCodes.contains(candidate), !ambiguousHosterCodes.contains(candidate) {
                countryCode = candidate
                remaining = Array(parts.dropFirst())
            } else if ambiguousHosterCodes.contains(candidate) {
                // Drop hoster prefix; resolve country from the rest (`TW Germany` → Germany).
                remaining = Array(parts.dropFirst())
            }
        }

        if countryCode.isEmpty {
            for part in parts where part.count == 2 {
                let candidate = part.uppercased()
                if knownCountryCodes.contains(candidate), !ambiguousHosterCodes.contains(candidate) {
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
            } else if last.count <= 3, knownCountryCodes.contains(last.uppercased()) || last.allSatisfy(\.isNumber) {
                // "Germany 2" / "France DE" → keep country token out of the city when possible.
                city = head
                country = countryName(for: countryCode) ?? head
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
            countryCode = inferCountryCode(from: country)
                ?? inferCountryCode(from: city)
                ?? inferCountryCode(from: remaining.joined(separator: " "))
                ?? inferCountryCode(from: working)
                ?? inferCountryCode(from: tag)
                ?? "XX"
        }

        let normalized = normalizeCountryCode(countryCode, country: country, city: city, tag: "\(working) \(tag)")

        return VPNServer(
            id: tag,
            city: city.isEmpty ? (countryName(for: normalized) ?? city) : city,
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
        // Named country in the label always wins over an ambiguous hoster code (TW ≠ Taiwan here).
        if let inferred = inferCountryCode(from: haystack) {
            let inferredNorm = inferred == "UK" ? "GB" : inferred
            if ambiguousHosterCodes.contains(code), inferredNorm != code {
                return inferredNorm
            }
            // Also prefer an explicit country name over a conflicting ISO token already chosen.
            if knownCountryCodes.contains(code), inferredNorm != code,
               haystackContainsNamedCountry(haystack, code: inferredNorm)
            {
                return inferredNorm
            }
        }
        if knownCountryCodes.contains(code) { return code }
        if let inferred = inferCountryCode(from: haystack) {
            return inferred == "UK" ? "GB" : inferred
        }
        return code.isEmpty ? "XX" : code
    }

    /// True when `haystack` contains a clear country/city alias for `code` (not just the ISO letters).
    private static func haystackContainsNamedCountry(_ haystack: String, code: String) -> Bool {
        guard let name = countryName(for: code)?.lowercased() else { return false }
        if haystack.contains(name) { return true }
        // English stems commonly used in Remnawave / Happ tags.
        let stems: [String: [String]] = [
            "DE": ["germany", "german", "герман", "berlin", "frankfurt"],
            "FR": ["france", "french", "франц", "paris", "париж"],
            "NL": ["netherlands", "holland", "нидерл", "голланд", "amsterdam"],
            "US": ["usa", "united states", "america", "сша"],
            "SE": ["sweden", "swedish", "швец", "stockholm"],
            "IT": ["italy", "italian", "итал", "milan", "rome"],
            "CH": ["switzerland", "swiss", "швейцар", "zurich"],
            "PL": ["poland", "polish", "польш", "warsaw"],
            "LV": ["latvia", "латви", "riga"],
        ]
        return stems[code.uppercased()]?.contains(where: { haystack.contains($0) }) == true
    }

    public static func servers(fromJSON json: String) -> [VPNServer] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        let outbounds = (root["outbounds"] as? [[String: Any]]) ?? []
        let endpoints = (root["endpoints"] as? [[String: Any]]) ?? []
        guard !outbounds.isEmpty || !endpoints.isEmpty else { return [] }

        var objectByTag: [String: [String: Any]] = [:]
        for outbound in outbounds {
            guard let tag = outbound["tag"] as? String, !tag.isEmpty else { continue }
            objectByTag[tag] = outbound
        }
        for endpoint in endpoints {
            guard let tag = endpoint["tag"] as? String, !tag.isEmpty else { continue }
            objectByTag[tag] = endpoint
        }

        let rootSelector = outbounds.first(where: { ($0["tag"] as? String) == "proxy" && ($0["type"] as? String) == "selector" })
            ?? outbounds.first(where: { ($0["type"] as? String) == "selector" })
        let groupTag = (rootSelector?["tag"] as? String) ?? "proxy"
        let rootMembers = (rootSelector?["outbounds"] as? [String]) ?? []
        let preferredRoots = rootMembers.filter { $0.lowercased() != "auto" }

        // Happ / TheTochka / Remnawave cascading UX:
        // proxy → [auto, Germany, France, …] where each country is selector|urltest.
        // Show ONE row per location group — never explode nested leaves into the picker.
        var locationGroups: [VPNServer] = []
        var flatLeaves: [VPNServer] = []
        for tag in preferredRoots {
            guard let object = objectByTag[tag] else { continue }
            let type = (object["type"] as? String)?.lowercased() ?? ""
            if type == "selector" || type == "urltest" {
                locationGroups.append(enrichLocationServer(parse(tag: tag, groupTag: groupTag), objectByTag: objectByTag))
            } else if !["direct", "block", "dns"].contains(type) {
                flatLeaves.append(parse(tag: tag, groupTag: groupTag))
            }
        }
        if !locationGroups.isEmpty {
            return locationGroups
        }
        if !flatLeaves.isEmpty {
            return flatLeaves
        }

        // Flat configs with no root selector members: every non-group outbound/endpoint.
        return objectByTag.keys.sorted().compactMap { tag in
            guard let object = objectByTag[tag] else { return nil }
            let type = (object["type"] as? String)?.lowercased() ?? ""
            if ["selector", "urltest", "direct", "block", "dns"].contains(type) { return nil }
            return parse(tag: tag, groupTag: groupTag)
        }
    }

    /// When the location tag is synthetic (`profile-1`) but the first leaf is `Germany`,
    /// promote the leaf name for flags/labels while keeping the location tag as `id` (Core select).
    private static func enrichLocationServer(_ server: VPNServer, objectByTag: [String: [String: Any]]) -> VPNServer {
        if !isOpaqueLocationTag(server.id), server.countryCode != "XX" {
            return server
        }
        guard let object = objectByTag[server.id],
              let children = object["outbounds"] as? [String]
        else { return server }

        var bestCode = server.countryCode
        var bestCity = server.city
        var bestCountry = server.country
        for child in children {
            let parsed = parse(tag: child, groupTag: server.groupTag)
            if parsed.countryCode != "XX" {
                bestCode = parsed.countryCode
                bestCountry = parsed.country
                if isOpaqueLocationTag(server.id) || server.city == server.id {
                    bestCity = parsed.city
                }
                break
            }
            if isOpaqueLocationTag(server.id), bestCity == server.id || bestCity.hasPrefix("profile") {
                bestCity = parsed.city
                bestCountry = parsed.country
            }
        }
        // Also try inferring from all child names joined (helps when leaf tags are proxy/proxy-2).
        if bestCode == "XX" {
            let joined = ([server.id] + children).joined(separator: " ")
            if let code = inferCountryCode(from: joined) {
                bestCode = code
                bestCountry = countryName(for: code) ?? bestCountry
            }
        }
        return VPNServer(
            id: server.id,
            city: bestCity,
            country: countryName(for: bestCode) ?? bestCountry,
            countryCode: bestCode,
            ping: server.ping,
            load: server.load,
            groupTag: server.groupTag
        )
    }

    private static func stripLeadingFlagEmoji(_ text: String) -> String {
        stripAllFlagEmoji(text)
    }

    /// ISO region from the first flag emoji (regional-indicator pair) in `text`.
    private static func flagEmojiCountryCode(in text: String) -> String? {
        let scalars = Array(text.unicodeScalars)
        var index = 0
        while index + 1 < scalars.count {
            let a = scalars[index].value
            let b = scalars[index + 1].value
            if (0x1F1E6 ... 0x1F1FF).contains(a), (0x1F1E6 ... 0x1F1FF).contains(b) {
                let c0 = Character(UnicodeScalar(UInt32(65 + (a - 0x1F1E6)))!)
                let c1 = Character(UnicodeScalar(UInt32(65 + (b - 0x1F1E6)))!)
                return String([c0, c1])
            }
            index += 1
        }
        return nil
    }

    private static func stripAllFlagEmoji(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var out: [UnicodeScalar] = []
        var index = 0
        while index < scalars.count {
            if index + 1 < scalars.count {
                let a = scalars[index].value
                let b = scalars[index + 1].value
                if (0x1F1E6 ... 0x1F1FF).contains(a), (0x1F1E6 ... 0x1F1FF).contains(b) {
                    index += 2
                    continue
                }
            }
            out.append(scalars[index])
            index += 1
        }
        return String(String.UnicodeScalarView(out))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func countryName(for code: String) -> String? {
        VPNCountryCatalog.displayName(for: code)
    }

    private static func inferCountryCode(from name: String) -> String? {
        let lower = VPNCountryCatalog.normalize(name)
        if let exact = VPNCountryCatalog.exactCode(for: lower) {
            // Whole-string "tw" alone can still mean Taiwan; "tw germany" is handled below.
            return exact == "UK" ? "GB" : exact
        }
        let tokens = lower
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { VPNCountryCatalog.normalize($0) }
            .filter { !$0.isEmpty }

        // Prefer multi-word country names before short ISO tokens (`tw germany` → Germany).
        if tokens.count >= 2 {
            for window in 2 ... min(4, tokens.count) {
                for start in 0 ... (tokens.count - window) {
                    let phrase = tokens[start ..< (start + window)].joined(separator: " ")
                    if let exact = VPNCountryCatalog.exactCode(for: phrase) {
                        return exact == "UK" ? "GB" : exact
                    }
                }
            }
        }

        // Named country tokens first; skip ambiguous hoster codes like TimeWeb `tw`.
        for token in tokens {
            if token.count == 2, ambiguousHosterCodes.contains(token.uppercased()) {
                continue
            }
            if let exact = VPNCountryCatalog.exactCode(for: token) {
                return exact == "UK" ? "GB" : exact
            }
        }

        if let code = VPNCountryCatalog.containsCode(in: lower) {
            // contains("tw") must not beat germany/france in the same string.
            if ambiguousHosterCodes.contains(code),
               tokens.contains(where: {
                   guard $0.count > 2 else { return false }
                   return VPNCountryCatalog.exactCode(for: $0) != nil
               })
            {
                // fall through — named token already checked above
            } else {
                return code == "UK" ? "GB" : code
            }
        }

        // Lone ambiguous hoster token with no other country signal → allow ISO (TW → Taiwan).
        if tokens.count == 1, let only = tokens.first?.uppercased(),
           ambiguousHosterCodes.contains(only),
           let exact = VPNCountryCatalog.exactCode(for: only.lowercased())
        {
            return exact
        }
        return nil
    }

    /// Synthetic graph tags that must not be shown as country rows.
    private static func isOpaqueLocationTag(_ tag: String) -> Bool {
        let t = tag.lowercased()
        if t.hasPrefix("profile-") || t.hasPrefix("share-") || t.hasPrefix("loc-") {
            return true
        }
        if t == "proxy" || t.hasPrefix("proxy-") { return true }
        return false
    }
}

#endif
