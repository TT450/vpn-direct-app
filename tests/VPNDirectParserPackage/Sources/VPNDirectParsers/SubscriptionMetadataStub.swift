import Foundation

/// Package stub mirroring Library `SubscriptionMetadata` fields used by NormalizedSubscription.
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
    public var announce: String?
    public var supportURL: String?
    public var profileWebPageURL: String?
    public var updateIntervalHours: Int?
    public var routingEnabled: Bool?
    public var routingRules: String?
    public var providerID: String?
    public var etag: String?
    public var lastModified: String?
    public var compatibilityProfileID: String?

    public init(
        title: String? = nil,
        expireTimestamp: Int64? = nil,
        uploadBytes: Int64? = nil,
        downloadBytes: Int64? = nil,
        totalBytes: Int64? = nil,
        deviceLimit: Int? = nil,
        deviceUsed: Int? = nil,
        hwidLimitEnabled: Bool? = nil,
        unlimitedDevices: Bool = false,
        announce: String? = nil,
        supportURL: String? = nil,
        profileWebPageURL: String? = nil,
        updateIntervalHours: Int? = nil,
        routingEnabled: Bool? = nil,
        routingRules: String? = nil,
        providerID: String? = nil,
        etag: String? = nil,
        lastModified: String? = nil,
        compatibilityProfileID: String? = nil
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
        self.announce = announce
        self.supportURL = supportURL
        self.profileWebPageURL = profileWebPageURL
        self.updateIntervalHours = updateIntervalHours
        self.routingEnabled = routingEnabled
        self.routingRules = routingRules
        self.providerID = providerID
        self.etag = etag
        self.lastModified = lastModified
        self.compatibilityProfileID = compatibilityProfileID
    }
}
