import Foundation

#if os(iOS)

/// Public location metadata for the Direct «Локации» tab.
/// No credentials — safe to ship in the app and cache on CDN.
public struct DirectLocationRecord: Codable, Hashable, Identifiable {
    public let id: String
    public let countryCode: String
    public let country: String
    public let city: String
    public let region: String

    public init(
        id: String,
        countryCode: String,
        country: String,
        city: String,
        region: String
    ) {
        self.id = id
        self.countryCode = countryCode
        self.country = country
        self.city = city
        self.region = region
    }

    public func asServerItem(latency: Int = 0, load: Int = 0) -> DirectServerItem {
        DirectServerItem(
            id: id,
            countryCode: countryCode,
            country: country,
            city: city,
            latency: latency,
            load: load,
            region: region
        )
    }

    public static func from(server: VPNServer) -> DirectLocationRecord {
        DirectLocationRecord(
            id: server.id,
            countryCode: server.countryCode,
            country: server.country.isEmpty ? server.locationLabel : server.country,
            city: server.city.isEmpty ? server.locationLabel : server.city,
            region: DirectServerItem.region(for: server.countryCode)
        )
    }
}

private struct DirectLocationsPayload: Codable {
    let updatedAt: String?
    let locations: [DirectLocationRecord]
}

/// Direct locations catalog — Direct product servers only (seed / cache / optional CDN).
/// Never mixes third-party imported subscription nodes.
///
/// Sources (priority):
/// 1. Disk cache (last good fetch / ingest)
/// 2. Local Direct API binding (if installed)
/// 3. Remote JSON CDN URL if configured
/// 4. Bundled seed (offline / first launch)
@MainActor
public final class DirectLocationsCatalog: ObservableObject {
    public static let shared = DirectLocationsCatalog()

    /// Ops: optional public locations JSON URL (no secrets). Empty = disabled.
    public static var remoteCatalogURLString: String = ""

    /// Injected by local backend hooks. Default returns empty.
    public static var fetchLocationsHandler: () async throws -> [DirectLocationRecord] = {
        DirectBackendRuntime.warmUp()
        return try await DirectBackendRuntime.fetchLocations()
    }

    /// Minimum interval between CDN fetches (also respects ETag 304).
    public static let remoteTTL: TimeInterval = 12 * 60 * 60

    @Published public private(set) var locations: [DirectLocationRecord] = []
    @Published public private(set) var lastUpdated: Date?
    @Published public private(set) var isRefreshing = false

