#if os(iOS)

import Foundation

/// Country / city / state aliases for VPN server labels (EN + RU).
/// Used by `VPNServerNameParser` so flags resolve for Remnawave / Happ-style names.
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
        if let ru = Locale(identifier: "ru_RU").localizedString(forRegionCode: normalized), !ru.isEmpty {
            return ru
        }
        if let en = Locale(identifier: "en_US").localizedString(forRegionCode: normalized), !en.isEmpty {
            return en
        }
        return nil
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
        put(["usa", "us", "u.s.", "u.s.a.", "america", "united states", "united states of america", "сша"], "US")
        put(["uk", "gb", "britain", "great britain", "england", "united kingdom", "великобритания", "англия"], "GB")
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

    private static let containsAliasesSorted: [(String, String)] = {
        var pairs: [(String, String)] = []
        func add(_ keys: [String], _ code: String) {
            for key in keys {
                let n = normalize(key)
                // Avoid short stems that false-positive inside other names (e.g. "oman" ⊂ "romania").
                guard n.count >= 4 || ["usa", "uae"].contains(n) else { continue }
                pairs.append((n, code))
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
        add(["brazil", "brazilian", "бразил"], "BR")
        add(["india", "indian", "инди"], "IN")
        add(["israel", "израил"], "IL")
        add(["kazakhstan", "казах"], "KZ")
        add(["singapore", "сингапур"], "SG")
        add(["armenia", "армен"], "AM")
        add(["georgia", "грузи"], "GE")
        add(["azerbaijan", "азербайдж"], "AZ")

        // Dedupe by alias keeping first (longest will sort later).
        var seen = Set<String>()
        var unique: [(String, String)] = []
        for pair in pairs {
            if seen.insert(pair.0).inserted {
                unique.append(pair)
            }
        }
        return unique.sorted { $0.0.count > $1.0.count }
    }()

    static func normalize(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}

#endif
