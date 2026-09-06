import Combine
import Foundation
import Libbox
import Library
import NetworkExtension
import UIKit

#if os(iOS)

@MainActor
public final class VPNConnectionModel: ObservableObject {
    @Published public var selectedTab: AppTab = .home
    @Published public var detailPage: DetailPage?
    @Published public var activeSheet: AppSheet?
    @Published public var connectionMode = "Авто"
    @Published public var isMenuOpen = false
    @Published public private(set) var isConnected = false
    @Published public private(set) var phase: ConnectionPhase = .idle
    @Published public var subscriptions: [VPNSubscriptionItem] = []
    @Published public var activeSubscriptionID: Int64 = 0
    /// `nil` means balancer / auto-select for the active subscription.
    @Published public var selectedServerID: String?
    @Published public var runtimeText = "00:00:00"
    @Published public var trafficText = "—"
    @Published public var alert: AlertState?

    // MARK: - Access sources (Free / Premium / imported)
    @Published public var activeAccess: AccessSource = .free
    @Published public var freeHours = 0
    @Published public var freeTrafficMB = 0
    @Published public var freeExpiresAt: Date?
    @Published public var watchedAds = 0
    @Published public var hasPremiumEntitlement = false
    @Published public var premiumRemainingDays = 0
    @Published public var premiumTrafficGB = 300
    @Published public var premiumDevicesUsed = 1
    @Published public var premiumDeviceLimit = 5
    @Published public var selectedPlanMonths = 1
    @Published public var selectedPlanPrice = 249
    @Published public var paymentMethod: PaymentMethod = .apple
    @Published public var checkoutTitle = "1 месяц Premium"
    @Published public var checkoutPrice = 249
    @Published public var checkoutReturnPage: DetailPage = .premiumPlans
    @Published public var pendingAddOnTrafficGB = 0
    @Published public var pendingAddOnDevice = false
    @Published public var pendingAddOnDay = false
    @Published public var accessChoiceContext: String?
    @Published public var importFromAccessChoice = false

    // Security center (backed by SharedPreferences)
    // Kill Switch (includeAllNetworks) is permanently disabled — it can black-hole Wi‑Fi.
    @Published public var autoConnect = false
    @Published public var unknownWiFi = false
    @Published public var secureDNS = true
    @Published public var localNetwork = true
    @Published public var faceIDLock = false
    @Published public var autoFailover = true
    @Published public var bypassRussianSites = true
    @Published public private(set) var currentWifiSSID: String?
    @Published public private(set) var wifiAccess: DirectWiFiAccess = .needsPermission
    @Published public private(set) var trustedWifiSSIDs: [String] = []

    private weak var environments: ExtensionEnvironments?
    private var isStarting = false
    private var didBind = false
    private var connectAttemptID: UInt64 = 0
    private var connectTimeoutExtended = false
    private var tickTask: Task<Void, Never>?
    private var connectTimeoutTask: Task<Void, Never>?
    private var connectPollTask: Task<Void, Never>?
    private var assignedServerID: String?
    @Published public private(set) var favoriteServerIDs: Set<String> = []
    @Published public private(set) var recentServerIDs: [String] = []
    private var sessionTrafficBaseline: Int64 = 0
    private var lastSessionTrafficTotal: Int64 = 0
    private var skipAccessChoiceGate = false
    private var entitlementDisconnectInFlight = false

    private static let favoritesKey = "vpndirect.favorite.servers"
    private static let recentKey = "vpndirect.recent.servers"
    private static let urltestMigratedKey = "vpndirect.config.urltest.migrated.v1"
    private static let freeHoursKey = "vpndirect.access.free.hours"
    private static let freeTrafficKey = "vpndirect.access.free.traffic.mb"
    private static let freeExpiresAtKey = "vpndirect.access.free.expires_at"
    private static let watchedAdsKey = "vpndirect.access.free.ads"
    private static let accessSourceKey = "vpndirect.access.source"
    private static let premiumEntitlementKey = "vpndirect.access.premium.enabled"
    private static let premiumDaysKey = "vpndirect.access.premium.days"
    private static let premiumTrafficKey = "vpndirect.access.premium.traffic.gb"
    private static let premiumDevicesUsedKey = "vpndirect.access.premium.devices.used"
    private static let premiumDeviceLimitKey = "vpndirect.access.premium.devices.limit"
    private static let builtinsSeededKey = "vpndirect.access.builtins.seeded.v1"

    public init() {
        if let stored = UserDefaults.standard.array(forKey: Self.favoritesKey) as? [String] {
            favoriteServerIDs = Set(stored)
        }
        if let stored = UserDefaults.standard.array(forKey: Self.recentKey) as? [String] {
            recentServerIDs = stored
        }
        freeHours = UserDefaults.standard.integer(forKey: Self.freeHoursKey)
        freeTrafficMB = UserDefaults.standard.integer(forKey: Self.freeTrafficKey)
        if UserDefaults.standard.object(forKey: Self.freeExpiresAtKey) != nil {
            let ts = UserDefaults.standard.double(forKey: Self.freeExpiresAtKey)
            freeExpiresAt = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        } else if freeHours > 0 {
            freeExpiresAt = Date().addingTimeInterval(TimeInterval(freeHours * 3600))
            persistFreeBalance()
        }
        watchedAds = UserDefaults.standard.integer(forKey: Self.watchedAdsKey)
        hasPremiumEntitlement = UserDefaults.standard.bool(forKey: Self.premiumEntitlementKey)
        premiumRemainingDays = UserDefaults.standard.integer(forKey: Self.premiumDaysKey)
        let traffic = UserDefaults.standard.integer(forKey: Self.premiumTrafficKey)
        premiumTrafficGB = traffic > 0 ? traffic : 300
        let used = UserDefaults.standard.integer(forKey: Self.premiumDevicesUsedKey)
        premiumDevicesUsed = used > 0 ? used : 1
        let limit = UserDefaults.standard.integer(forKey: Self.premiumDeviceLimitKey)
        premiumDeviceLimit = limit > 0 ? limit : 5
        activeAccess = Self.loadAccessSource()
    }

    public var isBusy: Bool { phase != .idle }

    public var securityEnabledCount: Int {
        isProtected ? 5 : 0
    }

    public var securityLevelTitle: String {
        isProtected ? "Высокий" : "Низкий"
    }

    public var securityLevelSubtitle: String {
        if isProtected {
            return "VPN активен · трафик защищён"
        }
        return "VPN отключён · защита неактивна"
    }

    public var wifiAccessHint: String {
        switch wifiAccess {
        case .ready:
            return "VPN не будет автоматически включаться в доверенных сетях."
        case .needsPermission, .denied:
            return "Чтобы определить текущую сеть, разрешите доступ к геолокации в Настройках iOS."
        case .unavailable:
            return "Определение Wi‑Fi недоступно на этом устройстве."
        }
    }

    public var subscriptionTrafficText: String {
        if isFreeAccessActive {
            return "\(freeTrafficMB)"
        }
        if case .premium = activeAccess, hasPremiumEntitlement {
            return formatTrafficValue(Double(premiumTrafficGB))
        }
        guard activeSubscriptionID != 0,
              let meta = SubscriptionMetadataStore.load(profileID: activeSubscriptionID)
        else { return "—" }
        return meta.trafficQuotaLabel
    }

    public var subscriptionTrafficUnit: String {
        if isFreeAccessActive {
            return "МБ"
        }
        if case .premium = activeAccess, hasPremiumEntitlement {
            return "ГБ"
        }
        guard activeSubscriptionID != 0,
              let meta = SubscriptionMetadataStore.load(profileID: activeSubscriptionID)
        else { return "" }
        return meta.trafficQuotaUnit
    }

