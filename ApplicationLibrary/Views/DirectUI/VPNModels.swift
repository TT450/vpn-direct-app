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
    /// Precomputed once at init — never re-run country catalog on every SwiftUI tick.
    public let locationLabel: String

    public init(
        id: String,
        city: String,
        country: String,
        countryCode: String,
        ping: Int = 0,
        load: Int = 0,
        groupTag: String = "proxy",
        locationLabel: String? = nil
    ) {
        self.id = id
        self.city = city
        self.country = country
        self.countryCode = countryCode
        self.ping = ping
        self.load = load
        self.groupTag = groupTag
        self.locationLabel = locationLabel ?? Self.makeLocationLabel(id: id, city: city, country: country)
    }

    public var pingLabel: String {
        ping > 0 ? "\(ping) MS" : "— MS"
    }

    /// Single location line — never "Швеция, Швеция" / "USA / США" / "Dubai, United Arab Emirates".
    private static func makeLocationLabel(id: String, city: String, country: String) -> String {
        let cityName = normalizeLocationToken(city)
        let countryName = normalizeLocationToken(country)
        if let emirate = VPNCountryCatalog.emirateEnglishName(in: "\(city) \(country) \(id)") {
            return emirate
        }
        if VPNCountryCatalog.isUnitedArabEmiratesLabel(cityName)
            || VPNCountryCatalog.isUnitedArabEmiratesLabel(countryName)
        {
            // Bare UAE profile without a specific emirate → short "UAE".
            return "UAE"
        }
        let raw: String
        if cityName.isEmpty {
            raw = countryName.isEmpty ? "—" : countryName
        } else if countryName.isEmpty || cityName.caseInsensitiveCompare(countryName) == .orderedSame {
            raw = cityName
        } else if looksLikeCountryAlias(cityName, countryName) {
            raw = preferredLocaleName(city: cityName, country: countryName)
        } else if VPNCountryCatalog.isUnitedArabEmiratesLabel(countryName) {
            raw = cityName
        } else {
            raw = "\(cityName), \(countryName)"
        }
        return collapseDuplicatedCommaPair(raw)
    }

    private static func normalizeLocationToken(_ value: String) -> String {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return VPNCountryCatalog.englishPlaceName(for: cleaned)
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
        // Only collapse true duplicates (USA / США), never "United" vs "United Kingdom".
        let na = VPNCountryCatalog.normalize(a)
        let nb = VPNCountryCatalog.normalize(b)
        if na.isEmpty || nb.isEmpty { return false }
        if na == nb { return true }
        let ca = VPNCountryCatalog.exactCode(for: na) ?? VPNCountryCatalog.containsCode(in: na)
        let cb = VPNCountryCatalog.exactCode(for: nb) ?? VPNCountryCatalog.containsCode(in: nb)
        guard let ca, let cb else { return false }
        return ca == cb
    }

    private static func preferredLocaleName(city: String, country: String) -> String {
        // Prefer English / Latin over Cyrillic duplicates (e.g. USA vs США).
        let cityCyrillic = city.unicodeScalars.contains { (0x0400 ... 0x04FF).contains($0.value) }
        let countryCyrillic = country.unicodeScalars.contains { (0x0400 ... 0x04FF).contains($0.value) }
        if cityCyrillic, !countryCyrillic { return country }
        if countryCyrillic, !cityCyrillic { return city }
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

    /// Tokens that must never become a country code (Wi-Fi → Fi → Finland, LTE, etc.).
    private static let nonCountryNoiseTokens: Set<String> = [
        "wi", "fi", "wifi", "lte", "5g", "4g", "3g", "tcp", "udp", "tls", "ws", "http", "https",
        "vpn", "vip", "os", "tv", "ip", "v2", "v3", "x2", "x3", "cdn", "bgp", "asn",
        "безлим", "лимит", "unlimited", "limit", "mobile", "mobiledata",
    ]

    public static func parse(tag: String, groupTag: String = "proxy", ping: Int = 0, load: Int = 0) -> VPNServer {
        var working = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        // Flag emoji anywhere in the name (Happ puts it first; some panels append it).
        let emojiCode = flagEmojiCountryCode(in: working)
        working = stripAllFlagEmoji(working)
        working = scrubNetworkNoise(working)

        working = working
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "|", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = working
            .components(separatedBy: CharacterSet.whitespaces)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { !nonCountryNoiseTokens.contains($0.lowercased()) }

        var countryCode = emojiCode ?? ""
        var remaining = parts
        if countryCode.isEmpty, let first = parts.first, first.count == 2 {
            let candidate = first.uppercased()
            if knownCountryCodes.contains(candidate),
               !ambiguousHosterCodes.contains(candidate),
               !nonCountryNoiseTokens.contains(candidate.lowercased())
            {
                countryCode = candidate
                remaining = Array(parts.dropFirst())
            } else if ambiguousHosterCodes.contains(candidate) {
                // Drop hoster prefix; resolve country from the rest (`TW Germany` → Germany).
                remaining = Array(parts.dropFirst())
            }
        }

        // Do NOT scan mid-name 2-letter ISO tokens: Remnawave tags lose flag emoji in sing-box
        // tags (`Польша-Безлим-Wi-Fi` → `Fi` ⇒ Finland). Prefer named countries via infer.

        var cityRaw: String
        var countryRaw: String
        // Smart phrase resolve before naive head/tail split ("United Kingdom", "Great Britain", bare "United").
        if let phrase = VPNCountryCatalog.resolveCountryPhrase(
            in: remaining.joined(separator: " "),
            preferCode: countryCode.isEmpty ? emojiCode : countryCode
        ) ?? VPNCountryCatalog.resolveCountryPhrase(in: working, preferCode: countryCode.isEmpty ? emojiCode : countryCode) {
            if countryCode.isEmpty { countryCode = phrase.code }
            countryRaw = phrase.englishName
            // Country-normalized label: never invent a capital — show the country name.
            let phraseNorm = VPNCountryCatalog.normalize(phrase.englishName)
            let remNorm = VPNCountryCatalog.normalize(remaining.joined(separator: " "))
            if remNorm == phraseNorm || remNorm.isEmpty {
                cityRaw = phrase.englishName
            } else {
                let countryTokens = Set(phraseNorm.split(separator: " ").map(String.init))
                let extras = remaining.filter { !countryTokens.contains(VPNCountryCatalog.normalize($0)) }
                // Extra tokens that are only an index ("2", "#3") stay on the country label.
                let meaningful = extras.filter { token in
                    let t = token.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                    return !(t.count <= 3 && t.allSatisfy(\.isNumber))
                }
                if meaningful.isEmpty {
                    cityRaw = phrase.englishName
                    if let idx = extras.last {
                        countryRaw = "\(phrase.englishName) \(idx)"
                    }
                } else {
                    cityRaw = meaningful.joined(separator: " ")
                }
            }
        } else if remaining.count >= 2 {
            let joined = remaining.joined(separator: " ")
            if let multiCode = VPNCountryCatalog.exactCode(for: VPNCountryCatalog.normalize(joined)) {
                let en = countryName(for: multiCode) ?? joined
                cityRaw = en
                countryRaw = en
                if countryCode.isEmpty { countryCode = multiCode }
            } else {
                let last = remaining.last!
                let head = remaining.dropLast().joined(separator: " ")
                if head.caseInsensitiveCompare(last) == .orderedSame {
                    cityRaw = last
                    countryRaw = countryName(for: countryCode) ?? last
                } else if last.count <= 3, last.allSatisfy(\.isNumber) {
                    cityRaw = head
                    countryRaw = countryName(for: countryCode) ?? head
                } else if last.count == 2,
                          knownCountryCodes.contains(last.uppercased()),
                          !nonCountryNoiseTokens.contains(last.lowercased()),
                          !ambiguousHosterCodes.contains(last.uppercased())
                {
                    cityRaw = head
                    countryRaw = countryName(for: countryCode) ?? head
                } else {
                    cityRaw = head
                    countryRaw = last
                }
            }
        } else if remaining.count == 1 {
            cityRaw = remaining[0]
            countryRaw = countryName(for: countryCode) ?? remaining[0]
        } else {
            cityRaw = tag
            countryRaw = "Server"
        }

        if countryCode.isEmpty {
            countryCode = inferNamedCountryStem(from: "\(countryRaw) \(cityRaw) \(working) \(tag)")
                ?? inferCountryCode(from: countryRaw)
                ?? inferCountryCode(from: cityRaw)
                ?? inferCountryCode(from: remaining.joined(separator: " "))
                ?? inferCountryCode(from: working)
                ?? inferCountryCode(from: tag)
                ?? "XX"
        }

        let normalized = normalizeCountryCode(countryCode, country: countryRaw, city: cityRaw, tag: "\(working) \(tag)")
        let placeHaystack = "\(cityRaw) \(countryRaw) \(working) \(tag)"
        if let emirate = VPNCountryCatalog.emirateEnglishName(in: placeHaystack) {
            return VPNServer(
                id: tag,
                city: emirate,
                country: emirate,
                countryCode: "AE",
                ping: ping,
                load: load,
                groupTag: groupTag
            )
        }
        let fallback = countryName(for: normalized)
        let city = VPNCountryCatalog.englishPlaceName(for: cityRaw.isEmpty ? (fallback ?? cityRaw) : cityRaw)
        let country = VPNCountryCatalog.englishPlaceName(for: fallback ?? countryRaw)
        // Prefer a single country label when city is just the country (or empty).
        let displayCity: String
        if city.isEmpty || city.caseInsensitiveCompare(country) == .orderedSame {
            displayCity = country
        } else if VPNCountryCatalog.exactCode(for: VPNCountryCatalog.normalize(city)) == normalized {
            displayCity = country
        } else {
            displayCity = city
        }

        return VPNServer(
            id: tag,
            city: displayCity,
            country: country,
            countryCode: normalized,
            ping: ping,
            load: load,
            groupTag: groupTag
        )
    }

    /// Strip Wi-Fi / LTE markers so they cannot be tokenized into ISO codes (`Fi` → Finland).
    private static func scrubNetworkNoise(_ text: String) -> String {
        var result = text
        let patterns = [
            "wi-fi", "wi fi", "wifi", "wi‑fi", // include unicode hyphen
        ]
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: " ", options: [.caseInsensitive])
        }
        return result
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeCountryCode(_ code: String, country: String, city: String, tag: String) -> String {
        let haystack = scrubNetworkNoise("\(country) \(city) \(tag)".lowercased())
        if code == "UK" { return "GB" }

        // TheTochka policy: Cyrillic/English country stems beat accidental ISO tokens
        // (`Польша-…-Wi-Fi` → Fi must not become Finland).
        if let named = inferNamedCountryStem(from: haystack) {
            return named
        }

        if let inferred = inferCountryCode(from: haystack) {
            let inferredNorm = inferred == "UK" ? "GB" : inferred
            if ambiguousHosterCodes.contains(code), inferredNorm != code {
                return inferredNorm
            }
            // Named / multi-char inference wins over a conflicting bare ISO code.
            if knownCountryCodes.contains(code), inferredNorm != code, inferredNorm.count == 2 {
                let scrubbedCode = nonCountryNoiseTokens.contains(code.lowercased())
                if scrubbedCode || haystackContainsNamedCountry(haystack, code: inferredNorm) {
                    return inferredNorm
                }
            }
            if !knownCountryCodes.contains(code) {
                return inferredNorm
            }
        }
        if knownCountryCodes.contains(code), !nonCountryNoiseTokens.contains(code.lowercased()) {
            return code == "UK" ? "GB" : code
        }
        if let inferred = inferCountryCode(from: haystack) {
            return inferred == "UK" ? "GB" : inferred
        }
        return code.isEmpty ? "XX" : code
    }

    /// TheTochka-style stem matcher: `польш`→PL, `сша`→US, `дубай`→AE. Never uses 2-letter ISO.
    private static func inferNamedCountryStem(from haystack: String) -> String? {
        let lower = scrubNetworkNoise(VPNCountryCatalog.normalize(haystack))
        let stems: [(String, String)] = [
            ("united states", "US"), ("сша", "US"), ("america", "US"), ("usa", "US"),
            ("united kingdom", "GB"), ("great britain", "GB"), ("britain", "GB"), ("england", "GB"), ("london", "GB"),
            ("great", "GB"), ("грит", "GB"), ("грейт", "GB"), ("юнайтед", "GB"),
            ("герман", "DE"), ("germany", "DE"), ("berlin", "DE"), ("frankfur", "DE"),
            ("нидерл", "NL"), ("голланд", "NL"), ("netherlands", "NL"), ("holland", "NL"), ("amster", "NL"),
            ("финлянд", "FI"), ("finland", "FI"), ("helsink", "FI"),
            ("швец", "SE"), ("sweden", "SE"), ("stockhol", "SE"),
            ("франц", "FR"), ("france", "FR"), ("paris", "FR"),
            ("турц", "TR"), ("turkey", "TR"), ("istanbul", "TR"), ("стамбул", "TR"),
            ("польш", "PL"), ("poland", "PL"), ("warsaw", "PL"), ("варшав", "PL"),
            ("латви", "LV"), ("latvia", "LV"), ("riga", "LV"), ("рига", "LV"),
            ("литв", "LT"), ("lithuania", "LT"), ("vilnius", "LT"),
            ("эстон", "EE"), ("estonia", "EE"), ("tallinn", "EE"),
            ("япон", "JP"), ("japan", "JP"), ("tokyo", "JP"), ("токио", "JP"),
            ("сингапур", "SG"), ("singapore", "SG"),
            ("гонконг", "HK"), ("hong kong", "HK"),
            ("росси", "RU"), ("russia", "RU"), ("moscow", "RU"),
            ("казах", "KZ"), ("алматы", "KZ"),
            ("украин", "UA"), ("ukraine", "UA"),
            ("армен", "AM"), ("armenia", "AM"),
            ("грузи", "GE"), ("georgia", "GE"), ("тбилис", "GE"),
            ("азербайдж", "AZ"), ("баку", "AZ"),
            ("румын", "RO"), ("romania", "RO"),
            ("израил", "IL"), ("israel", "IL"),
            ("оаэ", "AE"), ("дубай", "AE"), ("emirates", "AE"), ("uae", "AE"),
            ("австр", "AT"), ("austria", "AT"),
            ("швейцар", "CH"), ("switzerland", "CH"),
            ("чехи", "CZ"), ("czech", "CZ"),
            ("испан", "ES"), ("spain", "ES"),
            ("итал", "IT"), ("italy", "IT"),
            ("канад", "CA"), ("canada", "CA"),
            ("тайван", "TW"), ("taiwan", "TW"),
            ("норвег", "NO"), ("norway", "NO"),
            ("дания", "DK"), ("denmark", "DK"), ("copenhagen", "DK"), ("копенгаген", "DK"),
            ("албан", "AL"), ("albania", "AL"), ("tirana", "AL"), ("тирана", "AL"),
            ("бразил", "BR"), ("brazil", "BR"), ("brasil", "BR"),
            ("инди", "IN"), ("india", "IN"), ("delhi", "IN"),
            ("нигер", "NG"), ("nigeria", "NG"), ("lagos", "NG"), ("abuja", "NG"),
        ]
        // Longer stems first to avoid short false hits.
        for (stem, code) in stems.sorted(by: { $0.0.count > $1.0.count }) where lower.contains(stem) {
            return code
        }
        return nil
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
            return disambiguateDuplicateLabels(locationGroups)
        }
        if !flatLeaves.isEmpty {
            return disambiguateDuplicateLabels(flatLeaves)
        }

        // Flat configs with no root selector members: every non-group outbound/endpoint.
        let flat = objectByTag.keys.sorted().compactMap { tag -> VPNServer? in
            guard let object = objectByTag[tag] else { return nil }
            let type = (object["type"] as? String)?.lowercased() ?? ""
            if ["selector", "urltest", "direct", "block", "dns"].contains(type) { return nil }
            return parse(tag: tag, groupTag: groupTag)
        }
        return disambiguateDuplicateLabels(flat)
    }

    /// When several rows share the same display label (e.g. TW France + France → «France»),
    /// number them «France 1», «France 2» so the picker stays unambiguous.
    private static func disambiguateDuplicateLabels(_ servers: [VPNServer]) -> [VPNServer] {
        var totals: [String: Int] = [:]
        for server in servers {
            totals[server.locationLabel.lowercased(), default: 0] += 1
        }
        var seen: [String: Int] = [:]
        return servers.map { server in
            let key = server.locationLabel.lowercased()
            guard totals[key, default: 0] > 1 else { return server }
            seen[key, default: 0] += 1
            let numbered = "\(server.locationLabel) \(seen[key]!)"
            return VPNServer(
                id: server.id,
                city: numbered,
                country: numbered,
                countryCode: server.countryCode,
                ping: server.ping,
                load: server.load,
                groupTag: server.groupTag,
                locationLabel: numbered
            )
        }
    }

    /// 5G / anti-block profile: only nodes whose names mention mobile-bypass keywords.
    public static func matchesAntiBlockOrMobileProfile(_ server: VPNServer) -> Bool {
        let hay = "\(server.id) \(server.city) \(server.country)".lowercased()
        let needles = [
            "5g",
            "lte",
            "обход",
            "белые списки",
            "белый список",
            "whitelist",
            "white list",
            "white-list",
            "ограничен",
            "антиблок",
            "antiblock",
        ]
        return needles.contains { hay.contains($0) }
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
            city: VPNCountryCatalog.englishPlaceName(for: bestCity),
            country: VPNCountryCatalog.englishPlaceName(for: countryName(for: bestCode) ?? bestCountry),
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

        // Named country tokens first (>2 chars); skip ambiguous hoster codes like TimeWeb `tw`.
        for token in tokens where token.count > 2 {
            if let exact = VPNCountryCatalog.exactCode(for: token) {
                return exact == "UK" ? "GB" : exact
            }
        }

        // Bare ISO tokens last — never Wi-Fi fragments (`fi`) or other noise.
        for token in tokens where token.count == 2 {
            if ambiguousHosterCodes.contains(token.uppercased()) { continue }
            if nonCountryNoiseTokens.contains(token) { continue }
            if let exact = VPNCountryCatalog.exactCode(for: token) {
                return exact == "UK" ? "GB" : exact
            }
        }

        if let code = VPNCountryCatalog.containsCode(in: scrubNetworkNoise(lower)) {
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
