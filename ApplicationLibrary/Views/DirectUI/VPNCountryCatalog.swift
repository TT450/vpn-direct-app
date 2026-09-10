#if os(iOS)

import Foundation

/// Country / city / state aliases for VPN server labels.
/// Resolves Remnawave / Happ-style EN+RU names to a single English display label.
enum VPNCountryCatalog {
    /// All ISO 3166-1 alpha-2 codes known to the system, plus UK → GB alias.
    static let isoCodes: Set<String> = {
        var codes = Set(Locale.isoRegionCodes.map { $0.uppercased() })
        codes.insert("UK")
        return codes
    }()

    static func displayName(for code: String) -> String? {
        let upper = code.uppercased()
        let normalized = upper == "UK" ? "GB" : upper
        // Stable English labels for the picker (never Russian duplicates).
        switch normalized {
        case "US": return "USA"
        case "GB": return "United Kingdom"
        default:
            break
        }
        if let en = Locale(identifier: "en_US").localizedString(forRegionCode: normalized), !en.isEmpty {
            return en
        }
        return nil
    }

    /// English capital (or primary metro) for country-only VPN tags.
    /// Unused — country-normalized UI shows the country name, never a capital.
    @available(*, deprecated, message: "Do not invent capitals; show country names.")
    static func capitalEnglishName(for code: String) -> String? {
        nil
    }

    /// Resolve incomplete / multi-word country phrases from VPN tags.
    /// Handles: "United", "United Kingdom", "Great", "Great Britain", "Czech", "Saudi", …
    static func resolveCountryPhrase(in raw: String, preferCode: String? = nil) -> (code: String, englishName: String)? {
        let n = normalize(raw)
        guard !n.isEmpty else { return nil }

        let cacheKey = "\(preferCode?.uppercased() ?? "")|\(n)" as NSString
        if let cached = phraseCache.object(forKey: cacheKey) as? PhraseBox {
            return (cached.code, cached.englishName)
        }

        let resolved: (code: String, englishName: String)?
        // Whole-string exact first.
        if let code = exactCode(for: n), let name = displayName(for: code) {
            resolved = (code == "UK" ? "GB" : code, name)
        } else if let hit = matchLeadingISOCountryName(in: n) {
            resolved = hit
        } else if let hit = resolveAmbiguousCountryStarter(n, preferCode: preferCode) {
            resolved = hit
        } else if let code = containsCode(in: n), let name = displayName(for: code) {
            resolved = (code == "UK" ? "GB" : code, name)
        } else {
            resolved = nil
        }

        if let resolved {
            phraseCache.setObject(PhraseBox(code: resolved.code, englishName: resolved.englishName), forKey: cacheKey)
        }
        return resolved
    }

    /// "united kingdom foo" / "south korea bar" — longest prebuilt EN name that is a prefix or exact.
    private static func matchLeadingISOCountryName(in normalized: String) -> (code: String, englishName: String)? {
        var best: (code: String, englishName: String, len: Int)?

        // Exact Locale EN name.
        if let hit = isoEnglishExact[normalized] {
            return hit
        }

        // Longest prebuilt name that is a prefix / contained token — no Locale scan per call.
        for entry in isoEnglishByLength {
            let enNorm = entry.norm
            if normalized.hasPrefix(enNorm + " ")
                || normalized.contains(" " + enNorm)
                || normalized.contains(" " + enNorm + " ")
            {
                let len = enNorm.count
                if best == nil || len > best!.len {
                    best = (entry.code, entry.english, len)
                }
                // Names are sorted longest-first; first hit is enough for prefix, but
                // keep scanning briefly for longer contained aliases below.
                break
            }
        }

        // Also common aliases not identical to Locale names.
        for (alias, code) in multiWordCountryAliases {
            if normalized == alias || normalized.hasPrefix(alias + " ") || normalized.contains(" " + alias) {
                let len = alias.count
                if best == nil || len > best!.len {
                    best = (code, displayName(for: code) ?? alias, len)
                }
            }
        }
        guard let best else { return nil }
        return (best.code, best.englishName)
    }

    /// Truncated starters: United / Great / Saudi / Czech / South / North / Dominican / …
    private static func resolveAmbiguousCountryStarter(_ normalized: String, preferCode: String?) -> (code: String, englishName: String)? {
        let tokens = normalized
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.whitespaces)
            .filter { !$0.isEmpty }
        guard let first = tokens.first else { return nil }
        let rest = tokens.dropFirst().joined(separator: " ")