    public var isFreeAccessActive: Bool { activeAccess == .free }

    public var isFreeAccessReady: Bool {
        guard let expires = freeExpiresAt, expires > Date() else { return false }
        return freeTrafficMB > 0
    }

    public var isPremiumAccessReady: Bool {
        hasPremiumEntitlement && premiumRemainingDays > 0 && premiumTrafficGB > 0
    }

    public var isExternalAccessReady: Bool {
        guard case let .imported(id) = activeAccess else { return false }
        guard subscriptions.contains(where: { $0.id == id }) else { return false }
        return activeSubscriptionID == id
    }

    public var isActiveAccessReady: Bool {
        switch activeAccess {
        case .free: return isFreeAccessReady
        case .premium: return isPremiumAccessReady
        case .imported: return isExternalAccessReady
        }
    }

    public var shouldShowAccessChoiceOnConnect: Bool { !isActiveAccessReady }

    public var freeRemainingMinutes: Int {
        guard let expires = freeExpiresAt, expires > Date() else { return 0 }
        return max(1, Int(ceil(expires.timeIntervalSinceNow / 60)))
    }

    public var freeRemainingDisplayText: String {
        let minutes = freeRemainingMinutes
        guard minutes > 0 else { return "0 мин" }
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder > 0 ? "\(hours) ч \(remainder) мин" : "\(hours) ч"
        }
        return "\(minutes) мин"
    }

    public var freeHoursText: String { freeRemainingDisplayText }
    public var freeTrafficText: String { "\(freeTrafficMB) МБ" }

    public var freeProfileID: Int64? {
        subscriptions.first(where: { DirectBuiltinProfile.kind(for: $0.profile.remoteURL) == .free })?.id
    }

    public var premiumProfileID: Int64? {
        subscriptions.first(where: { DirectBuiltinProfile.kind(for: $0.profile.remoteURL) == .premium })?.id
    }

    public var importedSubscriptions: [VPNSubscriptionItem] {
        subscriptions.filter { !DirectBuiltinProfile.isBuiltin($0.profile.remoteURL) }
    }

    public var freeSubscription: VPNSubscriptionItem? {
        subscriptions.first(where: { DirectBuiltinProfile.kind(for: $0.profile.remoteURL) == .free })
    }

    public var premiumSubscription: VPNSubscriptionItem? {
        subscriptions.first(where: { DirectBuiltinProfile.kind(for: $0.profile.remoteURL) == .premium })
    }

    public func isSubscriptionActive(_ id: Int64) -> Bool {
        switch activeAccess {
        case .free:
            return id == freeProfileID
        case .premium:
            return id == premiumProfileID
        case let .imported(activeID):
            return activeID == id
        }
    }

    public var accessStripTitle: String {
        switch activeAccess {
        case .free:
            return "VPN DIRECT FREE"
        case .premium:
            return hasPremiumEntitlement ? "VPN DIRECT PREMIUM" : "VPN DIRECT PREMIUM"
        case .imported:
            return (activeSubscription?.name ?? "ВНЕШНЯЯ").uppercased()
        }
    }

    public var accessStripDetail: String {
        switch activeAccess {
        case .free:
            return freeRemainingDisplayText
        case .premium:
            if hasPremiumEntitlement {
                return "\(premiumExpiryShortLabel) · \(premiumTrafficGB) ГБ · \(premiumDevicesUsed)/\(premiumDeviceLimit)"
            }
            return "Нет тарифа"
        case .imported:
            let expiry = activeSubscription?.expiry ?? "—"
            let traffic = subscriptionTrafficText
            let unit = subscriptionTrafficUnit
            let trafficPart = unit.isEmpty ? traffic : "\(traffic) \(unit)"
            return "\(expiry) · \(trafficPart)"
        }
    }

    /// Expiry date for premium strip, derived from remaining days.
    public var premiumExpiryShortLabel: String {
        guard hasPremiumEntitlement, premiumRemainingDays > 0 else { return "—" }
        let date = Calendar.current.date(byAdding: .day, value: premiumRemainingDays, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("d MMM yy")
        return formatter.string(from: date)
    }

    public var accessStripActionTitle: String {
        switch activeAccess {
        case .free: return "+1 ЧАС"
        case .premium: return hasPremiumEntitlement ? "УПРАВЛЯТЬ" : "ТАРИФ"
        case .imported: return "ПОДПИСКИ"
        }
    }

    public var isCurrentWifiTrusted: Bool {
        guard let ssid = currentWifiSSID else { return false }
        return trustedWifiSSIDs.contains(where: { $0.caseInsensitiveCompare(ssid) == .orderedSame })
    }

    /// UI protection state: connected with an active subscription.
    public var isProtected: Bool {
        !subscriptions.isEmpty && isConnected
    }

    /// Dial shows ON only when a subscription exists and VPN is connected.
    public var dialIsConnected: Bool { isProtected }

    public var headerPageIndex: Int { selectedTab.rawValue }

    public var usesAutoSelection: Bool { selectedServerID == nil }

    public var activeSubscription: VPNSubscriptionItem? {
        subscriptions.first(where: { $0.id == activeSubscriptionID }) ?? subscriptions.first
    }

    public var activeServer: VPNServer? {
        guard let sub = activeSubscription else { return nil }
        if let selectedServerID,
           let selected = sub.servers.first(where: { $0.id == selectedServerID })
        {
            return selected
        }
        if let assignedServerID,
           let assigned = sub.servers.first(where: { $0.id == assignedServerID })
        {
            return assigned
        }
        return sub.servers.first
    }

    public var statusTitle: String {
        switch phase {
        case .connecting: "Подключение"
        case .disconnecting: "Отключение"
        case .switching: "Переподключение"
        case .idle: isProtected ? "Защищено" : "Отключено"
        }
    }

    public var statusSubtitle: String {
        switch phase {
        case .switching: "Переключаем маршрут без потери защиты"
        case .connecting, .disconnecting: "Устанавливаем защищённый канал"
        case .idle: isProtected ? "Трафик зашифрован и скрыт" : "Соединение не защищено"
        }
    }

    public func clearRecentHistory() {
        recentServerIDs = []
        UserDefaults.standard.removeObject(forKey: Self.recentKey)
    }

    public func select(tab: AppTab) {
        selectedTab = tab
        detailPage = nil
        isMenuOpen = false
        HapticManager.shared.play(.navigation)
    }

    public func openDetail(_ page: DetailPage) {
        detailPage = page
    }

    public func openAccessStripAction() {
        switch activeAccess {
        case .free:
            openDetail(.freeAccess)
        case .premium:
            openDetail(hasPremiumEntitlement ? .addOns : .premiumPlans)
        case .imported:
            select(tab: .subscriptions)
        }
    }

    public func activateFreeAccess() {
        guard let freeID = freeProfileID else {
            openDetail(.freeAccess)
            return
        }
        guard !isSubscriptionActive(freeID) else { return }
        setActiveAccess(.free)
        activate(subscriptionID: freeID)
    }

    public func clearAccessChoiceContext() {
        accessChoiceContext = nil
    }

    public func handleAccessChoiceFree() {
        if isFreeAccessReady {
            guard let freeID = freeProfileID else {
                detailPage = .freeAccess
                return
            }
            setActiveAccess(.free)
            if activeSubscriptionID != freeID {
                activate(subscriptionID: freeID)
            }
            detailPage = nil
            Task { await connectAfterAccessChoice() }
        } else {
            detailPage = .freeAccess
        }
    }

    public func handleAccessChoicePremium() {
        if isPremiumAccessReady {
            guard let premiumID = premiumProfileID else {
                detailPage = .premiumPlans
                return
            }
            setActiveAccess(.premium)
            if activeSubscriptionID != premiumID {
                activate(subscriptionID: premiumID)
            }
            detailPage = nil
            Task { await connectAfterAccessChoice() }
        } else if !hasPremiumEntitlement {
            detailPage = .premiumPlans
        } else {
            detailPage = .addOns
        }
    }

    public func handleAccessChoicePickSubscription() {
        selectedTab = .subscriptions
        detailPage = nil
    }

    public func handleAccessChoiceAddURL() {
        importFromAccessChoice = true
        isMenuOpen = true
    }

    public func handleImportedProfileActivated(subscriptionID: Int64) {
        importFromAccessChoice = false
        setActiveAccess(.imported(subscriptionID))
        activate(subscriptionID: subscriptionID)
        detailPage = nil
        Task { await connectAfterAccessChoice() }
    }

    private func connectAfterAccessChoice() async {
        try? await Task.sleep(nanoseconds: 400_000_000)
        skipAccessChoiceGate = true
        defer { skipAccessChoiceGate = false }
        await toggleConnectionAsync()
    }

    private func presentAccessChoice(reason: String?) {
        if let reason {
            accessChoiceContext = reason
        }
        detailPage = .accessChoice
    }

    private func entitlementExpiredMessage() -> String {
        switch activeAccess {
        case .free:
            return "Срок бесплатного доступа истёк или закончился трафик."
        case .premium:
            return "Срок Premium истёк или закончился трафик."
        case .imported:
            return "Подписка недоступна."
        }
    }

    private func evaluateAccessEntitlements() {
        guard isConnected || isStarting || phase == .connecting else { return }
        guard isActiveAccessReady else {
            guard !entitlementDisconnectInFlight else { return }
            entitlementDisconnectInFlight = true
            accessChoiceContext = entitlementExpiredMessage()
            Task {
                await disconnectDueToExpiredEntitlement()
                entitlementDisconnectInFlight = false
            }
            return
        }
    }

    private func disconnectDueToExpiredEntitlement() async {
        connectAttemptID &+= 1
        connectTimeoutTask?.cancel()
        connectPollTask?.cancel()
        isStarting = false
        connectTimeoutExtended = false
        if let profile = environments?.extensionProfile {
            HapticManager.shared.play(.vpnDisconnecting)
            phase = .disconnecting
            try? await profile.stop()
        }
        phase = .idle
        syncFromExtension()
    }

    private func syncFreeHoursFromExpiry() {
        guard let expires = freeExpiresAt else { return }
        let remaining = expires.timeIntervalSinceNow
        if remaining <= 0 {
            if freeHours != 0 {
                freeHours = 0
                UserDefaults.standard.set(0, forKey: Self.freeHoursKey)
            }
        } else {
            let hours = max(1, Int(ceil(remaining / 3600)))
            if hours != freeHours {
                freeHours = hours
                UserDefaults.standard.set(freeHours, forKey: Self.freeHoursKey)
            }
        }
    }

    public func completeRewardPack() {
        let now = Date()
        let base = max(now, freeExpiresAt ?? now)
        freeExpiresAt = base.addingTimeInterval(3600)
        freeHours = max(freeHours, Int(ceil(freeExpiresAt!.timeIntervalSince(now) / 3600)))
        freeTrafficMB += 200
        watchedAds = 0
        persistFreeBalance()
        HapticManager.shared.play(.rewardGranted)
    }

    /// Returns `true` when a full 3-ad pack was completed and balance was credited.
    @discardableResult
    public func watchNextAd() -> Bool {
        watchedAds = min(watchedAds + 1, 3)
        UserDefaults.standard.set(watchedAds, forKey: Self.watchedAdsKey)
        if watchedAds >= 3 {
            completeRewardPack()
            return true
        }
        return false
    }

    public func selectPlan(months: Int, price: Int) {
        selectedPlanMonths = months
        selectedPlanPrice = price
        checkoutTitle = months == 1
            ? "1 месяц Premium"
            : (months == 2 || months == 3 ? "\(months) месяца Premium" : "\(months) месяцев Premium")
        checkoutPrice = price
        pendingAddOnTrafficGB = 0
        pendingAddOnDevice = false
        pendingAddOnDay = false
        HapticManager.shared.play(.selection)
    }

    public func prepareAddOnsCheckout(trafficGB: Int, device: Bool, day: Bool, price: Int) {
        pendingAddOnTrafficGB = trafficGB
        pendingAddOnDevice = device
        pendingAddOnDay = day
        checkoutTitle = "Дополнительные ресурсы"
        checkoutPrice = price
        checkoutReturnPage = .addOns
    }

    public func completeCheckout() {
        if checkoutReturnPage == .addOns {
            if pendingAddOnTrafficGB > 0 {
                premiumTrafficGB += pendingAddOnTrafficGB
            }
            if pendingAddOnDevice {
                premiumDeviceLimit += 1
            }
            if pendingAddOnDay {
                premiumRemainingDays += 1
            }
            pendingAddOnTrafficGB = 0
            pendingAddOnDevice = false
            pendingAddOnDay = false
            hasPremiumEntitlement = true
        } else {
            hasPremiumEntitlement = true
            premiumRemainingDays += selectedPlanMonths * 30
            if premiumTrafficGB < 300 { premiumTrafficGB = 300 }
            if premiumDeviceLimit < 5 { premiumDeviceLimit = 5 }
        }
        persistPremiumState()
        setActiveAccess(.premium)
        if let premiumID = premiumProfileID {
            activate(subscriptionID: premiumID)
        }
        selectedTab = .subscriptions
        detailPage = nil
        HapticManager.shared.play(.purchaseCompleted)
    }

    private func setActiveAccess(_ source: AccessSource) {
        activeAccess = source
        Self.saveAccessSource(source)
    }

    private func persistFreeBalance() {
        UserDefaults.standard.set(freeHours, forKey: Self.freeHoursKey)
        UserDefaults.standard.set(freeTrafficMB, forKey: Self.freeTrafficKey)
        UserDefaults.standard.set(watchedAds, forKey: Self.watchedAdsKey)
        if let expires = freeExpiresAt {
            UserDefaults.standard.set(expires.timeIntervalSince1970, forKey: Self.freeExpiresAtKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.freeExpiresAtKey)
        }
    }

    private func persistPremiumState() {
        UserDefaults.standard.set(hasPremiumEntitlement, forKey: Self.premiumEntitlementKey)
        UserDefaults.standard.set(premiumRemainingDays, forKey: Self.premiumDaysKey)
        UserDefaults.standard.set(premiumTrafficGB, forKey: Self.premiumTrafficKey)
        UserDefaults.standard.set(premiumDevicesUsed, forKey: Self.premiumDevicesUsedKey)
        UserDefaults.standard.set(premiumDeviceLimit, forKey: Self.premiumDeviceLimitKey)
    }

    private static func loadAccessSource() -> AccessSource {
        let raw = UserDefaults.standard.string(forKey: accessSourceKey) ?? "free"
        if raw == "free" { return .free }
        if raw == "premium" { return .premium }
        if raw.hasPrefix("imported:"), let id = Int64(raw.dropFirst("imported:".count)) {
            return .imported(id)
        }
        return .free
    }

    private static func saveAccessSource(_ source: AccessSource) {
        switch source {
        case .free:
            UserDefaults.standard.set("free", forKey: accessSourceKey)
        case .premium:
            UserDefaults.standard.set("premium", forKey: accessSourceKey)
        case let .imported(id):
            UserDefaults.standard.set("imported:\(id)", forKey: accessSourceKey)
        }
    }

    private func formatTrafficValue(_ value: Double) -> String {
        value.rounded() == value
            ? String(Int(value))
            : String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }

    private func ensureBuiltinProfiles() async {
        let profiles = (try? await ProfileManager.list()) ?? []
        let hasFree = profiles.contains { $0.remoteURL == DirectBuiltinProfile.freeURL }
        let hasPremium = profiles.contains { $0.remoteURL == DirectBuiltinProfile.premiumURL }
        if hasFree, hasPremium {
            UserDefaults.standard.set(true, forKey: Self.builtinsSeededKey)
            return
        }
        if !hasFree {
            try? await createBuiltinProfile(
                name: DirectBuiltinProfile.freeName,
                remoteURL: DirectBuiltinProfile.freeURL
            )
        }
        if !hasPremium {
            try? await createBuiltinProfile(
                name: DirectBuiltinProfile.premiumName,
                remoteURL: DirectBuiltinProfile.premiumURL
            )
        }
        UserDefaults.standard.set(true, forKey: Self.builtinsSeededKey)
    }

    private func createBuiltinProfile(name: String, remoteURL: String) async throws {
        let nextProfileID = try await ProfileManager.nextID()
        let profileConfigDirectory = FilePath.sharedDirectory.appendingPathComponent("configs", isDirectory: true)
        let profileConfig = profileConfigDirectory.appendingPathComponent("config_\(nextProfileID).json")
        let stub = """
        {
          "log": { "level": "info" },
          "inbounds": [],
          "outbounds": [
            { "type": "direct", "tag": "direct" }
          ]
        }
        """
        try await BlockingIO.run {
            try FileManager.default.createDirectory(at: profileConfigDirectory, withIntermediateDirectories: true)
            try stub.write(to: profileConfig, atomically: true, encoding: .utf8)
        }
        let profile = Profile(
            name: name,
            type: .local,
            path: profileConfig.relativePath,
            remoteURL: remoteURL,
            autoUpdate: false,
            autoUpdateInterval: 0,
            lastUpdated: Date()
        )
        try await ProfileManager.create(profile)
    }

    public func toggleFavorite(serverID: String) {
        if favoriteServerIDs.contains(serverID) {
            favoriteServerIDs.remove(serverID)
        } else {
            favoriteServerIDs.insert(serverID)
        }
        UserDefaults.standard.set(Array(favoriteServerIDs), forKey: Self.favoritesKey)
    }

    public func favoriteServers(for subscription: VPNSubscriptionItem?) -> [VPNServer] {
        guard let subscription else { return [] }
        return subscription.servers.filter { favoriteServerIDs.contains($0.id) }
    }

    public func recentServers(for subscription: VPNSubscriptionItem?) -> [VPNServer] {
        guard let subscription else { return [] }
        return recentServerIDs.compactMap { id in
            subscription.servers.first(where: { $0.id == id })
        }
    }

    private func rememberRecentServer(_ serverID: String?) {
        guard let serverID, !serverID.isEmpty else { return }
        recentServerIDs.removeAll(where: { $0 == serverID })
        recentServerIDs.insert(serverID, at: 0)
        recentServerIDs = Array(recentServerIDs.prefix(12))
        UserDefaults.standard.set(recentServerIDs, forKey: Self.recentKey)
    }

    public func setConnectionMode(_ mode: String) {
        connectionMode = mode
        Task {
            await SharedPreferences.connectionMode.set(mode)
            if isConnected {
                phase = .switching
                HapticManager.shared.play(.vpnSwitching)
            }
            await applyConnectionModeBehavior(force: true)
            if isConnected {
                try? await Task.sleep(nanoseconds: 700_000_000)
                phase = .idle
                HapticManager.shared.play(.vpnSwitched)
            }
        }
    }

    public func refreshCurrentWifi() async {
        wifiAccess = await DirectWiFiMonitor.accessStatus()
        currentWifiSSID = await DirectWiFiMonitor.currentSSID()
    }

    public func toggleTrustedCurrentWifi() {
        guard let ssid = currentWifiSSID, !ssid.isEmpty else { return }
        if isCurrentWifiTrusted {
            removeTrustedWifi(ssid)
        } else {
            addTrustedWifi(ssid)
        }
    }

    /// Refresh SSID first, then toggle. Returns false if SSID could not be read.
    public func toggleTrustedCurrentWifiAfterRefresh() async -> Bool {
        await refreshCurrentWifi()
        guard let ssid = currentWifiSSID, !ssid.isEmpty else { return false }
        toggleTrustedCurrentWifi()
        return true
    }

    public func loadSecuritySettings() async {
        // Kill Switch is permanently off — never restore includeAllNetworks from prefs.
        await SharedPreferences.includeAllNetworks.set(false)
        let alwaysOn = await SharedPreferences.alwaysOn.get()
        let onDemandEnabled = await SharedPreferences.onDemandEnabled.get()
        autoConnect = alwaysOn || onDemandEnabled
        unknownWiFi = await SharedPreferences.unknownWifiConnect.get()
        secureDNS = await SharedPreferences.enforceRoutes.get()
        localNetwork = await SharedPreferences.excludeLocalNetworks.get()
        faceIDLock = await SharedPreferences.appLockEnabled.get()
        autoFailover = await SharedPreferences.autoFailover.get()
        bypassRussianSites = await SharedPreferences.bypassRussianSites.get()
        trustedWifiSSIDs = await SharedPreferences.trustedWifiSSIDs.get()
        connectionMode = await SharedPreferences.connectionMode.get()
    }

    public func setAutoConnect(_ enabled: Bool) {
        autoConnect = enabled
        Task { await applySecuritySettings() }
    }

    public func setUnknownWiFi(_ enabled: Bool) {
        unknownWiFi = enabled
        Task {
            await SharedPreferences.unknownWifiConnect.set(enabled)
            await applySecuritySettings()
        }
    }

    public func setSecureDNS(_ enabled: Bool) {
        secureDNS = enabled
        Task {
            await SharedPreferences.enforceRoutes.set(enabled)
            await applySecuritySettings()
        }
    }

    public func setLocalNetwork(_ enabled: Bool) {
        localNetwork = enabled
        Task {
            await SharedPreferences.excludeLocalNetworks.set(enabled)
            await applySecuritySettings()
        }
    }

    public func setFaceIDLock(_ enabled: Bool) {
        faceIDLock = enabled
        Task { await SharedPreferences.appLockEnabled.set(enabled) }
    }

    public func setAutoFailover(_ enabled: Bool) {
        autoFailover = enabled
        Task { await SharedPreferences.autoFailover.set(enabled) }
    }

    public func setBypassRussianSites(_ enabled: Bool) {
        bypassRussianSites = enabled
        Task {
            await SharedPreferences.bypassRussianSites.set(enabled)
            // Re-apply route rules in the running tunnel (or next connect).
            if isConnected || isProtected {
                try? await environments?.extensionProfile?.reloadService()
            }
        }
    }

    public func addTrustedWifi(_ ssid: String) {
        let trimmed = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !trustedWifiSSIDs.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        trustedWifiSSIDs.append(trimmed)
        Task {
            await SharedPreferences.trustedWifiSSIDs.set(trustedWifiSSIDs)
            await applySecuritySettings()
        }
    }

    public func removeTrustedWifi(_ ssid: String) {
        trustedWifiSSIDs.removeAll(where: { $0.caseInsensitiveCompare(ssid) == .orderedSame })
        Task {
            await SharedPreferences.trustedWifiSSIDs.set(trustedWifiSSIDs)
            await applySecuritySettings()
        }
    }

    public func shareSubscription(subscriptionID: Int64) {
        guard let url = shareURL(for: subscriptionID) else { return }
        DirectSharePresenter.share([url])
    }

    public func applySecuritySettings() async {
        // Kill Switch permanently disabled — never write includeAllNetworks = true.
        await SharedPreferences.includeAllNetworks.set(false)
        await SharedPreferences.enforceRoutes.set(secureDNS)
        await SharedPreferences.excludeLocalNetworks.set(localNetwork)
        await SharedPreferences.unknownWifiConnect.set(unknownWiFi)

        let enableOnDemand = autoConnect && (unknownWiFi || !trustedWifiSSIDs.isEmpty)
        let enableAlwaysOn = autoConnect && trustedWifiSSIDs.isEmpty && !unknownWiFi
        await SharedPreferences.alwaysOn.set(enableAlwaysOn)
        await SharedPreferences.onDemandEnabled.set(enableOnDemand)

        if enableOnDemand {
            var rules: [OnDemandRule] = trustedWifiSSIDs.map {
                OnDemandRule(action: .disconnect, interfaceType: .wifi, ssidMatch: [$0])
            }
            if unknownWiFi {
                rules.append(OnDemandRule(action: .connect, interfaceType: .wifi))
            }
            rules.append(OnDemandRule(action: .connect, interfaceType: .cellular))
            await SharedPreferences.onDemandRules.set(rules)
        } else {
            await SharedPreferences.onDemandRules.set([])
            await SharedPreferences.alwaysOn.set(false)
            await SharedPreferences.onDemandEnabled.set(false)
        }

        guard let profile = environments?.extensionProfile else { return }
        let useDefault = enableAlwaysOn
        try? await profile.updateOnDemand(enabled: enableOnDemand || enableAlwaysOn, useDefaultRules: useDefault)
    }

    public func refreshSubscription(subscriptionID: Int64) {
        Task {
            do {
                guard let profile = try await ProfileManager.get(subscriptionID) else { return }
                try await profile.updateRemoteProfile()
                environments?.profileUpdate.send()
                await reloadSubscriptions()
            } catch {
                alert = AlertState(action: "обновить подписку", error: error)
            }
        }
    }

    public func renameSubscription(subscriptionID: Int64, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            do {
                guard let profile = try await ProfileManager.get(subscriptionID) else { return }
                await MainActor.run { profile.name = trimmed }
                try await ProfileManager.update(profile)
                environments?.profileUpdate.send()
                await reloadSubscriptions()
            } catch {
                alert = AlertState(action: "переименовать подписку", error: error)
            }
        }
    }

    public func deleteSubscription(subscriptionID: Int64) {
        Task {
            do {
                guard let profile = try await ProfileManager.get(subscriptionID) else { return }
                if DirectBuiltinProfile.isBuiltin(profile.remoteURL) {
                    alert = AlertState(errorMessage: String(localized: "Встроенные подписки VPN Direct нельзя удалить."))
                    return
                }
                if activeSubscriptionID == subscriptionID {
                    activeSubscriptionID = 0
                    selectedServerID = nil
                }
                try await ProfileManager.delete(profile)
                if detailPage == .subscription(subscriptionID) {
                    detailPage = nil
                }
                if case let .imported(id) = activeAccess, id == subscriptionID {
                    setActiveAccess(.free)
                }
                environments?.profileUpdate.send()
                environments?.postReload()
                await reloadSubscriptions()
                if subscriptions.isEmpty {
                    await disableVPNAutoConnect()
                }
            } catch {
                alert = AlertState(action: "удалить подписку", error: error)
            }
        }
    }

    public func shareURL(for subscriptionID: Int64) -> URL? {
        guard let item = subscriptions.first(where: { $0.id == subscriptionID }),
              item.profile.type == .remote,
              let url = item.profile.remoteURL,
              !url.isEmpty
        else { return nil }
        return URL(string: url)
    }

    public func copySubscriptionURL(subscriptionID: Int64) {
        guard let url = shareURL(for: subscriptionID)?.absoluteString else { return }
        UIPasteboard.general.string = url
    }

    public func runRecoveryDemo() {
        Task {
            guard isConnected, let groupTag = activeServer?.groupTag ?? activeSubscription?.servers.first?.groupTag else { return }
            HapticManager.shared.play(.vpnSwitching)
            try? await LibboxNewStandaloneCommandClient()!.urlTest(groupTag)
            try? await Task.sleep(nanoseconds: 600_000_000)
            await mergeLivePings()
            if autoFailover, let servers = activeSubscription?.servers.sorted(by: { $0.ping > 0 && ($1.ping == 0 || $0.ping < $1.ping) }),
               let best = servers.first(where: { $0.ping > 0 })
            {
                try? await LibboxNewStandaloneCommandClient()!.selectOutbound(best.groupTag, outboundTag: best.id)
                assignedServerID = best.id
                selectedServerID = best.id
                await SharedPreferences.preferredOutboundTag.set(best.id)
            }
            HapticManager.shared.play(.vpnSwitched)
        }
    }

    private func applyConnectionModeBehavior(force: Bool = false) async {
        guard let servers = activeSubscription?.servers, !servers.isEmpty else { return }
        let groupTag = activeServer?.groupTag ?? servers.first!.groupTag

        switch connectionMode {
        case "Авто":
            selectedServerID = nil
            await SharedPreferences.preferredOutboundTag.set("")
            guard isConnected else { return }
            try? await LibboxNewStandaloneCommandClient()!.selectOutbound(groupTag, outboundTag: "auto")
            // Don't block UI — balancer probes in the background.
            Task {
                try? await LibboxNewStandaloneCommandClient()!.urlTest("auto")
                try? await Task.sleep(nanoseconds: 400_000_000)
                await refreshAssignedFromGroups()
                await mergeLivePings()
            }
        case "Максимальная скорость":
            await pickAndApplyServer(
                groupTag: groupTag,
                manualSelection: true,
                chooser: { $0.filter { $0.ping > 0 }.min(by: { $0.ping < $1.ping }) ?? $0.first }
            )
        case "Стабильный":
            let sticky = assignedServerID ?? selectedServerID ?? servers.first?.id
            if let sticky, let server = servers.first(where: { $0.id == sticky }) {
                await commitServerPick(server, manualSelection: true)
            }
        case "Для видео":
            await pickAndApplyServer(
                groupTag: groupTag,
                manualSelection: true,
                chooser: { list in
                    let stable = list.filter { $0.ping >= 40 && $0.ping <= 180 }
                    return stable.min(by: { $0.load < $1.load })
                        ?? list.filter { $0.ping > 0 }.min(by: { $0.ping < $1.ping })
                        ?? list.first
                }
            )
        case "Антиблокировка":
            await pickAndApplyServer(
                groupTag: groupTag,
                manualSelection: true,
                chooser: { [assignedServerID, selectedServerID] list in
                    let sorted = list.filter { $0.ping > 0 }.sorted(by: { $0.ping < $1.ping })
                    let current = assignedServerID ?? selectedServerID
                    return sorted.first(where: { $0.id != current }) ?? sorted.first ?? list.first
                }
            )
        default:
            if force { break }
        }
    }

    private func pickAndApplyServer(
        groupTag: String,
        manualSelection: Bool,
        chooser: @escaping ([VPNServer]) -> VPNServer?
    ) async {
        let servers = activeSubscription?.servers ?? []
        // Prefer cached pings for instant switch; refresh in background.
        if let pick = chooser(servers) {
            await commitServerPick(pick, manualSelection: manualSelection)
        }
        guard isConnected else { return }
        Task {
            try? await LibboxNewStandaloneCommandClient()!.urlTest(groupTag)
            try? await Task.sleep(nanoseconds: 400_000_000)
            await mergeLivePings()
            let refreshed = activeSubscription?.servers ?? []
            if let pick = chooser(refreshed) {
                await commitServerPick(pick, manualSelection: manualSelection)
            }
        }
    }

    private func commitServerPick(_ server: VPNServer, manualSelection: Bool) async {
        if manualSelection {
            selectedServerID = server.id
            assignedServerID = server.id
            await SharedPreferences.preferredOutboundTag.set(server.id)
        } else {
            selectedServerID = nil
            assignedServerID = server.id
            await SharedPreferences.preferredOutboundTag.set("")
        }
        guard isConnected else { return }
        try? await LibboxNewStandaloneCommandClient()!.selectOutbound(server.groupTag, outboundTag: server.id)
    }

    public func bind(_ environments: ExtensionEnvironments) {
        self.environments = environments
        syncFromExtension()
        guard !didBind else { return }
        didBind = true
        Task {
            // One-time cleanup from older kill-switch builds — never block later opens.
            await SharedPreferences.includeAllNetworks.set(false)
            await ExtensionProfile.disableAllSavedProfiles()
            await SingBoxConfigMigrator.migrateAllStoredProfiles()
            await loadSecuritySettings()
            autoConnect = false
            unknownWiFi = false
            await SharedPreferences.alwaysOn.set(false)
            await SharedPreferences.onDemandEnabled.set(false)
            await refreshCurrentWifi()
            let stored = await SharedPreferences.preferredOutboundTag.get()
            selectedServerID = stored.isEmpty ? nil : stored
            connectionMode = await SharedPreferences.connectionMode.get()
            await reloadSubscriptions()
            try? await environments.ensureExtensionProfileReady()
            await applySecuritySettings()
            await migrateUrlTestBalancerIfNeeded()
        }
        startTicker()
    }

    public func syncFromExtension() {
        // Always read live NE status — cached @Published can lag behind the system VPN.
        let wasConnected = isConnected
        let wasPhase = phase
        environments?.extensionProfile?.refreshStatus()
        guard let status = environments?.extensionProfile?.status else {
            if phase == .idle {
                isConnected = false
            }
            return
        }
        switch status {
        case .connecting:
            if phase == .idle { phase = .connecting }
            isConnected = false
        case .connected, .reasserting:
            connectTimeoutTask?.cancel()
            connectTimeoutTask = nil
            connectPollTask?.cancel()
            connectPollTask = nil
            isStarting = false
            isConnected = true
            let shouldApplyMode = phase == .connecting
            phase = .idle
            alert = nil
            environments?.commandClient.connect()
            Task {
                resetSessionTrafficBaseline()
                await refreshAssignedFromGroups()
                if shouldApplyMode {
                    await applyConnectionModeBehavior(force: true)
                }
            }
        case .disconnecting:
            if phase == .idle { phase = .disconnecting }
            isConnected = true
        case .disconnected:
            persistSessionTrafficDelta()
            sessionTrafficBaseline = 0
            lastSessionTrafficTotal = 0
            if isStarting || phase == .connecting {
                // Stay in connecting UI — live status will flip; timeout handles failure.
                break
            } else if phase != .switching {
                isConnected = false
                phase = .idle
            }
        default:
            if phase == .idle {
                isConnected = false
            }
        }
        updateRuntime()
        updateTraffic()

        if isConnected, !wasConnected {
            HapticManager.shared.play(.vpnConnected)
        } else if !isConnected, wasConnected, wasPhase != .switching, !isStarting,
                  environments?.extensionProfile?.status == .disconnected
        {
            HapticManager.shared.play(.vpnDisconnected)
        }
    }

    public func reloadSubscriptions() async {
        do {
            await ensureBuiltinProfiles()
            let profiles = try await ProfileManager.list().map { ProfilePreview($0) }
            environments?.emptyProfiles = profiles.isEmpty
            var items: [VPNSubscriptionItem] = []
            for (index, profile) in profiles.enumerated() {
                let servers: [VPNServer]
                do {
                    let json = try await profile.origin.readAsync()
                    servers = VPNServerNameParser.servers(fromJSON: json)
                } catch {
                    servers = []
                }
                let builtinKind = DirectBuiltinProfile.kind(for: profile.remoteURL)
                let source: String
                if builtinKind == .free {
                    source = "VPN DIRECT FREE"
                } else if builtinKind == .premium {
                    source = "VPN DIRECT PREMIUM"
                } else {
                    switch profile.type {
                    case .remote: source = index == 0 ? "ОСНОВНАЯ" : "УДАЛЁННАЯ"
                    case .local: source = "ДОБАВЛЕНА ВРУЧНУЮ"
                    case .icloud: source = "ICLOUD"
                    }
                }
                let updated: String
                if let date = profile.lastUpdated {
                    let formatter = RelativeDateTimeFormatter()
                    formatter.locale = Locale(identifier: "ru_RU")
                    formatter.unitsStyle = .short
                    updated = "обновлена \(formatter.localizedString(for: date, relativeTo: Date()))"
                } else {
                    updated = "ожидает обновления"
                }

                // Local cache only — never hit the network on screen open / tab switch.
                let meta = SubscriptionMetadataStore.load(profileID: profile.id) ?? SubscriptionMetadata()
                var displayName = Self.resolvedSubscriptionName(profile: profile, metadata: meta)
                var expiry = meta.shortExpiryLabel
                var devices = meta.devicesLabel
                if builtinKind == .free {
                    displayName = DirectBuiltinProfile.freeName
                    expiry = isFreeAccessReady ? freeRemainingDisplayText : "НЕТ"
                    devices = "1 / 1"
                } else if builtinKind == .premium {
                    displayName = DirectBuiltinProfile.premiumName
                    expiry = hasPremiumEntitlement ? "\(premiumRemainingDays) ДН" : "НЕТ"
                    devices = "\(premiumDevicesUsed) / \(premiumDeviceLimit)"
                }
                if displayName != profile.name,
                   SubscriptionMetadata.isEncodedProfileTitle(profile.name)
                    || SubscriptionConfigBuilder.isHostLikeName(profile.name)
                    || profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    let origin = profile.origin
                    await MainActor.run { origin.name = displayName }
                    try? await ProfileManager.update(origin)
                }

                items.append(
                    VPNSubscriptionItem(
                        profile: profile,
                        servers: servers,
                        source: source,
                        updated: updated,
                        expiry: expiry,
                        devices: devices,
                        displayName: displayName
                    )
                )
            }
            // Stable order: Free, Premium, then imports.
            items.sort { lhs, rhs in
                let lRank = Self.builtinSortRank(lhs.profile.remoteURL)
                let rRank = Self.builtinSortRank(rhs.profile.remoteURL)
                if lRank != rRank { return lRank < rRank }
                return lhs.id < rhs.id
            }
            subscriptions = items
            let selected = await SharedPreferences.selectedProfileID.get()
            if items.contains(where: { $0.id == selected }) {
                activeSubscriptionID = selected
            } else if let first = items.first {
                activeSubscriptionID = first.id
                await SharedPreferences.selectedProfileID.set(first.id)
            } else {
                activeSubscriptionID = 0
                await SharedPreferences.selectedProfileID.set(-1)
                await disableVPNAutoConnect()
            }
            await mergeLivePings()
        } catch {
            alert = AlertState(action: "load subscriptions", error: error)
        }
    }

    private static func builtinSortRank(_ remoteURL: String?) -> Int {
        switch DirectBuiltinProfile.kind(for: remoteURL) {
        case .free: return 0
        case .premium: return 1
        default: return 2
        }
    }

    /// One-shot background rebuild so Auto mode gets a native urltest balancer.
    private func migrateUrlTestBalancerIfNeeded() async {
        if UserDefaults.standard.bool(forKey: Self.urltestMigratedKey) { return }
        let profiles = (try? await ProfileManager.list()) ?? []
        var changed = false
        for profile in profiles where profile.type == .remote {
            guard let remoteURL = profile.remoteURL, !remoteURL.isEmpty else { continue }
            let json = (try? await profile.readAsync()) ?? ""
            if json.contains("\"type\" : \"urltest\"") || json.contains("\"type\":\"urltest\"") {
                continue
            }
            try? await profile.updateRemoteProfile()
            changed = true
        }
        UserDefaults.standard.set(true, forKey: Self.urltestMigratedKey)
        if changed {
            await reloadSubscriptions()
        }
    }

    private static func resolvedSubscriptionName(profile: ProfilePreview, metadata: SubscriptionMetadata) -> String {
        if let title = SubscriptionMetadata.sanitizedTitle(metadata.title) {
            return title
        }
        if let decoded = SubscriptionMetadata.sanitizedTitle(profile.name),
           decoded != profile.name || !SubscriptionMetadata.isEncodedProfileTitle(profile.name)
        {
            return decoded
        }
        return profile.name
    }

    public func activate(subscriptionID: Int64) {
        Task {
            // Broken / limited subscriptions can leave the UI stuck in "connecting".
            // Always allow switching away so the user can recover.
            if phase == .connecting || phase == .disconnecting || (isBusy && !isConnected) {
                await cancelPendingConnection(showError: false)
            } else if isBusy {
                return
            }

            let item = subscriptions.first(where: { $0.id == subscriptionID })
            if let kind = DirectBuiltinProfile.kind(for: item?.profile.remoteURL) {
                setActiveAccess(kind)
            } else {
                setActiveAccess(.imported(subscriptionID))
            }

            let sameProfile = subscriptionID == activeSubscriptionID
            if sameProfile {
                return
            }

            activeSubscriptionID = subscriptionID
            selectedServerID = nil
            assignedServerID = nil
            HapticManager.shared.play(.selection)
            await SharedPreferences.selectedProfileID.set(subscriptionID)
            await SharedPreferences.preferredOutboundTag.set("")
            environments?.selectedProfileUpdate.send()
            try? await environments?.ensureExtensionProfileReady()
            if isConnected, let profile = environments?.extensionProfile {
                phase = .switching
                HapticManager.shared.play(.vpnSwitching)
                do {
                    try await profile.reloadService()
                    try? await Task.sleep(nanoseconds: 850_000_000)
                    phase = .idle
                    HapticManager.shared.play(.vpnSwitched)
                    await refreshAssignedFromGroups()
                } catch {
                    phase = .idle
                    isConnected = false
                    alert = AlertState(
                        errorMessage: String(localized: "Не удалось переключить подписку. Выберите другую или обновите конфигурацию.")
                    )
                }
            }
            await reloadSubscriptions()
        }
    }

    public func select(serverID: String?) {
        guard serverID != selectedServerID else {
            activeSheet = nil
            return
        }
        selectedServerID = serverID
        rememberRecentServer(serverID)
        activeSheet = nil
        HapticManager.shared.play(.selection)
        Task {
            await SharedPreferences.preferredOutboundTag.set(serverID ?? "")
            guard isConnected else { return }
            phase = .switching
            HapticManager.shared.play(.vpnSwitching)
            do {
                if let serverID, let server = activeSubscription?.servers.first(where: { $0.id == serverID }) {
                    try await LibboxNewStandaloneCommandClient()!.selectOutbound(server.groupTag, outboundTag: serverID)
                    assignedServerID = serverID
                } else {
                    let groupTag = activeSubscription?.servers.first?.groupTag ?? "proxy"
                    // Auto mode: native sing-box urltest balancer.
                    try await LibboxNewStandaloneCommandClient()!.selectOutbound(groupTag, outboundTag: "auto")
                    try? await LibboxNewStandaloneCommandClient()!.urlTest("auto")
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await refreshAssignedFromGroups()
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
                phase = .idle
                HapticManager.shared.play(.vpnSwitched)
                await mergeLivePings()
            } catch {
                phase = .idle
                alert = AlertState(action: "switch server", error: error)
            }
        }
    }

    public func toggleConnection() {
        // Tap during hang/connecting cancels instead of ignoring input.
        if phase == .connecting || phase == .switching {
            Task { await cancelPendingConnection(showError: false) }
            return
        }
        guard phase == .idle else { return }
        Task { await toggleConnectionAsync() }
    }

    public func handleDisconnectSettled() async {
        // Only used for genuine post-connect drops now — never during start.
        if isStarting || phase == .connecting {
            return
        }
        if let status = environments?.extensionProfile?.status {
            switch status {
            case .connected, .reasserting, .connecting:
                syncFromExtension()
                return
            default:
                break
            }
        }
        isConnected = false
        phase = .idle
        syncFromExtension()
    }

    public func requestURLTest() {
        guard isConnected, let groupTag = activeServer?.groupTag ?? activeSubscription?.servers.first?.groupTag else { return }
        Task {
            try? await LibboxNewStandaloneCommandClient()!.urlTest(groupTag)
            try? await Task.sleep(nanoseconds: 500_000_000)
            await mergeLivePings()
        }
    }

    public func updateFromGroups() {
        Task {
            await refreshAssignedFromGroups()
            await mergeLivePings()
        }
    }

    private func toggleConnectionAsync() async {
        guard let environments else { return }
        guard !environments.emptyProfiles else {
            alert = AlertState(errorMessage: String(localized: "Добавьте подписку, чтобы подключить VPN."))
            selectedTab = .subscriptions
            return
        }
        do {
            try await environments.ensureExtensionProfileReady()
        } catch {
            alert = AlertState(action: "prepare vpn profile", error: error)
            return
        }
        guard let profile = environments.extensionProfile else {
            alert = AlertState(errorMessage: String(localized: "VPN-профиль ещё не готов. Подождите секунду."))
            environments.postReload()
            return
        }
        guard profile.status.isEnabled else { return }

        do {
            if profile.status.isConnected {
                persistSessionTrafficDelta()
                connectTimeoutTask?.cancel()
                HapticManager.shared.play(.vpnDisconnecting)
                phase = .disconnecting
                try await profile.stop()
                isStarting = false
                isConnected = false
                phase = .idle
            } else {
                if !skipAccessChoiceGate, shouldShowAccessChoiceOnConnect {
                    presentAccessChoice(reason: nil)
                    return
                }
                await ensureAutoConnectSettings()
                connectAttemptID &+= 1
                connectTimeoutExtended = false
                isStarting = true
                phase = .connecting
                HapticManager.shared.play(.vpnConnecting)
                scheduleConnectTimeout()
                startConnectStatusPolling()
                try await profile.start()
                // Force a live read right after start — notifications can miss the transition.
                profile.refreshStatus()
                syncFromExtension()
            }
        } catch {
            await cancelPendingConnection(showError: true, error: error)
        }
    }

    private func scheduleConnectTimeout() {
        connectTimeoutTask?.cancel()
        let attempt = connectAttemptID
        connectTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 35_000_000_000)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            await self.failConnectIfStillDown(attempt: attempt)
        }
    }

    /// Poll live NE status while starting — notifications alone are unreliable after saveToPreferences.
    private func startConnectStatusPolling() {
        connectPollTask?.cancel()
        let attempt = connectAttemptID
        connectPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard let self else { return }
                guard self.connectAttemptID == attempt else { return }
                guard self.isStarting || self.phase == .connecting else { return }
                self.environments?.extensionProfile?.refreshStatus()
                self.syncFromExtension()
                if self.isConnected || self.phase == .idle, !self.isStarting {
                    return
                }
            }
        }
    }

    private func failConnectIfStillDown(attempt: UInt64) async {
        guard connectAttemptID == attempt else { return }
        guard isStarting || phase == .connecting else { return }

        environments?.extensionProfile?.refreshStatus()
        let status = environments?.extensionProfile?.status
        switch status {
        case .connected, .reasserting:
            syncFromExtension()
            return
        case .connecting:
            if !connectTimeoutExtended {
                connectTimeoutExtended = true
                scheduleConnectTimeout()
                return
            }
        default:
            break
        }

        await cancelPendingConnection(showError: true)
    }

    private func cancelPendingConnection(showError: Bool, error: Error? = nil) async {
        environments?.extensionProfile?.refreshStatus()
        // If the system tunnel already connected, treat as success — don't stop it or alert.
        if let status = environments?.extensionProfile?.status,
           status == .connected || status == .reasserting
        {
            connectTimeoutTask?.cancel()
            connectTimeoutTask = nil
            connectPollTask?.cancel()
            connectPollTask = nil
            isStarting = false
            syncFromExtension()
            return
        }

        connectTimeoutTask?.cancel()
        connectTimeoutTask = nil
        connectPollTask?.cancel()
        connectPollTask = nil
        connectAttemptID &+= 1
        isStarting = false
        isConnected = false
        phase = .idle

        if let profile = environments?.extensionProfile {
            try? await profile.updateOnDemand(enabled: false, useDefaultRules: false)
            profile.refreshStatus()
            if profile.status.isConnected || profile.status == .connecting || profile.status == .reasserting {
                try? await profile.stop()
            }
            let useDefault = autoConnect && trustedWifiSSIDs.isEmpty && !unknownWiFi
            try? await profile.updateOnDemand(enabled: autoConnect, useDefaultRules: useDefault)
        }

        if showError {
            presentAccessChoice(
                reason: error.map { "Не удалось подключиться: \($0.localizedDescription)" }
                    ?? "Не удалось подключиться. Выберите другой способ доступа."
            )
        }
        syncFromExtension()
    }

    private func disableVPNAutoConnect() async {
        autoConnect = false
        await SharedPreferences.alwaysOn.set(false)
        await SharedPreferences.onDemandEnabled.set(false)
        await SharedPreferences.onDemandRules.set([])
        try? await environments?.extensionProfile?.updateOnDemand(enabled: false, useDefaultRules: false)
        if environments?.extensionProfile?.status.isConnected == true {
            try? await environments?.extensionProfile?.stop()
        }
    }

    private func applyRouteIfNeeded() async {
        guard isConnected else { return }
        if let selectedServerID,
           let server = activeSubscription?.servers.first(where: { $0.id == selectedServerID })
        {
            try? await LibboxNewStandaloneCommandClient()!.selectOutbound(server.groupTag, outboundTag: selectedServerID)
            assignedServerID = selectedServerID
        } else {
            await refreshAssignedFromGroups()
        }
    }

    private func refreshAssignedFromGroups() async {
        guard let groups = environments?.commandClient.groups else { return }
        let selectable = groups.filter { $0.selectable }
        guard let group = selectable.first(where: { $0.type == "selector" }) ?? selectable.first else { return }
        if !group.selected.isEmpty {
            assignedServerID = group.selected
        }
    }

    private func mergeLivePings() async {
        guard let groups = environments?.commandClient.groups else { return }
        let selectable = groups.filter { $0.selectable }
        guard let group = selectable.first(where: { $0.type == "selector" }) ?? selectable.first,
              let iterator = group.getItems()
        else { return }

        var delays: [String: Int] = [:]
        while iterator.hasNext() {
            guard let item = iterator.next() else { continue }
            let delay = Int(item.urlTestDelay)
            if delay > 0 { delays[item.tag] = delay }
        }
        guard !delays.isEmpty else { return }

        subscriptions = subscriptions.map { sub in
            let servers = sub.servers.map { server in
                guard let ping = delays[server.id] else { return server }
                let load = min(95, max(18, ping / 2 + (abs(server.id.hashValue) % 40)))
                return VPNServer(
                    id: server.id,
                    city: server.city,
                    country: server.country,
                    countryCode: server.countryCode,
                    ping: ping,
                    load: load,
                    groupTag: server.groupTag
                )
            }
            return VPNSubscriptionItem(
                profile: sub.profile,
                servers: servers,
                source: sub.source,
                updated: sub.updated,
                expiry: sub.expiry,
                devices: sub.devices,
                displayName: sub.name
            )
        }
        if !group.selected.isEmpty {
            assignedServerID = group.selected
        }
    }

    private func ensureAutoConnectSettings() async {
        await applySecuritySettings()
    }

    private func startTicker() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    self?.updateRuntime()
                    self?.syncFreeHoursFromExpiry()
                    self?.evaluateAccessEntitlements()
                    self?.updateTraffic()
                }
            }
        }
    }

    private func updateRuntime() {
        guard isProtected,
              let connectedDate = environments?.extensionProfile?.connectedDate
        else {
            runtimeText = "00:00:00"
            return
        }
        let interval = max(0, Date().timeIntervalSince(connectedDate))
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        runtimeText = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func updateTraffic() {
        let persisted = DailyTrafficStore.storedBytesForToday()

        if isProtected, let status = environments?.commandClient.status {
            let sessionTotal = status.uplinkTotal &+ status.downlinkTotal
            lastSessionTrafficTotal = sessionTotal
            if sessionTrafficBaseline == 0 {
                sessionTrafficBaseline = sessionTotal
            }
            let delta = max(0, sessionTotal - sessionTrafficBaseline)
            trafficText = Self.formatBytes(persisted &+ delta)
            return
        }

        if persisted > 0 {
            trafficText = Self.formatBytes(persisted)
        } else {
            trafficText = "—"
        }
    }

    private func resetSessionTrafficBaseline() {
        if let status = environments?.commandClient.status {
            sessionTrafficBaseline = status.uplinkTotal &+ status.downlinkTotal
            lastSessionTrafficTotal = sessionTrafficBaseline
        } else {
            sessionTrafficBaseline = 0
            lastSessionTrafficTotal = 0
        }
    }

    private func persistSessionTrafficDelta() {
        guard lastSessionTrafficTotal >= sessionTrafficBaseline else { return }
        let delta = lastSessionTrafficTotal - sessionTrafficBaseline
        DailyTrafficStore.addBytes(delta)
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let value = Double(max(0, bytes))
        if value < 1024 { return "0" }
        let mb = value / (1024 * 1024)
        if mb < 1024 {
            return String(format: "%.1f", mb).replacingOccurrences(of: ".", with: ",")
        }
        return String(format: "%.1f", mb / 1024).replacingOccurrences(of: ".", with: ",")
    }

    public var trafficUnit: String {
        let persisted = Double(DailyTrafficStore.storedBytesForToday())
        var total = persisted
        if isProtected, let status = environments?.commandClient.status {
            let sessionTotal = Double(status.uplinkTotal &+ status.downlinkTotal)
            total += Double(max(0, sessionTotal - Double(sessionTrafficBaseline)))
        }
        return total >= 1024 * 1024 * 1024 ? "ГБ" : "МБ"
    }
}

#endif
