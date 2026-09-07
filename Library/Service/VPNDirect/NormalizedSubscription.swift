import Foundation

/// Kind of selectable location / group (panel-neutral).
public enum NormalizedLocationKind: String, Equatable, Sendable {
    /// Geo / country-labelled selectable group (only after real geo classification).
    case country
    case globalAuto
    /// Clash / Mihomo / panel proxy group (not a geo country row).
    case group
    /// Single imported share node / custom server (not a country).
    case server
    /// Fallback / priority group.
    case fallback
    /// Custom grouping when source is neither geo nor named proxy-group.
    case custom
}

/// How leaf endpoints are selected inside a location.
/// Extensible via raw string storage on future adapters; known cases map to Core graph types.
public enum NormalizedLocationStrategy: String, Equatable, Sendable {
    /// One selectable leaf (or leaf retagged with location name).
    case single
    /// Latency-based urltest over multiple leaves / balancer backends.
    case urltest
    /// Manual selector (Clash `select`, multi-leaf without auto).
    case select
    /// Prefer first reachable member (Clash `fallback`).
    case fallback
    /// Random member selection when Core/panel semantics require it (no silent urltest swap).
    case random
}

/// A selectable location (country row or global Auto aggregate).
public struct NormalizedLocation: Equatable {
    public var id: String
    public var name: String
    public var kind: NormalizedLocationKind
    public var strategy: NormalizedLocationStrategy
    public var endpoints: [NormalizedNode]
    /// Nested group references (Clash proxy-group → other groups). Resolved by GraphBuilder via location tags.
    public var memberLocationIDs: [String]
    /// Health-check URL for urltest/fallback groups when provided by source.
    public var healthCheckURL: String?
    /// Health-check interval (e.g. "300s", "5m") when provided by source.
    public var healthCheckInterval: String?

    public init(
        id: String,
        name: String,
        kind: NormalizedLocationKind,
        strategy: NormalizedLocationStrategy,
        endpoints: [NormalizedNode],
        memberLocationIDs: [String] = [],
        healthCheckURL: String? = nil,
        healthCheckInterval: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.strategy = strategy
        self.endpoints = endpoints
        self.memberLocationIDs = memberLocationIDs
        self.healthCheckURL = healthCheckURL
        self.healthCheckInterval = healthCheckInterval
    }
}

/// Full subscription intermediate model: metadata + locations of endpoints.
public struct NormalizedSubscription: Equatable {
    public var name: String?
    public var locations: [NormalizedLocation]
    public var metadata: SubscriptionMetadata
    /// Partial-import / conversion warnings (never silent when some leaves fail).
    public var importWarnings: [String]

    public init(
        name: String? = nil,
        locations: [NormalizedLocation] = [],
        metadata: SubscriptionMetadata = SubscriptionMetadata(),
        importWarnings: [String] = []
    ) {
        self.name = name
        self.locations = locations
        self.metadata = metadata
        self.importWarnings = importWarnings
    }

    public var allEndpoints: [NormalizedNode] {
        locations.flatMap(\.endpoints)
    }

    public var endpointCount: Int {
        allEndpoints.count
    }
}