    private let cacheURL: URL
    private let etagKey = "vpndirect.locations.catalog.etag.v2"
    private let fetchedAtKey = "vpndirect.locations.catalog.fetchedAt.v2"
    private let cacheVersionKey = "vpndirect.locations.catalog.cacheVersion"
    private static let cacheVersion = 2

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        cacheURL = base.appendingPathComponent("direct_locations_catalog_v2.json")
        // Drop polluted v1 cache that may have absorbed third-party nodes.
        if UserDefaults.standard.integer(forKey: cacheVersionKey) != Self.cacheVersion {
            UserDefaults.standard.set(Self.cacheVersion, forKey: cacheVersionKey)
            UserDefaults.standard.removeObject(forKey: "vpndirect.locations.catalog.etag")
            UserDefaults.standard.removeObject(forKey: "vpndirect.locations.catalog.fetchedAt")
            let legacy = base.appendingPathComponent("direct_locations_catalog.json")
            try? FileManager.default.removeItem(at: legacy)
            locations = Self.seed
            lastUpdated = nil
            persistDisk(Self.seed)
        } else {
            locations = loadDisk() ?? Self.seed
            lastUpdated = UserDefaults.standard.object(forKey: fetchedAtKey) as? Date
        }
    }

    public var items: [DirectServerItem] {
        locations.map { $0.asServerItem() }
    }

    /// Replace catalog entirely with Direct servers (no merge with foreign leftovers).
    public func replace(with servers: [VPNServer]) {
        let mapped = servers
            .filter { !$0.id.isEmpty && $0.id.lowercased() != "direct" && $0.id.lowercased() != "auto" }
            .map(DirectLocationRecord.from(server:))
        // Dedupe by id, keep first occurrence order.
        var seen = Set<String>()
        var unique: [DirectLocationRecord] = []
        for item in mapped where seen.insert(item.id).inserted {
            unique.append(item)
        }
        guard !unique.isEmpty else { return }
        locations = unique
        lastUpdated = Date()
        persistDisk(unique)
        UserDefaults.standard.set(lastUpdated, forKey: fetchedAtKey)
    }

    /// Legacy name — now replaces instead of merging foreign nodes in.
    public func ingest(servers: [VPNServer]) {
        replace(with: servers)
    }

    /// Refresh from Direct product API when local bindings are installed.
    public func refreshFromBackendIfNeeded(force: Bool = false) async {
        if !force, let fetched = UserDefaults.standard.object(forKey: fetchedAtKey) as? Date,
           Date().timeIntervalSince(fetched) < Self.remoteTTL
        {
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let remote = try await Self.fetchLocationsHandler()
            guard !remote.isEmpty else {
                await refreshFromRemoteIfNeeded(force: force)
                return
            }
            locations = remote
            lastUpdated = Date()
            persistDisk(remote)
            UserDefaults.standard.set(lastUpdated, forKey: fetchedAtKey)
        } catch {
            await refreshFromRemoteIfNeeded(force: force)
        }
    }

    /// Refresh from optional CDN URL if configured. Never throws into UI.
    public func refreshFromRemoteIfNeeded(force: Bool = false) async {
        let urlString = Self.remoteCatalogURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: urlString), !urlString.isEmpty else { return }
        if !force, let fetched = UserDefaults.standard.object(forKey: fetchedAtKey) as? Date,
           Date().timeIntervalSince(fetched) < Self.remoteTTL
        {
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        if let etag = UserDefaults.standard.string(forKey: etagKey), !etag.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }
            if http.statusCode == 304 {
                UserDefaults.standard.set(Date(), forKey: fetchedAtKey)
                lastUpdated = Date()
                return
            }
            guard (200 ... 299).contains(http.statusCode) else { return }
            let decoded = try JSONDecoder().decode(DirectLocationsPayload.self, from: data)
            guard !decoded.locations.isEmpty else { return }
            locations = decoded.locations
            lastUpdated = Date()
            persistDisk(decoded.locations)
            UserDefaults.standard.set(lastUpdated, forKey: fetchedAtKey)
            if let etag = http.value(forHTTPHeaderField: "ETag") {
                UserDefaults.standard.set(etag, forKey: etagKey)
            }
        } catch {
            // Keep seed / disk cache — never blank the UI on network failure.
        }
    }

    private func loadDisk() -> [DirectLocationRecord]? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(DirectLocationsPayload.self, from: data).locations
    }

    private func persistDisk(_ records: [DirectLocationRecord]) {
        let payload = DirectLocationsPayload(updatedAt: ISO8601DateFormatter().string(from: Date()), locations: records)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    private static func merge(preferred: [DirectLocationRecord], fallback: [DirectLocationRecord]) -> [DirectLocationRecord] {
        // Intentionally unused — catalog must never silently keep foreign leftovers.
        preferred.isEmpty ? fallback : preferred
    }

    /// Offline seed — Direct-shaped metadata only (not third-party imports).
    public static let seed: [DirectLocationRecord] = [
        .init(id: "de-frankfurt", countryCode: "DE", country: "Germany", city: "Frankfurt", region: "EUROPE"),
        .init(id: "nl-amsterdam", countryCode: "NL", country: "Netherlands", city: "Amsterdam", region: "EUROPE"),
        .init(id: "fi-helsinki", countryCode: "FI", country: "Finland", city: "Helsinki", region: "EUROPE"),
        .init(id: "se-stockholm", countryCode: "SE", country: "Sweden", city: "Stockholm", region: "EUROPE"),
        .init(id: "lv-riga", countryCode: "LV", country: "Latvia", city: "Riga", region: "EUROPE"),
        .init(id: "pl-warsaw", countryCode: "PL", country: "Poland", city: "Warsaw", region: "EUROPE"),
        .init(id: "am-yerevan", countryCode: "AM", country: "Armenia", city: "Yerevan", region: "EUROPE"),
        .init(id: "tr-istanbul", countryCode: "TR", country: "Turkey", city: "Istanbul", region: "EUROPE"),
        .init(id: "ae-dubai", countryCode: "AE", country: "United Arab Emirates", city: "Dubai", region: "ASIA"),
        .init(id: "sg-singapore", countryCode: "SG", country: "Singapore", city: "Singapore", region: "ASIA"),
        .init(id: "us-newyork", countryCode: "US", country: "United States", city: "New York", region: "AMERICAS"),
    ]
}

#endif