        func finish(_ code: String) -> (String, String)? {
            let c = code == "UK" ? "GB" : code
            guard let name = displayName(for: c) else { return nil }
            return (c, name)
        }

        // Prefer emoji / already-known code when starter is ambiguous.
        if let prefer = preferCode?.uppercased(), prefer != "XX", !prefer.isEmpty {
            let p = prefer == "UK" ? "GB" : prefer
            switch first {
            case "united", "юнайтед", "юнайтедк":
                if ["GB", "US", "AE"].contains(p) { return finish(p) }
            case "great", "грейт", "грит", "brit", "britain", "британ":
                if p == "GB" { return finish("GB") }
            case "south", "юг", "южн":
                if ["KR", "ZA", "SS", "SD"].contains(p) { return finish(p) }
            case "north", "север":
                if ["KP", "MK", "NO"].contains(p) { return finish(p) }
            default:
                break
            }
        }

        switch first {
        case "united", "юнайтед":
            if rest.hasPrefix("kingdom") || rest.hasPrefix("king") || rest.contains("britain")
                || rest.hasPrefix("корол") || rest.contains("британ")
            {
                return finish("GB")
            }
            if rest.hasPrefix("state") || rest.hasPrefix("states") || rest.contains("america")
                || rest.hasPrefix("штат") || rest.contains("америк")
            {
                return finish("US")
            }
            if rest.contains("arab") || rest.contains("emirat") || rest.contains("араб") || rest.contains("эмират") {
                return finish("AE")
            }
            // Bare "United" in VPN lists is almost always UK (Durev / Happ tags).
            if rest.isEmpty { return finish("GB") }
            return finish("GB")

        case "great", "грейт", "грит", "britain", "brit", "британ":
            return finish("GB")

        case "kingdom", "корол":
            return finish("GB")

        case "czech", "czechia", "чехи", "чешск":
            return finish("CZ")

        case "saudi", "сауд":
            return finish("SA")

        case "dominican", "доминикан":
            // "Dominican" alone → Republic (DO), not Dominica (DM)
            if rest.hasPrefix("republic") || rest.isEmpty { return finish("DO") }
            return finish("DO")

        case "south", "южн":
            if rest.hasPrefix("korea") || rest.hasPrefix("коре") { return finish("KR") }
            if rest.hasPrefix("africa") || rest.hasPrefix("афри") { return finish("ZA") }
            if rest.hasPrefix("sudan") || rest.hasPrefix("судан") { return finish("SS") }
            return nil

        case "north", "северн", "север":
            if rest.hasPrefix("korea") || rest.hasPrefix("коре") { return finish("KP") }
            if rest.hasPrefix("macedonia") || rest.hasPrefix("македон") { return finish("MK") }
            return nil

        case "papu", "papua":
            return finish("PG")

        case "costa":
            if rest.hasPrefix("rica") { return finish("CR") }
            return nil

        case "el":
            if rest.hasPrefix("salvador") { return finish("SV") }
            return nil

        case "sri":
            if rest.hasPrefix("lanka") { return finish("LK") }
            return nil

        case "new":
            if rest.hasPrefix("zealand") || rest.hasPrefix("зеланд") { return finish("NZ") }
            if rest.hasPrefix("caledonia") { return finish("NC") }
            return nil

        case "hong":
            if rest.hasPrefix("kong") || rest.isEmpty { return finish("HK") }
            return nil

        default:
            return nil
        }
    }

    /// Emirate-only English label (never "United Arab Emirates").
    static func emirateEnglishName(in raw: String) -> String? {
        let n = normalize(raw)
        let stems: [(String, String)] = [
            ("abu dhabi", "Abu Dhabi"),
            ("абу-даби", "Abu Dhabi"),
            ("абу даби", "Abu Dhabi"),
            ("абудаби", "Abu Dhabi"),
            ("ras al khaimah", "Ras Al Khaimah"),
            ("ras al-khaimah", "Ras Al Khaimah"),
            ("рас-эль-хайма", "Ras Al Khaimah"),
            ("umm al quwain", "Umm Al Quwain"),
            ("umm al-quwain", "Umm Al Quwain"),
            ("dubai", "Dubai"),
            ("дубай", "Dubai"),
            ("sharjah", "Sharjah"),
            ("шаржа", "Sharjah"),
            ("ajman", "Ajman"),
            ("аджаман", "Ajman"),
            ("аджуман", "Ajman"),
            ("fujairah", "Fujairah"),
            ("фуджайра", "Fujairah"),
        ]
        for (stem, label) in stems.sorted(by: { $0.0.count > $1.0.count }) where n.contains(stem) {
            return label
        }
        return nil
    }

    static func isUnitedArabEmiratesLabel(_ raw: String) -> Bool {
        let n = normalize(raw)
        return n == "ae"
            || n == "uae"
            || n.contains("united arab emirates")
            || n.contains("оаэ")
            || n == "emirates"
            || n.contains("арабск") && n.contains("эмират")
    }

    /// Normalize a place token (country / city / state) to a single English label when known.
    static func englishPlaceName(for raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let cacheKey = trimmed as NSString
        if let cached = placeNameCache.object(forKey: cacheKey) {
            return cached as String
        }
        let resolved = resolveEnglishPlaceName(trimmed)
        placeNameCache.setObject(resolved as NSString, forKey: cacheKey)
        return resolved
    }

    private static func resolveEnglishPlaceName(_ trimmed: String) -> String {
        if let emirate = emirateEnglishName(in: trimmed) {
            return emirate
        }
        if let phrase = resolveCountryPhrase(in: trimmed) {
            return phrase.englishName
        }
        let n = normalize(trimmed)
        if let mapped = englishPlaceByNormalized[n] {
            return mapped
        }
        if let code = exactAliases[n] {
            return displayName(for: code) ?? trimmed
        }
        // Preserve trailing index markers: "Швеция 2" / "Sweden #2".
        if let split = splitTrailingIndex(trimmed) {
            let head = englishPlaceName(for: split.head)
            return "\(head) \(split.suffix)"
        }
        if containsCyrillic(trimmed), let code = containsCode(in: n) {
            for (alias, _) in containsAliasesSorted where n.contains(alias) {
                if let label = englishPlaceByNormalized[alias] {
                    return label
                }
            }
            return displayName(for: code) ?? trimmed
        }
        return trimmed
    }

    private static func containsCyrillic(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0400 ... 0x04FF).contains($0.value) }
    }

    private static func splitTrailingIndex(_ text: String) -> (head: String, suffix: String)? {
        let parts = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard parts.count >= 2, let last = parts.last else { return nil }
        let marker = last.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard marker.allSatisfy(\.isNumber), !marker.isEmpty else { return nil }
        let head = parts.dropLast().joined(separator: " ")
        return (head, last.hasPrefix("#") ? "#\(marker)" : marker)
    }

    /// Exact whole-string match (lowercased, ё→е).
    static func exactCode(for normalized: String) -> String? {
        exactAliases[normalized]
    }

    /// Longest substring alias wins.
    static func containsCode(in haystack: String) -> String? {
        for (alias, code) in containsAliasesSorted where haystack.contains(alias) {
            return code
        }
        return nil
    }

    // MARK: - Exact aliases (countries)

    private static let exactAliases: [String: String] = {
        var map: [String: String] = [:]
        func put(_ keys: [String], _ code: String) {
            for key in keys {
                map[normalize(key)] = code
            }
        }

        // ISO display names from Locale (EN + RU) for every region.
        for code in Locale.isoRegionCodes {
            let upper = code.uppercased()
            if let en = Locale(identifier: "en_US").localizedString(forRegionCode: code) {
                put([en], upper)
            }
            if let ru = Locale(identifier: "ru_RU").localizedString(forRegionCode: code) {
                put([ru], upper)
            }
        }

        // Common VPN / panel short names and English variants Locale misses.
        put(["uk", "gb", "britain", "great britain", "great", "england", "united kingdom", "united", "великобритания", "англия", "грит", "грейт", "юнайтед"], "GB")
        put(["usa", "us", "u.s.", "u.s.a.", "america", "united states", "united states of america", "сша"], "US")
        put(["uae", "оаэ", "emirates", "united arab emirates"], "AE")
        put(["korea", "south korea", "republic of korea", "корея", "южная корея"], "KR")
        put(["north korea", "dprk", "кндр", "северная корея"], "KP")
        put(["czech", "czechia", "czech republic", "чехия"], "CZ")
        put(["holland", "netherlands", "the netherlands", "нидерланды", "голландия"], "NL")
        put(["hong kong", "hongkong", "гонконг"], "HK")
        put(["macau", "macao", "макао"], "MO")
        put(["taiwan", "тайвань", "тайван"], "TW")
        put(["russia", "russian federation", "россия", "рф"], "RU")
        put(["vietnam", "viet nam", "вьетнам"], "VN")
        put(["laos", "лаос"], "LA")
        put(["moldova", "молдова", "молдавия"], "MD")
        put(["bosnia", "bosnia and herzegovina", "босния", "босния и герцеговина"], "BA")
        put(["macedonia", "north macedonia", "северная македония", "македония"], "MK")
        put(["ivory coast", "cote divoire", "cote d'ivoire", "кот-д'ивуар", "кот д ивуар"], "CI")
        put(["palestine", "палестина"], "PS")
        put(["vatican", "holy see", "ватикан"], "VA")
        put(["brunei", "бруней"], "BN")
        put(["myanmar", "burma", "мьянма", "бирма"], "MM")
        put(["eswatini", "swaziland", "эсватини", "свазиленд"], "SZ")
        put(["cabo verde", "cape verde", "кабо-верде"], "CV")
        put(["congo", "republic of the congo", "конго"], "CG")
        put(["dr congo", "democratic republic of the congo", "дрк", "конго-киншаса"], "CD")

        return map
    }()

    // MARK: - Substring aliases (capitals, cities, US states, CA/EU metros)

    private static let placeAliasTables: (contains: [(String, String)], english: [String: String]) = {
        var pairs: [(String, String)] = []
        var english: [String: String] = [:]

        func isCyrillicWord(_ text: String) -> Bool {
            text.unicodeScalars.contains { (0x0400 ... 0x04FF).contains($0.value) }
        }

        func titleCaseEnglish(_ raw: String) -> String {
            raw.split(separator: " ").map { part in
                let p = String(part)
                guard let first = p.first else { return p }
                return String(first).uppercased() + p.dropFirst().lowercased()
            }.joined(separator: " ")
        }

        func add(_ keys: [String], _ code: String) {
            let englishKey = keys.first(where: { !isCyrillicWord($0) }) ?? keys.first ?? code
            let label = titleCaseEnglish(englishKey)
            for key in keys {
                let n = normalize(key)
                // Avoid short stems that false-positive inside other names (e.g. "oman" ⊂ "romania").
                guard n.count >= 4 || ["usa", "uae"].contains(n) else { continue }
                pairs.append((n, code))
                english[n] = label
            }
        }

        // Do NOT dump every ISO display name into substring matching — short names
        // like "oman" / "chad" / "peru" collide with other words. Exact match covers
        // full country names; here we keep cities, capitals, states, and safe stems.

        // ——— Capitals & major cities (EN + RU) ———
        add(["berlin", "берлин", "frankfurt", "франкфурт", "munich", "мюнхен", "hamburg", "гамбург", "dusseldorf", "дюссельдорф", "cologne", "кёльн", "кельн"], "DE")
        add(["amsterdam", "амстердам", "rotterdam", "роттердам", "the hague", "гаага"], "NL")
        add(["paris", "париж", "lyon", "лион", "marseille", "марсель", "nice", "ницца"], "FR")
        add(["helsinki", "хельсинки", "хельсин"], "FI")
        add(["stockholm", "стокгольм", "gothenburg", "гётеборг", "гетеборг"], "SE")
        add(["oslo", "осло", "bergen", "берген"], "NO")
        add(["copenhagen", "копенгаген"], "DK")
        add(["brussels", "брюссель", "antwerp", "антверпен"], "BE")
        add(["vienna", "вена", "salzburg", "зальцбург"], "AT")
        add(["zurich", "цюрих", "geneva", "женева", "bern", "берн", "basel", "базель"], "CH")
        add(["prague", "прага", "brno", "брно"], "CZ")
        add(["warsaw", "варшава", "варшав", "krakow", "краков", "gdansk", "гданьск"], "PL")
        add(["budapest", "будапешт"], "HU")
        add(["bucharest", "бухарест"], "RO")
        add(["sofia", "софия"], "BG")
        add(["athens", "афины", "афин"], "GR")
        add(["lisbon", "лиссабон", "porto", "порту"], "PT")
        add(["madrid", "мадрид", "barcelona", "барселона", "valencia", "валенсия"], "ES")
        add(["rome", "рим", "milan", "милан", "naples", "неаполь", "turin", "турин", "florence", "флоренция"], "IT")
        add(["dublin", "дублин"], "IE")
        add(["london", "лондон", "manchester", "манчестер", "birmingham", "бирмингем", "edinburgh", "эдинбург", "glasgow", "глазго"], "GB")
        add(["reykjavik", "рейкьявик"], "IS")
        add(["luxembourg", "люксембург"], "LU")
        add(["monaco", "монако"], "MC")
        add(["vaduz", "вадуц"], "LI")
        add(["valletta", "валлетта"], "MT")
        add(["nicosia", "никосия"], "CY")
        add(["zagreb", "загреб"], "HR")
        add(["ljubljana", "любляна"], "SI")
        add(["bratislava", "братислава"], "SK")
        add(["belgrade", "белград"], "RS")
        add(["sarajevo", "сараево"], "BA")
        add(["podgorica", "подгорица"], "ME")
        add(["tirana", "тирана"], "AL")
        add(["skopje", "скопье", "скопje"], "MK")
        add(["chisinau", "кишинев", "кишинёв"], "MD")
        add(["kyiv", "kiev", "киев", "київ", "lviv", "львов", "odesa", "одесса"], "UA")
        add(["minsk", "минск"], "BY")
        add(["moscow", "москва", "москв", "saint petersburg", "санкт-петербург", "петербург", "новосибирск", "екатеринбург"], "RU")
        add(["almaty", "алматы", "astana", "астана", "nur-sultan", "нур-султан"], "KZ")
        add(["tashkent", "ташкент"], "UZ")
        add(["bishkek", "бишкек"], "KG")
        add(["dushanbe", "душанбе"], "TJ")
        add(["ashgabat", "ашхабад"], "TM")
        add(["yerevan", "ереван"], "AM")
        add(["tbilisi", "тбилиси", "тбилис"], "GE")
        add(["baku", "баку"], "AZ")
        add(["ankara", "анкара", "istanbul", "стамбул", "izmir", "измир"], "TR")
        add(["tel aviv", "тель-авив", "тель авив", "jerusalem", "иерусалим"], "IL")
        add(["dubai", "дубай", "abu dhabi", "абу-даби", "абу даби"], "AE")
        add(["doha", "доха"], "QA")
        add(["riyadh", "эр-рияд", "jeddah", "джидда"], "SA")
        add(["kuwait city", "эль-кувейт"], "KW")
        add(["manama", "манама"], "BH")
        add(["muscat", "маскат"], "OM")
        add(["tehran", "тегеран"], "IR")
        add(["baghdad", "багдад"], "IQ")
        add(["beirut", "бейрут"], "LB")
        add(["amman", "амман"], "JO")
        add(["cairo", "каир"], "EG")
        add(["casablanca", "касабланка", "rabat", "рабат"], "MA")
        add(["tunis", "тунис"], "TN")
        add(["algiers", "алжир"], "DZ")
        add(["lagos", "лагос", "abuja", "абуджа"], "NG")
        add(["nairobi", "найроби"], "KE")
        add(["johannesburg", "йоханнесбург", "cape town", "кейптаун", "pretoria", "претория"], "ZA")
        add(["tokyo", "токио", "osaka", "осака", "yokohama", "йокогама"], "JP")
        add(["seoul", "сеул", "busan", "пусан"], "KR")
        add(["beijing", "пекин", "shanghai", "шанхай", "shenzhen", "шэньчжэнь", "guangzhou", "гуанчжоу"], "CN")
        add(["taipei", "тайбэй", "тайпей"], "TW")
        add(["hong kong", "гонконг"], "HK")
        add(["singapore", "сингапур"], "SG")
        add(["bangkok", "бангкок"], "TH")
        add(["hanoi", "ханой", "ho chi minh", "хойшимин", "сайгон"], "VN")
        add(["jakarta", "джакарта"], "ID")
        add(["manila", "манила"], "PH")
        add(["kuala lumpur", "куала-лумпур"], "MY")
        add(["new delhi", "delhi", "дели", "mumbai", "мумбаи", "bangalore", "бангалор"], "IN")
        add(["islamabad", "исламабад", "karachi", "карачи", "lahore", "лахор"], "PK")
        add(["dhaka", "дакка"], "BD")
        add(["colombo", "коломбо"], "LK")
        add(["sydney", "сидней", "melbourne", "мельбурн", "brisbane", "брисбен", "perth", "перт", "canberra", "канберра"], "AU")
        add(["auckland", "окленд", "wellington", "веллингтон"], "NZ")
        add(["sao paulo", "сан-паулу", "rio de janeiro", "рио-де-жанейро", "brasilia", "бразилиа"], "BR")
        add(["buenos aires", "буэнос-айрес"], "AR")
        add(["santiago", "сантьяго"], "CL")
        add(["lima", "лима"], "PE")
        add(["bogota", "богота"], "CO")
        add(["mexico city", "мехико", "guadalajara", "гвадалахара"], "MX")

        // ——— Canada major cities ———
        add([
            "toronto", "торонто", "montreal", "монреаль", "vancouver", "ванкувер",
            "calgary", "калгари", "ottawa", "оттава", "edmonton", "эдмонтон",
            "winnipeg", "виннипег", "quebec city", "квебек", "hamilton", "гамильтон",
            "victoria", "виктория", "halifax", "галифакс", "saskatoon", "саскатун",
            "regina", "реджайна", "mississauga", "миссиссога", "brampton", "брэмптон",
            "surrey", "суррей", "laval", "лаваль", "markham", "маркхэм",
            "burnaby", "бёрнаби", "richmond", "ричмонд", "oakville", "оквилл",
            "burlington", "берлингтон", "oshawa", "ошава", "windsor", "виндзор",
            "london on", "квинстон", "newfoundland", "ньюфаундленд", "nova scotia", "новая шотландия",
            "british columbia", "британская колумбия", "ontario", "онтарио", "quebec", "квебек",
            "alberta", "альберта", "manitoba", "манитоба", "saskatchewan", "саскачеван",
        ], "CA")

        // ——— US states + capitals + major metros ———
        add([
            "united states", "america", "сша", "usa",
            "new york", "нью-йорк", "нью йорк", "los angeles", "лос-анджелес", "лос анджелес",
            "chicago", "чикаго", "houston", "хьюстон", "dallas", "даллас",
            "san francisco", "сан-франциско", "сан франциско", "seattle", "сиэтл", "сиэттл",
            "miami", "майами", "boston", "бостон", "atlanta", "атланта",
            "denver", "денвер", "phoenix", "финикс", "philadelphia", "филадельфия",
            "detroit", "детройт", "san diego", "сан-диего", "сан диего",
            "las vegas", "лас-вегас", "лас вегас", "portland", "портленд",
            "minneapolis", "миннеаполис", "orlando", "орландо", "tampa", "тампа",
            "austin", "остин", "nashville", "нэшвилл", "charlotte", "шарлотт",
            "washington dc", "washington d.c.", "washington", "вашингтон",
            "alabama", "алабама", "montgomery", "монтгомери",
            "alaska", "аляска", "juneau", "джуно", "anchorage", "анкоридж",
            "arizona", "аризона", "phoenix", "финикс",
            "arkansas", "арканзас", "little rock", "литл-рок",
            "california", "калифорния", "sacramento", "сакраменто",
            "colorado", "колорадо", "denver", "денвер",
            "connecticut", "коннектикут", "hartford", "хартфорд",
            "delaware", "делавэр", "dover", "довер",
            "florida", "флорида", "tallahassee", "таллахасси",
            "georgia us", "georgia state", "atlanta", "атланта",
            "hawaii", "гавайи", "honolulu", "гонолулу",
            "idaho", "айдахо", "boise", "бойсе",
            "illinois", "иллинойс", "springfield", "спрингфилд",
            "indiana", "индиана", "indianapolis", "индианаполис",
            "iowa", "айова", "des moines", "де-мойн",
            "kansas", "канзас", "topeka", "топика",
            "kentucky", "кентукки", "frankfort", "франкфорт",
            "louisiana", "луизиана", "baton rouge", "батон-руж", "new orleans", "новый орлеан",
            "maine", "мэйн", "augusta", "огаста",
            "maryland", "мэриленд", "annapolis", "аннаполис", "baltimore", "балтимор",
            "massachusetts", "массачусетс", "boston", "бостон",
            "michigan", "мичиган", "lansing", "лансинг", "detroit", "детройт",
            "minnesota", "миннесота", "saint paul", "сент-пол",
            "mississippi", "миссисипи", "jackson", "джексон",
            "missouri", "миссури", "jefferson city", "джефферсон-сити", "kansas city", "канзас-сити",
            "montana", "монтана", "helena", "хелена",
            "nebraska", "небраска", "lincoln", "линкольн", "omaha", "омаха",
            "nevada", "невада", "carson city", "карсон-сити", "las vegas", "лас-вегас",
            "new hampshire", "нью-хэмпшир", "concord", "конкорд",
            "new jersey", "нью-джерси", "trenton", "трентон", "newark", "ньюарк",
            "new mexico", "нью-мексико", "santa fe", "санта-фе", "albuquerque", "альбукерке",
            "new york state", "albany", "олбани",
            "north carolina", "северная каролина", "raleigh", "роли",
            "north dakota", "северная дакота", "bismarck", "бисмарк",
            "ohio", "огайо", "columbus", "колумбус", "cleveland", "кливленд", "cincinnati", "цинциннати",
            "oklahoma", "оклахома", "oklahoma city", "оклахома-сити", "tulsa", "талса",
            "oregon", "орегон", "salem", "сейлем",
            "pennsylvania", "пенсильвания", "harrisburg", "харрисберг", "pittsburgh", "питсбург",
            "rhode island", "род-айленд", "providence", "провиденс",
            "south carolina", "южная каролина",
            "south dakota", "южная дакота", "pierre", "пирр",
            "tennessee", "теннесси", "nashville", "нэшвилл", "memphis", "мемфис",
            "texas", "техас", "austin", "остин", "houston", "хьюстон", "dallas", "даллас", "san antonio", "сан-антонио",
            "utah", "юта", "salt lake city", "солт-лейк-сити",
            "vermont", "вермонт", "montpelier", "монтпилиер",
            "virginia", "вирджиния",
            "washington state", "olympia", "олимпия",
            "west virginia", "западная вирджиния", "charleston wv",
            "wisconsin", "висконсин", "madison", "мэдисон", "milwaukee", "милуоки",
            "wyoming", "вайоминг", "cheyenne", "шайенн",
            "district of columbia", "округ колумбия",
        ], "US")

        // Extra European country name stems (substring).
        add(["germany", "german", "герман"], "DE")
        add(["france", "french", "франц"], "FR")
        add(["netherlands", "netherland", "holland", "dutch", "нидерл", "голланд"], "NL")
        add(["finland", "finnish", "финлянд"], "FI")
        add(["sweden", "swedish", "швец"], "SE")
        add(["norway", "norwegian", "норвег"], "NO")
        add(["denmark", "danish", "дани"], "DK")
        add(["belgium", "belgian", "бельг"], "BE")
        add(["austria", "австр"], "AT")
        add(["switzerland", "swiss", "швейцар"], "CH")
        add(["poland", "polish", "польш"], "PL")
        add(["spain", "spanish", "испан"], "ES")
        add(["italy", "italian", "итал"], "IT")
        add(["portugal", "portuguese", "португал"], "PT")
        add(["ireland", "irish", "ирланд"], "IE")
        add(["iceland", "icelandic", "исланд"], "IS")
        add(["greece", "greek", "грец", "греци"], "GR")
        add(["hungary", "hungarian", "венгр", "венгер"], "HU")
        add(["romania", "romanian", "румын"], "RO")
        add(["bulgaria", "bulgarian", "болгар"], "BG")
        add(["croatia", "croatian", "хорват"], "HR")
        add(["serbia", "serbian", "серб"], "RS")
        add(["slovakia", "slovak", "словак"], "SK")
        add(["slovenia", "slovenian", "словен"], "SI")
        add(["lithuania", "lithuanian", "литв"], "LT")
        add(["latvia", "latvian", "латви"], "LV")
        add(["estonia", "estonian", "эстон"], "EE")
        add(["ukraine", "украин"], "UA")
        add(["belarus", "белорус", "беларус"], "BY")
        add(["russia", "russian", "росси"], "RU")
        add(["turkey", "turkish", "турц"], "TR")
        add(["japan", "japanese", "япон"], "JP")
        add(["korea", "korean", "коре"], "KR")
        add(["china", "chinese", "китай"], "CN")
        add(["canada", "canadian", "канад"], "CA")
        add(["australia", "australian", "австрал"], "AU")
        add(["brazil", "brazilian", "brasil", "бразил"], "BR")
        add(["india", "indian", "инди"], "IN")
        add(["albania", "albanian", "албан"], "AL")
        add(["nigeria", "nigerian", "нигери"], "NG")
        add(["israel", "израил"], "IL")
        add(["kazakhstan", "казах"], "KZ")
        add(["singapore", "сингапур"], "SG")
        add(["armenia", "армен"], "AM")
        add(["georgia", "грузи"], "GE")
        add(["azerbaijan", "азербайдж"], "AZ")

        // Dedupe by alias keeping first (longest will sort later).
        var seen = Set<String>()
        var unique: [(String, String)] = []
        var englishUnique: [String: String] = [:]
        for pair in pairs {
            if seen.insert(pair.0).inserted {
                unique.append(pair)
                if let label = english[pair.0] {
                    englishUnique[pair.0] = label
                }
            }
        }
        return (unique.sorted { $0.0.count > $1.0.count }, englishUnique)
    }()

    private static var containsAliasesSorted: [(String, String)] { placeAliasTables.contains }

    /// RU/EN aliases → single English display label (countries, cities, states).
    private static let englishPlaceByNormalized: [String: String] = {
        var map = placeAliasTables.english
        for (alias, code) in exactAliases {
            if map[alias] == nil, let en = displayName(for: code) {
                map[alias] = en
            }
        }
        return map
    }()

    /// Built once: Locale EN region names, longest first — avoids per-label ISO scans.
    private static let isoEnglishEntries: [(norm: String, code: String, english: String)] = {
        var rows: [(String, String, String)] = []
        let locale = Locale(identifier: "en_US")
        for code in Locale.isoRegionCodes {
            let upper = code.uppercased()
            guard let en = locale.localizedString(forRegionCode: code), !en.isEmpty else { continue }
            let enNorm = normalize(en)
            guard enNorm.count >= 4 else { continue }
            let display = displayName(for: upper) ?? en
            rows.append((enNorm, upper == "UK" ? "GB" : upper, display))
        }
        return rows.sorted { $0.0.count > $1.0.count }
    }()

    private static let isoEnglishExact: [String: (code: String, englishName: String)] = {
        var map: [String: (String, String)] = [:]
        for entry in isoEnglishEntries {
            map[entry.norm] = (entry.code, entry.english)
        }
        return map
    }()

    private static var isoEnglishByLength: [(norm: String, code: String, english: String)] { isoEnglishEntries }

    private static let multiWordCountryAliases: [(String, String)] = [
        ("united kingdom", "GB"), ("great britain", "GB"), ("britain", "GB"), ("england", "GB"),
        ("united states", "US"), ("united states of america", "US"), ("usa", "US"), ("u.s.a.", "US"),
        ("united arab emirates", "AE"), ("uae", "AE"),
        ("czech republic", "CZ"), ("czechia", "CZ"),
        ("south korea", "KR"), ("north korea", "KP"),
        ("saudi arabia", "SA"), ("south africa", "ZA"),
        ("new zealand", "NZ"), ("papua new guinea", "PG"),
        ("sri lanka", "LK"), ("costa rica", "CR"), ("el salvador", "SV"),
        ("dominican republic", "DO"), ("bosnia and herzegovina", "BA"),
        ("north macedonia", "MK"), ("trinidad and tobago", "TT"),
        ("antigua and barbuda", "AG"), ("saint kitts", "KN"),
        ("vatican", "VA"), ("hong kong", "HK"), ("macau", "MO"), ("macao", "MO"),
    ].sorted { $0.0.count > $1.0.count }

    private static let phraseCache = NSCache<NSString, PhraseBox>()
    private static let placeNameCache = NSCache<NSString, NSString>()

    private final class PhraseBox: NSObject {
        let code: String
        let englishName: String
        init(code: String, englishName: String) {
            self.code = code
            self.englishName = englishName
        }
    }

    static func normalize(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}

#endif
