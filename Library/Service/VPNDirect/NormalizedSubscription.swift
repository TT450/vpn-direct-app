import Foundation

/// Kind of selectable Remnawave / Happ location.
public enum NormalizedLocationKind: String, Equatable, Sendable {
    case country
    case globalAuto
}

/// How leaf endpoints are selected inside a location.
public enum NormalizedLocationStrategy: String, Equatable, Sendable {
    /// One selectable leaf (or leaf retagged with location name).
    case single
    /// Happ-style location urltest over multiple leaves / balancer backends.
    case urltest
}

/// A selectable location (country row or global Auto aggregate).
public struct NormalizedLocation: Equatable {
    public var id: String
    public var name: String
    public var kind: NormalizedLocationKind
    public var strategy: NormalizedLocationStrategy
    public var endpoints: [NormalizedNode]

    public init(
        id: String,
        name: String,
        kind: NormalizedLocationKind,
        strategy: NormalizedLocationStrategy,
        endpoints: [NormalizedNode]
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.strategy = strategy
        self.endpoints = endpoints
    }
}

/// Full subscription intermediate model: metadata + locations of endpoints.
public struct NormalizedSubscription: Equatable {
    public var name: String?
    public var locations: [NormalizedLocation]
    public var metadata: SubscriptionMetadata

    public init(
        name: String? = nil,
        locations: [NormalizedLocation] = [],
        metadata: SubscriptionMetadata = SubscriptionMetadata()
    ) {
        self.name = name
        self.locations = locations
        self.metadata = metadata
    }

    public var allEndpoints: [NormalizedNode] {
        locations.flatMap(\.endpoints)
    }

    public var endpointCount: Int {
        allEndpoints.count
    }
}
