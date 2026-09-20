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
    /// Previous detail pages for logical back navigation (not shown in UI).
    private var detailStack: [DetailPage] = []
    @Published public var activeSheet: AppSheet?
    @Published public var connectionMode = "Авто"
    @Published public var isMenuOpen = false
    /// Limited location caps from /me — exhausted stay visible but not selectable.
    @Published public var locationCaps: [DirectLocationCap] = []
    @Published public private(set) var isConnected = false
    @Published public private(set) var phase: ConnectionPhase = .idle
    /// Full-screen Guideline 5.4 disclosure before first VPN connect (all users until accepted).
    @Published public var showPrivacyDisclosure = false
    @Published public var subscriptions: [VPNSubscriptionItem] = []
    @Published public var activeSubscriptionID: Int64 = 0
    /// `nil` means balancer / auto-select for the active subscription.
    @Published public var selectedServerID: String?
    @Published public var runtimeText = "00:00:00"
    @Published public var trafficText = "—"
    @Published public var alert: AlertState?
    /// Public egress IP shown in the connection report (VPN exit when connected, WAN when idle).
    @Published public private(set) var publicIPText = "—"
    @Published public private(set) var publicIPLoading = false
    @Published public private(set) var isPingingServers = false
    @Published public private(set) var isRefreshingSubscription = false
    /// Prefill for «Вставить конфиг» when opened from clipboard / QR.
    @Published public var pendingImportConfigText: String?

    // MARK: - Access sources (Free / Premium / imported)
    @Published public var activeAccess: AccessSource = .free
    @Published public var freeHours = 0
    @Published public var freeTrafficMB = 0
    @Published public var freeExpiresAt: Date?
    @Published public var hasPremiumEntitlement = false
    @Published public var premiumRemainingDays = 0
    /// Plan traffic limit in GB (from `traffic_gb`).
    @Published public var premiumTrafficGB = 300
    /// Remaining traffic in GB (from `traffic_gb_remaining`). `nil` until server reports it.
    @Published public var premiumTrafficRemainingGB: Int?
    /// Live used GB for the shared subscription pool (`traffic_gb_used` from /me).
    @Published public var premiumTrafficUsedExactGB: Double?
    @Published public var premiumWhitelistGB = 0
    @Published public var premiumDevicesUsed = 1
    @Published public var premiumDeviceLimit = 5
    /// Paid / active tariff name for Management — never overwritten by catalog browsing.
    @Published public var activePlanName = ""
    /// Checkout cart only (browse / buy). Must not drive Management subscription card.
    @Published public var selectedPlan: PlanConfiguration = VPNDirectPlanCatalog.defaultConfiguration()
    @Published public var planBrowseMode: VPNDirectPlanMode = .presets
    @Published public var selectedPresetID: String = VPNDirectPlanCatalog.featured.id
    @Published public var autoRenewPremium = true
    @Published public var paymentMethod: PaymentMethod = .apple
    @Published public var checkoutTitle = "Plus · 30 дней"
    @Published public var checkoutPrice = 799
    /// Payment screen entry: renew shows active tariff; plan pick shows selected tariff.
    @Published public var checkoutEntrySource: CheckoutEntrySource = .selectedPlan
    @Published public var checkoutReturnPage: DetailPage = .premiumPlans
    @Published public var pendingAddOnTrafficGB = 0
    @Published public var pendingAddOnDevice = false
    @Published public var pendingAddOnDay = false
    @Published public var accessChoiceContext: String?
    @Published public var importFromAccessChoice = false
    @Published public var checkoutAuthEmail = ""
    @Published public var checkoutAuthCode = ""
    @Published public var checkoutAuthBotCode = ""
    @Published public var checkoutAuthBotIdentifier = ""
    /// Segment on «Аккаунт бота»: code entry vs Telegram confirm. Kept on the model so deep links / busy state do not reset it.
    @Published public var checkoutAuthBotMode: CheckoutAuthBotMode = .code
    @Published public var checkoutAuthPhone = ""
    @Published public var checkoutAuthPhoneRequestId = ""
    @Published public var checkoutAuthError: String?
    @Published public var checkoutAuthBusy = false
    @Published public var showBotLoginRateLimitNotice = false
    @Published public var botLoginRateLimitRetryAfter = 600
    /// In-flight Telegram confirm poll — cancelled on re-entry / deep link / logout.
    var botLoginConfirmTask: Task<Void, Never>?
    @Published public var authAccountSwitchWarning = false
    @Published public var pendingAuthDestination: DetailPage?
    /// Apple/Google after account-switch confirm (not a DetailPage).
    @Published public var pendingSocialAuth: SocialAuthKind?
    /// When true, auth success returns to account instead of continuing checkout.
    @Published public var authFlowReturnsToAccount = false
    @Published public var paymentErrorMessage = "Не удалось завершить оплату"
    @Published public var paymentActivationPending = false
    @Published public var lastPaymentId: String?
    @Published public var paymentWaitingSubtitle = ""
    @Published public var paymentWaitingTimedOut = false
    @Published public var appCatalog: DirectAppCatalog?
    /// Non-nil when catalog says this binary is below ios_min_version / ios_min_build.
    @Published public var forceUpdateRequirement: DirectForceUpdateRequirement?
    /// Catalog tariff id for app_tariff checkout (must survive savePendingCheckout).
    @Published public var pendingCheckoutTariffID: Int?
    private var paymentPollTask: Task<Void, Never>?
    private var paymentWaitStartedAt: Date?
    /// True only after we successfully opened the external pay WebView for this attempt.
    var didOpenExternalPayPage = false
    @Published public var directAccountEmail: String?
    @Published public var directAccountKind: String?
    @Published public var directAuthMethod: String?
    @Published public var directAccountUsername: String?
    @Published public var directAccountPhone: String?
    @Published public var directSubscriptionURL: String?
    @Published public var lastSuccessTitle = ""
    @Published public var lastSuccessPrice = 0
    @Published public var lastSuccessPeriodDays = 30

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
    private var lastPeriodicURLTestAt: Date?
    /// Live outbound currently used by urltest/selector (not the same as manual `selectedServerID`).
    /// Must be `@Published` — otherwise Auto UI keeps falling back to `servers.first` (Germany).
    @Published private var assignedServerID: String?
    @Published public private(set) var favoriteServerIDs: Set<String> = []
    @Published public private(set) var recentServerIDs: [String] = []
    private var sessionTrafficBaseline: Int64 = 0
    private var lastSessionTrafficTotal: Int64 = 0
    private var skipAccessChoiceGate = false
    private var entitlementDisconnectInFlight = false
    /// True after NE reports `.connecting` for the current dial — used to fail fast on drop.
    private var connectSawConnecting = false

    private static let favoritesKey = "vpndirect.favorite.servers"
    private static let recentKey = "vpndirect.recent.servers"
    private static let urltestMigratedKey = "vpndirect.config.urltest.migrated.v1"
    private static let urltestToleranceMigratedKey = "vpndirect.config.urltest.tolerance.v50"
    private static let freeHoursKey = "vpndirect.access.free.hours"
    private static let freeTrafficKey = "vpndirect.access.free.traffic.mb"
    private static let freeExpiresAtKey = "vpndirect.access.free.expires_at"
    private static let accessSourceKey = "vpndirect.access.source"
    private static let premiumEntitlementKey = "vpndirect.access.premium.enabled"
    private static let premiumDaysKey = "vpndirect.access.premium.days"
    private static let premiumTrafficKey = "vpndirect.access.premium.traffic.gb"
    private static let premiumTrafficRemainingKey = "vpndirect.access.premium.traffic.remaining.gb"
    private static let premiumWhitelistKey = "vpndirect.access.premium.whitelist.gb"
    private static let premiumDevicesUsedKey = "vpndirect.access.premium.devices.used"
    private static let premiumDeviceLimitKey = "vpndirect.access.premium.devices.limit"
    private static let premiumAutoRenewKey = "vpndirect.access.premium.autorenew"
    private static let builtinsSeededKey = "vpndirect.access.builtins.seeded.v1"
    private static let premiumPeriodDaysKey = "vpndirect.access.premium.period.days"
    private static let activePlanNameKey = "vpndirect.access.premium.plan.name"
    private static let privacyDisclosureAcceptedKey = "vpndirect.privacyDisclosureAccepted.v1"
    private static let phoneOTPPhoneKey = "vpndirect.auth.phone"
    private static let phoneOTPRequestIdKey = "vpndirect.auth.phone.request_id"
    /// Sentinel for Unlimited traffic in local demo entitlement.
    public static let unlimitedTrafficGB = 100_000

    public init() {
        DirectBackendRuntime.warmUp()
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
        hasPremiumEntitlement = UserDefaults.standard.bool(forKey: Self.premiumEntitlementKey)
        premiumRemainingDays = UserDefaults.standard.integer(forKey: Self.premiumDaysKey)
        let traffic = UserDefaults.standard.integer(forKey: Self.premiumTrafficKey)
        premiumTrafficGB = traffic > 0 ? traffic : 300
        if UserDefaults.standard.object(forKey: Self.premiumTrafficRemainingKey) != nil {
            premiumTrafficRemainingGB = UserDefaults.standard.integer(forKey: Self.premiumTrafficRemainingKey)
        }
        premiumWhitelistGB = max(0, UserDefaults.standard.integer(forKey: Self.premiumWhitelistKey))
        let used = UserDefaults.standard.integer(forKey: Self.premiumDevicesUsedKey)
        premiumDevicesUsed = used > 0 ? used : 1
        let limit = UserDefaults.standard.integer(forKey: Self.premiumDeviceLimitKey)
        premiumDeviceLimit = limit > 0 ? limit : 5
        if UserDefaults.standard.object(forKey: Self.premiumAutoRenewKey) != nil {
            autoRenewPremium = UserDefaults.standard.bool(forKey: Self.premiumAutoRenewKey)
        }
        activePlanName = UserDefaults.standard.string(forKey: Self.activePlanNameKey) ?? ""
        if let last = LastPaidCatalogCheckout.current {
            if activePlanName.isEmpty {
                activePlanName = last.planName
            }
            selectedPlan = PlanConfiguration(
                name: last.planName,
                days: last.periodDays,
                devices: last.devices,
                trafficGB: last.trafficGB,
                whitelistGB: 0
            )
            pendingCheckoutTariffID = last.tariffID
            checkoutTitle = Self.checkoutTitle(for: selectedPlan)
            checkoutPrice = last.price
        } else {
            selectedPlan = VPNDirectPlanCatalog.defaultConfiguration()
            let storedPeriod = UserDefaults.standard.integer(forKey: Self.premiumPeriodDaysKey)
            if hasPremiumEntitlement {
                selectedPlan = PlanConfiguration(
                    name: activePlanName.isEmpty ? selectedPlan.name : activePlanName,
                    days: VPNDirectPlanCatalog.presetPeriodDays.contains(storedPeriod) ? storedPeriod : selectedPlan.days,
                    devices: premiumDeviceLimit,
                    trafficGB: premiumTrafficGB >= Self.unlimitedTrafficGB ? nil : premiumTrafficGB,
                    whitelistGB: premiumWhitelistGB
                )
            }
            checkoutTitle = Self.checkoutTitle(for: selectedPlan)
            checkoutPrice = VPNDirectPricingEngine.price(for: selectedPlan)
        }
        activeAccess = Self.loadAccessSource()
        // Restore phone OTP mid-flow after process death.
        if let phone = UserDefaults.standard.string(forKey: Self.phoneOTPPhoneKey), !phone.isEmpty {
            checkoutAuthPhone = phone
        }
        if let rid = UserDefaults.standard.string(forKey: Self.phoneOTPRequestIdKey), !rid.isEmpty {
            checkoutAuthPhoneRequestId = rid
        }
    }

    /// Wipe Direct session + entitlement so Management/Home/Profile do not show stale tariff/traffic.
    /// Does not delete imported (non-Direct) profiles.
    public func clearDirectSessionState() {
        botLoginConfirmTask?.cancel()
        botLoginConfirmTask = nil

        directAccountEmail = nil
        directAccountKind = nil
        directAuthMethod = nil
        directAccountUsername = nil
        directAccountPhone = nil
        directSubscriptionURL = nil
        locationCaps = []

        hasPremiumEntitlement = false
        premiumRemainingDays = 0
        premiumTrafficGB = 300
        premiumTrafficRemainingGB = nil
        premiumTrafficUsedExactGB = nil
        premiumWhitelistGB = 0
        premiumDevicesUsed = 1
        premiumDeviceLimit = 5
        activePlanName = ""
        autoRenewPremium = true

        checkoutAuthError = nil
        checkoutAuthBusy = false
        showBotLoginRateLimitNotice = false
        checkoutAuthBotCode = ""
        checkoutAuthBotIdentifier = ""
        checkoutAuthCode = ""
        clearPersistedPhoneOTP()

        UserDefaults.standard.set(false, forKey: "vpndirect.authenticated")
        persistPremiumState()
        setActiveAccess(.free)

        DirectBalanceFlow.shared.applyMeBalance(usdCents: 0)

        // If the active profile is Direct-owned, deselect it (keep imported subs).
        if let item = activeSubscription,
           DirectBuiltinProfile.isDirectOwned(item.profile.remoteURL)
        {
            activeSubscriptionID = 0
            selectedServerID = nil
            Task {
                await SharedPreferences.selectedProfileID.set(-1)
                await SharedPreferences.preferredOutboundTag.set("")
                environments?.selectedProfileUpdate.send()
            }
        }

        switch detailPage {
        case .account, .authSuccess, .authLogin, .authEmail, .authCode, .authRegister,
             .authRecovery, .authBot, .authPhone, .authPhoneCode:
            detailStack.removeAll()
            detailPage = .account
        default:
            break
        }

        objectWillChange.send()
    }

    func persistPhoneOTP(phone: String, requestId: String) {
        checkoutAuthPhone = phone
        checkoutAuthPhoneRequestId = requestId
        UserDefaults.standard.set(phone, forKey: Self.phoneOTPPhoneKey)
        UserDefaults.standard.set(requestId, forKey: Self.phoneOTPRequestIdKey)
    }

    func clearPersistedPhoneOTP() {
        checkoutAuthPhone = ""
        checkoutAuthPhoneRequestId = ""
        UserDefaults.standard.removeObject(forKey: Self.phoneOTPPhoneKey)
        UserDefaults.standard.removeObject(forKey: Self.phoneOTPRequestIdKey)
    }

    /// Name shown on Management / subscription chrome (active paid plan, not checkout cart).
    public var activePlanDisplayName: String {
        if !activePlanName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return activePlanName
        }
        if let name = LastPaidCatalogCheckout.current?.planName,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return name
        }
        return ""
    }

    public var selectedPlanPrice: Int {
        VPNDirectPricingEngine.price(for: selectedPlan)
    }

    public var premiumTrafficDisplayLabel: String {
        if premiumTrafficGB >= Self.unlimitedTrafficGB { return "Unlimited" }
        if let remaining = premiumTrafficRemainingGB, remaining >= 0, premiumTrafficGB > 0,
           premiumTrafficGB < Self.unlimitedTrafficGB
        {
            return "\(remaining)/\(premiumTrafficGB) ГБ"
        }
        return "\(premiumTrafficGB) ГБ"
    }

    /// Used GB for management meter. Prefer exact used from /me, else limit − remaining.
    public var premiumTrafficUsedGB: Int {
        if let exact = premiumTrafficUsedExactGB, exact.isFinite {
            return max(0, Int(exact.rounded(.down)))
        }
        guard premiumTrafficGB > 0, premiumTrafficGB < Self.unlimitedTrafficGB else { return 0 }
        guard let remaining = premiumTrafficRemainingGB else { return 0 }
        return max(0, premiumTrafficGB - max(0, remaining))
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
            if premiumTrafficGB >= Self.unlimitedTrafficGB { return "∞" }
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
        guard hasPremiumEntitlement, premiumRemainingDays > 0 else { return false }
        return premiumTrafficGB > 0
    }

    public var isExternalAccessReady: Bool {
        // Third-party imported subscriptions are independent of Free/Premium.
        if let item = activeSubscription, !DirectBuiltinProfile.isBuiltin(item.profile.remoteURL) {
            return true
        }
        guard case let .imported(id) = activeAccess else { return false }
        return subscriptions.contains(where: { $0.id == id })
    }

    public var isActiveAccessReady: Bool {
        switch activeAccess {
        case .free: return isFreeAccessReady
        case .premium: return isPremiumAccessReady
        case .imported: return isExternalAccessReady
        }
    }

    public var shouldShowAccessChoiceOnConnect: Bool {
        // Selected third-party profile → never gate with Free/Premium chooser.
        if let item = activeSubscription, !DirectBuiltinProfile.isBuiltin(item.profile.remoteURL) {
            return false
        }
        return !isActiveAccessReady
    }

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

    /// Live Direct outbounds only (builtin + Direct-owned hosts). Never third-party imports.
    public var liveDirectServers: [VPNServer] {
        func usable(_ servers: [VPNServer]) -> [VPNServer] {
            servers.filter { server in
                let id = server.id.lowercased()
                return !id.isEmpty && id != "direct" && id != "auto"
            }
        }

        // Same source as home: the active Direct-owned profile (Remnawave remote), not empty builtins.
        if let active = activeSubscription,
           DirectBuiltinProfile.isDirectOwned(active.profile.remoteURL)
        {
            let fromActive = usable(active.servers)
            if !fromActive.isEmpty { return fromActive }
        }

        let directItems = subscriptions.filter { DirectBuiltinProfile.isDirectOwned($0.profile.remoteURL) }
        // Prefer live remotes over builtin stubs, then premium/free builtins.
        let ordered = directItems.sorted { lhs, rhs in
            let lBuiltin = DirectBuiltinProfile.isBuiltin(lhs.profile.remoteURL)
            let rBuiltin = DirectBuiltinProfile.isBuiltin(rhs.profile.remoteURL)
            if lBuiltin != rBuiltin { return !lBuiltin && rBuiltin }
            return Self.builtinSortRank(lhs.profile.remoteURL) < Self.builtinSortRank(rhs.profile.remoteURL)
        }
        for item in ordered {
            let servers = usable(item.servers)
            if !servers.isEmpty { return servers }
        }
        return []
    }

    /// Whether the Локации tab can switch the tunnel (same role as the server sheet).
    public var canSwitchDirectLocations: Bool {
        isPremiumAccessReady && !liveDirectServers.isEmpty
    }

    /// Servers for the Direct «Локации» tab — Direct only, never external imports.
    public var directServerItems: [DirectServerItem] {
        let live = liveDirectServers
        var items: [DirectServerItem] = []
        if !live.isEmpty {
            items = live.map(DirectServerItem.from(server:))
        } else {
            items = DirectLocationsCatalog.shared.items
        }
        return mergeExhaustedLocationItems(into: items)
    }

    public func isLocationCapExhausted(serverID: String?, locationLabel: String?) -> Bool {
        let id = (serverID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if id.hasPrefix("exhausted:") { return true }
        guard let cap = locationCap(serverID: id, locationLabel: locationLabel) else { return false }
        return cap.exhausted == true || cap.available == false
    }

    public func isLocationCapExhausted(_ server: VPNServer) -> Bool {
        isLocationCapExhausted(serverID: server.id, locationLabel: server.locationLabel)
    }

    /// Tell metering which limited squad is selected (null = Default / unlimited path).
    public func reportMeteringActiveLocation(serverID: String?) async {
        DirectBackendRuntime.warmUp()
        guard DirectBackendRuntime.isAuthenticated() else { return }
        var squadUuid: String?
        if let serverID,
           let server = (activeSubscription?.servers ?? liveDirectServers).first(where: { $0.id == serverID })
            ?? serversForLocationPicker.first(where: { $0.id == serverID })
        {
            squadUuid = locationCap(for: server)?.squadUuid
        } else if let serverID {
            squadUuid = locationCap(serverID: serverID, locationLabel: serverID)?.squadUuid
        }
        if let report = DirectBackendRuntime.reportActiveLocation {
            await report(squadUuid)
        }
    }

    /// Matching limited-location cap from account state, if any.
    public func locationCap(for server: VPNServer) -> DirectLocationCap? {
        locationCap(serverID: server.id, locationLabel: server.locationLabel, city: server.city, country: server.country)
    }

    public func locationCap(
        serverID: String?,
        locationLabel: String?,
        city: String? = nil,
        country: String? = nil
    ) -> DirectLocationCap? {
        let id = (serverID ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let needles = [locationLabel, city, country, serverID]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
        // Prefer exact title match (important for short names like «5G»).
        for cap in locationCaps {
            let key = (cap.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            if needles.contains(where: { $0 == key }) {
                return cap
            }
        }
        for cap in locationCaps {
            let title = (cap.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            let key = title.lowercased()
            if needles.contains(where: { $0.contains(key) || key.contains($0) }) {
                return cap
            }
            if !id.isEmpty, id.contains(key) { return cap }
        }
        return nil
    }

    /// Second line on location cards: «Безлимитный» / «0.14 / 3 GB» / «Лимит 3 GB исчерпан».
    public func locationQuotaSubtitle(for server: VPNServer) -> String {
        guard let cap = locationCap(for: server) else {
            return String(localized: "Безлимитный")
        }
        let amount = Self.formatTrafficCapGb(cap.capGb)
        let exhausted = server.id.hasPrefix("exhausted:")
            || cap.exhausted == true
            || cap.available == false
        if exhausted {
            return "Лимит \(amount) исчерпан"
        }
        let used = Self.formatTrafficUsedGb(cap.usedGb, cap: cap.capGb)
        return "\(used) / \(amount)"
    }

    /// Used / cap in `0…1` for limited locations. `nil` = unlimited (no meter bar).
    public func locationQuotaUsedFraction(for server: VPNServer) -> Double? {
        locationQuotaUsedFraction(
            cap: locationCap(for: server),
            exhaustedOverride: server.id.hasPrefix("exhausted:")
        )
    }

    public func locationQuotaUsedFraction(
        serverID: String?,
        locationLabel: String?,
        city: String? = nil,
        country: String? = nil
    ) -> Double? {
        locationQuotaUsedFraction(
            cap: locationCap(serverID: serverID, locationLabel: locationLabel, city: city, country: country),
            exhaustedOverride: (serverID ?? "").hasPrefix("exhausted:")
        )
    }

    private func locationQuotaUsedFraction(
        cap: DirectLocationCap?,
        exhaustedOverride: Bool
    ) -> Double? {
        guard let cap else { return nil }
        if exhaustedOverride || cap.exhausted == true || cap.available == false {
            return 1
        }
        let limit = cap.capGb ?? 0
        guard limit > 0, limit.isFinite else { return nil }
        if let used = cap.usedGb, used.isFinite, used >= 0 {
            return min(1, max(0, used / limit))
        }
        if let rem = cap.remainingGb, rem.isFinite {
            return min(1, max(0, (limit - rem) / limit))
        }
        return 0
    }

    /// Lightweight `/me` refresh — only location caps (for live usage meters).
    public func refreshLocationCaps() async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.refreshLocationCaps {
            await run(self)
            return
        }
    }

    /// Black-square fallback when there is no flag asset (e.g. named «5G»).
    public func flagFallbackLabel(for server: VPNServer) -> String? {
        let hay = "\(server.locationLabel) \(server.city) \(server.country) \(server.id)"
        if hay.range(of: "5G", options: [.caseInsensitive, .diacriticInsensitive]) != nil {
            return "5G"
        }
        return nil
    }

    public static func formatTrafficCapGb(_ gb: Double?) -> String {
        guard let gb, gb > 0, gb.isFinite else { return "—" }
        if abs(gb - gb.rounded()) < 0.05 {
            return "\(Int(gb.rounded())) GB"
        }
        let trimmed = String(format: "%g", gb)
        return "\(trimmed) GB"
    }

    public static func formatTrafficUsedGb(_ used: Double?, cap: Double?) -> String {
        let value: Double
        if let used, used.isFinite, used >= 0 {
            value = used
        } else {
            value = 0
        }
        if value < 0.01 {
            return "0 GB"
        }
        // Always keep two decimals under 1 GB so 0.4 of a large plan does not round to 0.0.
        if value < 1 {
            return String(format: "%.2f GB", value)
        }
        if abs(value - value.rounded()) < 0.05 {
            return "\(Int(value.rounded())) GB"
        }
        return String(format: "%.1f GB", value)
    }

    /// Live subscription servers plus phantom rows for exhausted limited locations removed from Remna.
    public var serversForLocationPicker: [VPNServer] {
        var servers = activeSubscription?.servers ?? liveDirectServers
        let existing = Set(servers.map { $0.locationLabel.lowercased() })
        for cap in locationCaps where cap.exhausted == true || cap.available == false {
            let title = (cap.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            if existing.contains(where: { $0.contains(title.lowercased()) }) { continue }
            let sid = "exhausted:\(cap.squadUuid ?? title)"
            servers.append(
                VPNServer(
                    id: sid,
                    city: title,
                    country: title,
                    countryCode: "ZZ",
                    ping: 0,
                    load: 100,
                    groupTag: "proxy",
                    locationLabel: title
                )
            )
        }
        return servers
    }

    private func mergeExhaustedLocationItems(into items: [DirectServerItem]) -> [DirectServerItem] {
        var out = items
        let existing = Set(out.map { $0.city.lowercased() + "|" + $0.country.lowercased() })
        for cap in locationCaps where cap.exhausted == true || cap.available == false {
            let title = (cap.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            if out.contains(where: {
                $0.city.localizedCaseInsensitiveContains(title)
                    || $0.country.localizedCaseInsensitiveContains(title)
                    || $0.id.localizedCaseInsensitiveContains(title)
            }) {
                continue
            }
            let key = title.lowercased() + "|" + title.lowercased()
            guard !existing.contains(key) else { continue }
            out.append(
                DirectServerItem(
                    id: "exhausted:\(cap.squadUuid ?? title)",
                    countryCode: "ZZ",
                    country: title,
                    city: title,
                    latency: 0,
                    load: 100,
                    region: "EUROPE"
                )
            )
        }
        return out
    }

    public func openPremiumPlans(mode: VPNDirectPlanMode) {
        planBrowseMode = mode
        if mode == .presets {
            if let preset = VPNDirectPlanCatalog.preset(id: selectedPresetID) {
                let days = VPNDirectPlanCatalog.presetPeriodDays.contains(selectedPlan.days)
                    || (preset.id == "travel" && selectedPlan.days == 7)
                    ? selectedPlan.days
                    : preset.defaultDays
                applySelectedPlan(preset.configuration(days: days), presetID: preset.id)
            }
            select(tab: .plans)
        } else {
            var custom = selectedPlan
            custom.name = nil
            applySelectedPlan(custom)
            openDetail(.planConstructor)
        }
    }

    public func ensureDirectProfileActive() {
        if let premiumID = premiumProfileID {
            if activeSubscriptionID != premiumID {
                setActiveAccess(.premium)
                activate(subscriptionID: premiumID)
            } else {
                setActiveAccess(.premium)
            }
            return
        }
        if let freeID = freeProfileID, activeSubscriptionID != freeID {
            setActiveAccess(.free)
            activate(subscriptionID: freeID)
        }
    }

    public func setImportedAccessAndActivate(_ subscriptionID: Int64) {
        setActiveAccess(.imported(subscriptionID))
        activate(subscriptionID: subscriptionID)
        selectedTab = .home
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
                let wl = premiumWhitelistGB > 0 ? " · \(premiumWhitelistGB) GB WL" : ""
                return "\(premiumExpiryShortLabel) · \(premiumTrafficDisplayLabel) · \(premiumDevicesUsed)/\(premiumDeviceLimit)\(wl)"
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
        case .free: return "ТАРИФЫ"
        case .premium: return hasPremiumEntitlement ? "УПРАВЛЯТЬ" : "ТАРИФ"
        case .imported: return "УПРАВЛЕНИЕ"
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

    /// Short label for the connection-mode card (home + locations list).
    public var connectionModeDisplayTitle: String {
        switch connectionMode {
        case "Авто":
            return "Автовыбор"
        case "Максимальная скорость":
            return "Скорость"
        case "Антиблокировка":
            return "5G"
        default:
            return connectionMode
        }
    }

    /// Subtitle under the mode title: fixed text for 5G, otherwise the resolved location.
    public var connectionModeDisplaySubtitle: String {
        switch connectionMode {
        case "5G", "Антиблокировка":
            return "Для Сотовой связи"
        default:
            if let label = activeServer?.locationLabel, !label.isEmpty {
                return label
            }
            if isProtected || isBusy {
                return "Определяем…"
            }
            return "Локация не выбрана"
        }
    }

    /// Location currently driven by the active mode / manual pick (pin under the mode card).
    public var pinnedLocationServer: VPNServer? {
        if let selectedServerID,
           let sub = activeSubscription,
           let selected = Self.resolveServer(id: selectedServerID, in: sub.servers)
        {
            return selected
        }
        return activeServer
    }

    public var activeSubscription: VPNSubscriptionItem? {
        guard activeSubscriptionID > 0 else { return nil }
        return subscriptions.first(where: { $0.id == activeSubscriptionID })
    }

    public var activeServer: VPNServer? {
        guard let sub = activeSubscription else { return nil }
        if let selectedServerID,
           let selected = Self.resolveServer(id: selectedServerID, in: sub.servers)
        {
            return selected
        }
        if let assignedServerID,
           assignedServerID != "auto",
           let assigned = Self.resolveServer(id: assignedServerID, in: sub.servers)
        {
            return assigned
        }
        // Auto mode: never fall back to list order (Germany-first).
        // When connected, wait for live assigned outbound; when idle, soft-preview best ping.
        if usesAutoSelection {
            guard !isConnected else { return nil }
            let ranked = sub.servers.filter { $0.ping > 0 }.sorted { $0.ping < $1.ping }
            return ranked.first
        }
        return sub.servers.first
    }

    /// Match libbox outbound tags to catalog servers. Prefer longest id to avoid
    /// short prefixes (e.g. `de`) stealing a more specific tag (`de-berlin-1`).
    private static func resolveServer(id: String, in servers: [VPNServer]) -> VPNServer? {
        let needle = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        if let exact = servers.first(where: { $0.id == needle }) {
            return exact
        }
        let hits = servers.filter {
            needle.hasPrefix($0.id) || $0.id.hasPrefix(needle)
        }
        return hits.max(by: { $0.id.count < $1.id.count })
    }

    public var statusTitle: String {
        switch phase {
        case .connecting: "Защищаем Сеть"
        case .disconnecting: "Отключаем Защиту"
        case .switching: "Переподключение"
        case .idle: isProtected ? "Подключено" : "Отключено"
        }
    }

    public var statusSubtitle: String {
        switch phase {
        case .switching:
            return "Переключаем маршрут без потери защиты"
        case .connecting, .disconnecting:
            return "Устанавливаем защищённый канал"
        case .idle:
            if isProtected {
                let provider = (activeSubscription?.name ?? "VPN")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let label = provider.isEmpty ? "VPN" : provider
                return "Трафик идет через \(label)"
            }
            return "Соединение не активно"
        }
    }

    public func clearRecentHistory() {
        recentServerIDs = []
        UserDefaults.standard.removeObject(forKey: Self.recentKey)
    }

    public func select(tab: AppTab) {
        selectedTab = tab
        // Management always shows the paid plan — never a browsed unpaid cart.
        if tab == .management, hasPremiumEntitlement {
            if detailPage == .payment {
                restoreActiveSubscriptionAfterAbandonedCheckout()
            } else {
                syncSelectedPlanFromActiveSubscription()
            }
        }
        closeDetail()
        isMenuOpen = false
        HapticManager.shared.play(.navigation)
    }

    public func openDetail(_ page: DetailPage) {
        if let current = detailPage, current != page {
            detailStack.append(current)
        }
        detailPage = page
        isMenuOpen = false
    }

    /// Leave all detail pages and return to the current tab root.
    public func closeDetail() {
        detailStack.removeAll()
        detailPage = nil
    }

    /// Pop one detail level (or return to the tab root).
    public func goBack() {
        // Payment flow: never leave the user stuck on processing/waiting after Back.
        if let page = detailPage, Self.isPaymentFlowPage(page) {
            abandonPaymentFlow(returnToPaymentMethod: page == .paymentWaiting || page == .paymentError || page == .paymentProcessing)
            return
        }
        let leavingPayment = detailPage == .payment
        if let previous = detailStack.popLast() {
            if Self.isPaymentFlowPage(previous) {
                abandonPaymentFlow(returnToPaymentMethod: true)
                return
            }
            detailPage = previous
        } else {
            detailPage = nil
        }
        if leavingPayment {
            restoreActiveSubscriptionAfterAbandonedCheckout()
        }
    }

    /// Browsed cart must not stick on Management after Back from payment without purchase.
    public func restoreActiveSubscriptionAfterAbandonedCheckout() {
        clearPendingCheckout()
        guard hasPremiumEntitlement else { return }
        syncSelectedPlanFromActiveSubscription()
        checkoutEntrySource = .selectedPlan
    }

    private static func isPaymentFlowPage(_ page: DetailPage) -> Bool {
        switch page {
        case .paymentProcessing, .paymentWaiting, .paymentCancelled, .paymentError, .paymentSuccess, .externalPay:
            return true
        default:
            return false
        }
    }

    /// Leave waiting/error/processing without auto-resuming the bank-wait screen.
    public func abandonPaymentFlow(returnToPaymentMethod: Bool) {
        stopPaymentStatusPolling()
        paymentActivationPending = false
        paymentWaitStartedAt = nil
        paymentWaitingTimedOut = false
        didOpenExternalPayPage = false
        detailStack.removeAll { Self.isPaymentFlowPage($0) }
        if returnToPaymentMethod {
            detailPage = .payment
        } else {
            detailPage = detailStack.popLast()
        }
    }

    /// Title for the chrome back control (previous page or current tab).
    public var chromeBackTitle: String {
        if let previous = detailStack.last {
            return Self.shortTitle(for: previous)
        }
        return selectedTab.title
    }

    private static func shortTitle(for page: DetailPage) -> String {
        switch page {
        case .premiumPlans: return "Тарифы"
        case .locations: return "Локации"
        case .planConstructor: return "Конструктор"
        case .payment: return "Оплата"
        case .balanceAccount: return "Баланс"
        case .balanceTopUp: return "Пополнение"
        case .accessChoice: return "Доступ"
        case .addOns: return "Дополнения"
        case .systemSettings: return "Настройки"
        case .systemWarning: return "Системные"
        case .about: return "О приложении"
        case .serviceLog: return "Журнал"
        case .security: return "Безопасность"
        case .connection: return "Подключение"
        case .diagnostics: return "Диагностика"
        case .activity: return "Мои серверы"
        case .subscription: return "Подписка"
        case .newConfiguration, .importFile, .importConfigText: return "Импорт"
        case .applicationSettings, .coreSettings, .tunnelSettings, .onDemandSettings: return "Настройки"
        case .authLogin: return "Вход"
        case .authEmail: return "Email"
        case .authCode: return "Код"
        case .authRegister: return "Регистрация"
        case .authRecovery: return "Восстановление"
        case .authBot: return "Код бота"
        case .authPhone: return "Телефон"
        case .authPhoneCode: return "Код"
        case .authSuccess: return "Готово"
        case .account: return "Аккаунт"
        case .paymentProcessing, .paymentWaiting, .paymentCancelled, .paymentError, .paymentSuccess, .externalPay:
            return "Оплата"
        }
    }

    public func openAuthFromAccount() {
        authFlowReturnsToAccount = true
        checkoutAuthError = nil
        openDetail(.authLogin)
    }

    /// Deep link from Telegram bot (`vpndirect://auth/bot`).
    /// Cancels any in-flight confirm poll; keeps «Подтверждение» only if still busy with an identifier.
    public func openBotAuthFromDeepLink() {
        authFlowReturnsToAccount = true
        checkoutAuthError = nil
        selectedTab = .profile
        botLoginConfirmTask?.cancel()
        botLoginConfirmTask = nil
        let keepConfirm = checkoutAuthBusy
            && !checkoutAuthBotIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if keepConfirm {
            checkoutAuthBotMode = .confirm
            checkoutAuthBusy = false
        } else {
            checkoutAuthBusy = false
            checkoutAuthBotCode = ""
            checkoutAuthBotMode = .code
        }
        openDetail(.authBot)
    }

    public func completeAuthAfterSuccess() {
        HapticManager.shared.play(.selection)
        if authFlowReturnsToAccount {
            detailStack.removeAll()
            detailPage = .account
            return
        }
        continueCheckoutAfterAuth()
    }

    public func openAccessStripAction() {
        switch activeAccess {
        case .free:
            select(tab: .plans)
        case .premium:
            if hasPremiumEntitlement {
                openDetail(.addOns)
            } else {
                select(tab: .plans)
            }
        case .imported:
            select(tab: .management)
        }
    }

    /// Soft-remove: stop using an imported subscription on this device; profile stays in the list.
    /// Clears the home selection — never auto-activates another imported subscription.
    public func removeImportedFromClient(subscriptionID: Int64? = nil) {
        let targetID = subscriptionID ?? activeSubscriptionID
        guard let item = subscriptions.first(where: { $0.id == targetID }),
              !DirectBuiltinProfile.isBuiltin(item.profile.remoteURL)
        else {
            select(tab: .management)
            return
        }
        guard activeSubscriptionID == targetID else {
            HapticManager.shared.play(.selection)
            return
        }
        Task {
            if phase == .connecting || phase == .switching || isBusy {
                await cancelPendingConnection(showError: false)
            }
            activeSubscriptionID = 0
            selectedServerID = nil
            assignedServerID = nil
        setActiveAccess(.free)
            await SharedPreferences.selectedProfileID.set(-1)
            await SharedPreferences.preferredOutboundTag.set("")
            await disableVPNAutoConnect()
            environments?.selectedProfileUpdate.send()
            HapticManager.shared.play(.selection)
        }
    }

    public func refreshActiveSubscription() {
        guard let subscription = activeSubscription else {
            alert = AlertState(errorMessage: String(localized: "Нет активной подписки."))
                return
            }
        refreshSubscription(subscriptionID: subscription.id)
    }

    public func openChangeSubscription() {
        openSubscriptionPicker()
    }

    /// Sheet with installed subscriptions (Direct + imports). Used when home has no active profile.
    public func openSubscriptionPicker() {
        Task { @MainActor in
            activeSheet = .subscriptionPicker
        }
    }

    public func openChangeServer() {
        // Defer so the tap can finish; mounting the picker on the same runloop
        // felt like a dead button when the main thread was already busy.
        Task { @MainActor in
            if activeSubscription == nil {
                activeSheet = .subscriptionPicker
        } else {
                activeSheet = .serverPicker
            }
        }
    }

    /// Account has a real VPN Direct tariff (show Management Direct card / picker row).
    public var hasNativeDirectSubscription: Bool {
        hasPremiumEntitlement
    }

    /// Selected profile in the client is the live Direct subscription (not empty builtin stub).
    public var isNativeDirectSubscriptionActive: Bool {
        guard let sub = activeSubscription else { return false }
        return DirectBuiltinProfile.isDirectOwned(sub.profile.remoteURL)
            && !DirectBuiltinProfile.isBuiltin(sub.profile.remoteURL)
    }

    /// Live Direct remote (`/sub/…`), never `vpndirect://builtin/*` stubs.
    public var preferredNativeDirectSubscription: VPNSubscriptionItem? {
        let owned = subscriptions.filter {
            DirectBuiltinProfile.isDirectOwned($0.profile.remoteURL)
                && !DirectBuiltinProfile.isBuiltin($0.profile.remoteURL)
        }
        return owned.first(where: { !$0.servers.isEmpty }) ?? owned.first
    }

    /// Profiles the user can pick in the subscription sheet.
    public var selectableSubscriptions: [VPNSubscriptionItem] {
        let hasLiveDirect = preferredNativeDirectSubscription != nil
        return subscriptions.filter { item in
            if DirectBuiltinProfile.isBuiltin(item.profile.remoteURL) {
                // Prefer the real Direct remote; show premium stub only as last resort.
                guard DirectBuiltinProfile.kind(for: item.profile.remoteURL) == .premium else {
                    return false
                }
                return hasPremiumEntitlement && !hasLiveDirect
            }
            if DirectBuiltinProfile.isDirectOwned(item.profile.remoteURL) {
                return hasPremiumEntitlement
            }
            return true
        }
    }

    /// Activate a profile from the subscription picker and close the sheet.
    public func pickSubscriptionFromSheet(_ subscriptionID: Int64) {
        if let item = subscriptions.first(where: { $0.id == subscriptionID }),
           DirectBuiltinProfile.isDirectOwned(item.profile.remoteURL)
        {
            setActiveAccess(.premium)
        }
        activate(subscriptionID: subscriptionID)
        activeSheet = nil
        selectedTab = .home
    }

    /// Put native Direct back into the client (Management «Использовать»).
    /// Same path as checkout/login: live Direct remote via `attachDirectSubscription`, not the empty builtin stub.
    public func useNativeDirectSubscription() {
        guard hasNativeDirectSubscription else { return }
        HapticManager.shared.play(.selection)
        if let live = preferredNativeDirectSubscription {
            setActiveAccess(.premium)
            activate(subscriptionID: live.id)
            selectedTab = .home
            return
        }
        Task { @MainActor in
            if directSubscriptionURL == nil || directSubscriptionURL?.isEmpty == true {
                await refreshDirectAccount()
            }
            if let url = directSubscriptionURL, !url.isEmpty {
                await attachDirectSubscription(url: url)
            } else if let live = preferredNativeDirectSubscription {
                setActiveAccess(.premium)
                activate(subscriptionID: live.id)
            }
            selectedTab = .home
        }
    }

    /// Fetches current egress IP. While VPN is up this is the VPN exit IP; otherwise the device WAN IP.
    public func refreshPublicIP() {
        publicIPLoading = true
        Task {
            defer { Task { @MainActor in self.publicIPLoading = false } }
            do {
                // Ephemeral session + cache-buster so server switches don't show a stale IP.
                let stamp = Int(Date().timeIntervalSince1970 * 1000)
                guard let url = URL(string: "https://api.ipify.org?_\(stamp)") else {
                    await MainActor.run { publicIPText = "—" }
                    return
                }
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
                request.setValue("text/plain", forHTTPHeaderField: "Accept")
                request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                let session = URLSession(configuration: .ephemeral)
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode),
                      let text = String(data: data, encoding: .utf8)?
                      .trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty
                else {
                    await MainActor.run { publicIPText = "—" }
                    return
                }
                await MainActor.run { publicIPText = text }
            } catch {
                await MainActor.run { publicIPText = "—" }
            }
        }
    }

    public func activateFreeAccess() {
        // Free-via-ads removed — open Direct tariff picker instead.
        select(tab: .plans)
    }

    public func clearAccessChoiceContext() {
        accessChoiceContext = nil
    }

    public func handleAccessChoicePremium() {
        if isPremiumAccessReady {
            guard let premiumID = premiumProfileID else {
                select(tab: .plans)
                return
            }
            setActiveAccess(.premium)
            if activeSubscriptionID != premiumID {
                activate(subscriptionID: premiumID)
            }
            closeDetail()
            Task { await connectAfterAccessChoice() }
        } else if !hasPremiumEntitlement {
            select(tab: .plans)
        } else {
            openDetail(.addOns)
        }
    }

    public func handleAccessChoicePickSubscription() {
        selectedTab = .management
        closeDetail()
    }

    public func handleAccessChoiceAddURL() {
        importFromAccessChoice = true
        isMenuOpen = true
    }

    public func handleImportedProfileActivated(subscriptionID: Int64) {
        importFromAccessChoice = false
        setActiveAccess(.imported(subscriptionID))
        activate(subscriptionID: subscriptionID)
        closeDetail()
        Task { await connectAfterAccessChoice() }
    }

    /// Used by import UI — same path as handleImportedProfileActivated.
    public func activateNewlyImportedSubscription(_ subscriptionID: Int64, connect: Bool = true) {
        importFromAccessChoice = false
        setActiveAccess(.imported(subscriptionID))
        activate(subscriptionID: subscriptionID)
        closeDetail()
        selectedTab = .home
        if connect {
            Task { await connectAfterAccessChoice() }
        }
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
        openDetail(.accessChoice)
    }

    private func entitlementExpiredMessage() -> String {
        switch activeAccess {
        case .free:
            return "Нужен тариф VPN Direct или внешняя подписка."
        case .premium:
            return "Срок Premium истёк или закончился трафик."
        case .imported:
            return "Подписка недоступна."
        }
    }

    private func evaluateAccessEntitlements() {
        // Never interrupt dial / teardown. Free/Premium expiry must not touch third-party.
        guard isConnected, !isStarting,
              phase != .connecting, phase != .disconnecting, phase != .switching
        else { return }

        if let item = activeSubscription, !DirectBuiltinProfile.isBuiltin(item.profile.remoteURL) {
            if case .imported = activeAccess { return }
            setActiveAccess(.imported(item.id))
            return
        }
        if case .imported = activeAccess { return }

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

    public func applySelectedPlan(_ plan: PlanConfiguration, presetID: String? = nil, playHaptic: Bool = true) {
        selectedPlan = plan
        if let presetID {
            selectedPresetID = presetID
        } else if let name = plan.name,
                  let match = VPNDirectPlanCatalog.presets.first(where: { $0.name == name })
        {
            selectedPresetID = match.id
        }
        checkoutTitle = Self.checkoutTitle(for: plan)
        checkoutPrice = VPNDirectPricingEngine.price(for: plan)
        pendingAddOnTrafficGB = 0
        pendingAddOnDevice = false
        pendingAddOnDay = false
        if playHaptic {
            HapticManager.shared.play(.selection)
        }
    }

    public func selectPlan(months: Int, price: Int) {
        // Legacy entry point — map months onto Plus-like resources.
        let days = max(30, months * 30)
        var plan = selectedPlan
        plan.days = days
        if plan.name == nil { plan.name = "Plus" }
        applySelectedPlan(plan)
        checkoutPrice = price
    }

    public func prepareAddOnsCheckout(trafficGB: Int, device: Bool, day: Bool, price: Int) {
        pendingAddOnTrafficGB = trafficGB
        pendingAddOnDevice = device
        pendingAddOnDay = day
        pendingCheckoutTariffID = nil
        checkoutTitle = "Дополнительные ресурсы"
        checkoutPrice = price
        checkoutEntrySource = .addOns
        checkoutReturnPage = .addOns
        PendingCheckout.save(
            PendingCheckout(
                title: checkoutTitle,
                price: price,
                periodDays: day ? 1 : selectedPlan.days,
                paymentMethodRaw: paymentMethod.rawValue,
                returnPage: String(describing: DetailPage.addOns),
                planName: nil,
                trafficGB: trafficGB > 0 ? trafficGB : nil,
                devices: device ? 1 : selectedPlan.devices,
                whitelistGB: 0,
                createdAt: Date(),
                productKind: "addon",
                tariffID: nil,
                addonDays: day ? 1 : 0,
                addonDevices: device ? 1 : 0,
                addonTrafficGB: trafficGB
            )
        )
    }

    public var isDirectAuthenticated: Bool {
        DirectBackendRuntime.warmUp()
        return DirectBackendRuntime.isAuthenticated()
    }

    public func savePendingCheckout() {
        let existing = PendingCheckout.current
        let isAddon = pendingAddOnDay || pendingAddOnDevice || pendingAddOnTrafficGB > 0
        let kind: String = {
            if let existingKind = existing?.productKind, !existingKind.isEmpty { return existingKind }
            if isAddon { return "addon" }
            if selectedPlan.name == nil { return "constructor" }
            return "app_tariff"
        }()
        let tariffID = pendingCheckoutTariffID ?? existing?.tariffID
        PendingCheckout.save(
            PendingCheckout(
                title: checkoutTitle,
                price: checkoutPrice,
                periodDays: selectedPlan.days,
                paymentMethodRaw: paymentMethod.rawValue,
                returnPage: String(describing: checkoutReturnPage),
                planName: selectedPlan.name,
                trafficGB: selectedPlan.trafficGB,
                devices: selectedPlan.devices,
                whitelistGB: 0,
                createdAt: Date(),
                productKind: kind,
                tariffID: tariffID,
                addonDays: isAddon ? (pendingAddOnDay ? 1 : 0) : existing?.addonDays,
                addonDevices: isAddon ? (pendingAddOnDevice ? 1 : 0) : existing?.addonDevices,
                addonTrafficGB: isAddon ? pendingAddOnTrafficGB : existing?.addonTrafficGB
            )
        )
    }

    public func clearPendingCheckout() {
        PendingCheckout.clear()
    }

    public func beginPaymentWaiting() {
        paymentWaitingTimedOut = false
        paymentWaitingSubtitle = "Ожидаем подтверждение банка…"
        if paymentWaitStartedAt == nil {
            paymentWaitStartedAt = Date()
        }
        openDetail(.paymentWaiting)
        startPaymentStatusPolling()
    }

    public func startPaymentStatusPolling() {
        stopPaymentStatusPolling()
        paymentPollTask = Task { @MainActor in
            while !Task.isCancelled {
                await pollOpenPaymentsOnce()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    public func stopPaymentStatusPolling() {
        paymentPollTask?.cancel()
        paymentPollTask = nil
    }

    /// Resume open checkouts without yanking the user into `.paymentWaiting`
    /// from unrelated screens (home / management / locations / account).
    /// Pass `forceWaitingUI: true` only when returning from the bank / pay URL.
    public func resumeOpenPaymentsIfNeeded(forceWaitingUI: Bool = false) {
        guard !PendingCheckout.openPaymentIDs.isEmpty else { return }
        if let page = detailPage {
            switch page {
            case .payment, .balanceAccount, .balanceTopUp, .paymentError, .paymentCancelled, .paymentSuccess, .paymentProcessing,
                 .authLogin, .authEmail, .authCode, .authRegister, .authRecovery, .authBot,
                 .authPhone, .authPhoneCode, .authSuccess, .premiumPlans, .planConstructor, .addOns, .accessChoice:
                // Stay on the current auth/checkout screen; poll in background.
                startPaymentStatusPolling()
                return
            case .paymentWaiting:
                startPaymentStatusPolling()
                return
            case .externalPay:
                return
            default:
                break
            }
        }
        if forceWaitingUI {
            beginPaymentWaiting()
        } else {
            startPaymentStatusPolling()
        }
    }

    @MainActor
    private func pollOpenPaymentsOnce() async {
        DirectBackendRuntime.warmUp()
        var ids = PendingCheckout.openPaymentIDs
        if let current = lastPaymentId, !ids.contains(current) {
            ids.append(current)
        }
        guard !ids.isEmpty else { return }

        if let started = paymentWaitStartedAt, Date().timeIntervalSince(started) > 2 * 60 * 60 {
            paymentWaitingTimedOut = true
            paymentWaitingSubtitle = "Ожидаем подтверждения со стороны банка. Зайдите позже или свяжитесь с вашим банком."
        }

        for id in ids {
            do {
                DirectBackendRuntime.warmUp()
                guard let fetch = DirectBackendRuntime.checkoutStatus else { return }
                let status = try await fetch(id)
                let st = (status.status ?? "").lowercased()
                if st == "paid" || st == "paid_unfulfilled" {
                    if status.fulfilled == true || status.hasSubscription == true {
                        await applyPaidFromHooks(status: status, paymentId: id)
                        return
                    }
                    // Paid but grant still in flight — show success with refresh CTA, keep polling.
                    paymentActivationPending = true
                    paymentWaitingSubtitle = "Оплата прошла, активируем подписку…"
                    if detailPage == .paymentWaiting || detailPage == .paymentProcessing {
                        lastSuccessTitle = status.title ?? checkoutTitle
                        lastSuccessPrice = status.amount ?? checkoutPrice
                        openDetail(.paymentSuccess)
                    }
                } else if ["canceled", "cancelled", "failed", "expired"].contains(st) {
                    PendingCheckout.forgetPaymentID(id)
                    if id == lastPaymentId {
                        stopPaymentStatusPolling()
                        // Only surface cancel UI when the user is already waiting on payment.
                        if detailPage == .paymentWaiting || detailPage == .paymentProcessing {
                            openDetail(.paymentCancelled)
                        }
                        return
                    }
                } else if st == "timeout" {
                    paymentWaitingTimedOut = true
                    paymentWaitingSubtitle = "Ожидаем подтверждения со стороны банка. Зайдите позже или свяжитесь с вашим банком."
                } else {
                    paymentWaitingSubtitle = "Статус: ожидание ответа банка…"
                }
            } catch {
                // Keep waiting — network blips during bank app switch are normal.
            }
        }
    }

    @MainActor
    private func applyPaidFromHooks(status: DirectCheckoutStatus, paymentId: String) async {
        stopPaymentStatusPolling()
        DirectBackendRuntime.warmUp()
        if let apply = DirectBackendRuntime.applyPaidCheckout {
            await apply(self, status, paymentId)
            return
        }
        if let url = status.subscriptionUrl, !url.isEmpty {
            directSubscriptionURL = url
            await attachDirectSubscription(url: url)
        }
        let pending = PendingCheckout.current
        applyLocalPremiumFromCheckout(pending: pending)
        paymentActivationPending = false
        PendingCheckout.forgetPaymentID(paymentId)
        clearPendingCheckout()
        openDetail(.paymentSuccess)
    }

    /// Renew current Direct tariff via catalog quote (same path as first purchase).
    /// Entry source is `.renewActive` so payment shows the active plan, not a browsed catalog pick.
    @MainActor
    public func beginRenewCheckout() async {
        DirectBackendRuntime.warmUp()
        // Prefer local last-paid immediately; refresh account only when renew context is missing.
        if LastPaidCatalogCheckout.current == nil, isDirectAuthenticated {
            await refreshDirectAccount()
        }
        if appCatalog == nil || (appCatalog?.tariffs.isEmpty ?? true) {
            await refreshAppCatalog()
        }

        let last = LastPaidCatalogCheckout.current
        let days = renewPeriodDays(last: last)
        guard let tariff = renewTariff(last: last) else {
            openPremiumPlans(mode: .presets)
            return
        }

        var price = scaledCatalogPrice(tariff: tariff, days: days)
        if let quote = DirectBackendRuntime.quoteCheckout {
            do {
                let q = try await quote(
                    DirectCheckoutQuoteRequest(
                        productKind: "app_tariff",
                        tariffID: tariff.id,
                        days: days,
                        devices: tariff.devices,
                        trafficGB: tariff.trafficGB
                    )
                )
                price = q.amount
            } catch {
                HapticManager.shared.play(.networkError)
            }
        }

        let config = PlanConfiguration(
            name: tariff.name,
            days: days,
            devices: tariff.devices,
            trafficGB: tariff.trafficGB,
            whitelistGB: 0
        )
        applySelectedPlan(config, presetID: "app-\(tariff.id)", playHaptic: false)
        setActivePlanName(tariff.name)
        checkoutPrice = price
        checkoutTitle = Self.checkoutTitle(for: config)
        checkoutEntrySource = .renewActive
        checkoutReturnPage = .premiumPlans
        pendingCheckoutTariffID = tariff.id
        let pending = PendingCheckout(
            title: tariff.name,
            price: price,
            periodDays: days,
            paymentMethodRaw: paymentMethod.rawValue,
            returnPage: String(describing: DetailPage.premiumPlans),
            planName: tariff.name,
            trafficGB: tariff.trafficGB,
            devices: tariff.devices,
            whitelistGB: 0,
            createdAt: Date(),
            productKind: "app_tariff",
            tariffID: tariff.id,
            addonDays: nil,
            addonDevices: nil,
            addonTrafficGB: nil
        )
        PendingCheckout.save(pending)
        LastPaidCatalogCheckout.remember(from: pending)
        if VPNDirectPlanCatalog.presetPeriodDays.contains(days) {
            UserDefaults.standard.set(days, forKey: Self.premiumPeriodDaysKey)
        }
        openDetail(.payment)
    }

    /// Period for renew: last paid / stored — never browsed `selectedPlan.days` (often START 30).
    private func renewPeriodDays(last: LastPaidCatalogCheckout?) -> Int {
        let storedPeriod = UserDefaults.standard.integer(forKey: Self.premiumPeriodDaysKey)
        let candidates = [
            last?.periodDays ?? 0,
            storedPeriod,
            lastSuccessPeriodDays,
        ]
        for days in candidates where VPNDirectPlanCatalog.presetPeriodDays.contains(days) {
            return days
        }
        return 30
    }

    /// Active tariff for renew: last paid id → entitlement devices/traffic → last paid name.
    /// Ignores browsed `selectedPlan` / stale `pendingCheckoutTariffID` (e.g. earlier START tap).
    private func renewTariff(last: LastPaidCatalogCheckout?) -> DirectAppTariff? {
        let tariffs = appCatalog?.tariffs ?? []
        if let id = last?.tariffID,
           let match = tariffs.first(where: { $0.id == id })
        {
            return match
        }
        let devices = premiumDeviceLimit > 0 ? premiumDeviceLimit : (last?.devices ?? 0)
        let traffic: Int? = {
            if let last {
                return last.trafficGB
            }
            if premiumTrafficGB >= Self.unlimitedTrafficGB { return nil }
            return premiumTrafficGB > 0 ? premiumTrafficGB : nil
        }()
        if devices > 0 {
            let byDevices = tariffs.filter { $0.devices == devices }
            if let match = byDevices.first(where: { Self.sameTraffic($0.trafficGB, traffic) }) {
                return match
            }
            // Unlimited grants often leave local traffic as a stale finite value — prefer ∞ pack.
            if premiumTrafficGB >= Self.unlimitedTrafficGB || last?.trafficGB == nil,
               let match = byDevices.first(where: { $0.trafficGB == nil })
            {
                return match
            }
            if byDevices.count == 1 {
                return byDevices[0]
            }
        }
        let name = (last?.planName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty,
           let match = tariffs.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
        {
            return match
        }
        return nil
    }

    private static func sameTraffic(_ a: Int?, _ b: Int?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return x == y
        default: return false
        }
    }

    private func scaledCatalogPrice(tariff: DirectAppTariff, days: Int) -> Int {
        let months = Double(days) / Double(max(tariff.days, 1))
        let mult = appCatalog?.monthMultipliers[days]
            ?? VPNDirectPricingEngine.durationMultiplier(forDays: days)
        return max(49, Int((Double(tariff.price) * months * mult / 10).rounded() * 10))
    }

    /// Seed last-paid renew context from the account profile (server source of truth).
    func rememberLastPaidFromServer(
        tariffID: Int?,
        planName: String?,
        title: String?,
        amount: Int?,
        periodDays: Int?,
        devices: Int?,
        trafficGB: Int?,
        productKind: String?
    ) {
        guard let tariffID, tariffID > 0 else { return }
        let period = periodDays ?? 30
        let deviceCount = max(1, devices ?? premiumDeviceLimit)
        let pending = PendingCheckout(
            title: title ?? planName ?? "VPN Direct",
            price: max(0, amount ?? 0),
            periodDays: period,
            paymentMethodRaw: paymentMethod.rawValue,
            returnPage: String(describing: DetailPage.premiumPlans),
            planName: planName ?? title,
            trafficGB: trafficGB,
            devices: deviceCount,
            whitelistGB: 0,
            createdAt: Date(),
            productKind: productKind ?? "app_tariff",
            tariffID: tariffID,
            addonDays: nil,
            addonDevices: nil,
            addonTrafficGB: nil
        )
        LastPaidCatalogCheckout.remember(from: pending)
        if VPNDirectPlanCatalog.presetPeriodDays.contains(period) {
            UserDefaults.standard.set(period, forKey: Self.premiumPeriodDaysKey)
        }
        setActivePlanName(planName ?? title)
        lastSuccessPeriodDays = period
        if let name = planName ?? title, !name.isEmpty {
            lastSuccessTitle = name
        }
        if let amount, amount > 0 {
            lastSuccessPrice = amount
        }
    }

    func syncSelectedPlanFromActiveSubscription() {
        let last = LastPaidCatalogCheckout.current
        let days: Int = {
            if let d = last?.periodDays, VPNDirectPlanCatalog.presetPeriodDays.contains(d) { return d }
            let stored = UserDefaults.standard.integer(forKey: Self.premiumPeriodDaysKey)
            if VPNDirectPlanCatalog.presetPeriodDays.contains(stored) { return stored }
            return selectedPlan.days
        }()
        let traffic: Int? = premiumTrafficGB >= Self.unlimitedTrafficGB ? nil : premiumTrafficGB
        let name = last?.planName ?? (activePlanName.isEmpty ? selectedPlan.name : activePlanName)
        selectedPlan = PlanConfiguration(
            name: name,
            days: days,
            devices: premiumDeviceLimit > 0 ? premiumDeviceLimit : selectedPlan.devices,
            trafficGB: traffic,
            whitelistGB: premiumWhitelistGB
        )
        if let id = last?.tariffID {
            pendingCheckoutTariffID = id
        }
        if let name, !name.isEmpty {
            setActivePlanName(name)
        }
    }

    public func refreshAppCatalog() async {
        DirectBackendRuntime.warmUp()
        do {
            // Hard ceiling so a stalled catalog never freezes bootstrap / pull-to-refresh.
            // Force-update is live from this response only — no disk/URL cache.
            let catalog = try await withThrowingTaskGroup(of: DirectAppCatalog.self) { group in
                group.addTask {
                    try await DirectBackendRuntime.fetchAppCatalog()
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 12_000_000_000)
                    throw CancellationError()
                }
                let first = try await group.next()!
                group.cancelAll()
                return first
            }
            appCatalog = catalog
            evaluateForceUpdateGate()
        } catch {
            // Network/timeout: keep previous catalog. Never invent a force-update from cache.
            if appCatalog == nil {
                forceUpdateRequirement = nil
            } else {
                evaluateForceUpdateGate()
            }
        }
    }

    public func evaluateForceUpdateGate() {
        forceUpdateRequirement = DirectAppVersionGate.evaluate(catalog: appCatalog)
    }

    /// Pull-to-refresh for every Direct screen except the home tab.
    public func performPullToRefresh() async {
        // Refresh remote sub BEFORE reloading local graphs — parallel reload raced the old cache.
        if isDirectAuthenticated {
            await refreshDirectAccount()
        } else if let url = directSubscriptionURL, !url.isEmpty {
            await attachDirectSubscription(url: url)
        }
        async let catalog: Void = refreshAppCatalog()
        async let locs: Void = DirectLocationsCatalog.shared.refreshFromBackendIfNeeded(force: true)
        await reloadSubscriptions()
        _ = await (catalog, locs)
        syncFromExtension()
        refreshPublicIP()
        if detailPage == .locations {
            requestURLTest()
        }
        HapticManager.shared.play(.selection)
    }

    /// Gate: guest path ends at payment method; auth required only when charging.
    public func requestCheckoutPayment() {
        savePendingCheckout()
        HapticManager.shared.play(.purchaseStarted)
        if !isDirectAuthenticated {
            authFlowReturnsToAccount = false
            checkoutAuthError = nil
            openDetail(.authLogin)
            return
        }
        Task { await startAuthenticatedCheckout() }
    }

    public func continueCheckoutAfterAuth() {
        openDetail(.payment)
        Task { await startAuthenticatedCheckout() }
    }

    public func startAuthenticatedCheckout() async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.startCheckout {
            await run(self)
            return
        }
        paymentErrorMessage = "Сервис оплаты недоступен"
        openDetail(.paymentError)
        HapticManager.shared.play(.error)
    }

    public func cancelExternalCheckout() {
        openDetail(.paymentCancelled)
    }

    public func retryCheckout() {
        Task { await startAuthenticatedCheckout() }
    }

    public func finalizeCheckoutSuccess(paymentId: String) async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.finalizeCheckout {
            await run(self, paymentId)
            return
        }
        paymentErrorMessage = "Сервис оплаты недоступен"
        openDetail(.paymentError)
        HapticManager.shared.play(.error)
    }

    public func logoutDirectAccount() async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.logout {
            await run(self)
            return
        }
        clearDirectSessionState()
    }

    /// Independent accounts: warn before replacing the current session with another login method.
    public func requestAuthDestination(_ page: DetailPage) {
        checkoutAuthError = nil
        pendingSocialAuth = nil
        if isDirectAuthenticated {
            pendingAuthDestination = page
            authAccountSwitchWarning = true
            return
        }
        openDetail(page)
    }

    public func requestSocialAuth(_ kind: SocialAuthKind) {
        checkoutAuthError = nil
        pendingAuthDestination = nil
        if isDirectAuthenticated {
            pendingSocialAuth = kind
            authAccountSwitchWarning = true
            return
        }
        Task {
            switch kind {
            case .apple: await signInWithAppleForAuth()
            case .google: await signInWithGoogleForAuth()
            }
        }
    }

    public func confirmAccountSwitchAndContinue() {
        authAccountSwitchWarning = false
        if let social = pendingSocialAuth {
            pendingSocialAuth = nil
            pendingAuthDestination = nil
            Task {
                switch social {
                case .apple: await signInWithAppleForAuth()
                case .google: await signInWithGoogleForAuth()
                }
            }
            return
        }
        guard let page = pendingAuthDestination else { return }
        pendingAuthDestination = nil
        openDetail(page)
    }

    public func cancelAccountSwitch() {
        authAccountSwitchWarning = false
        pendingAuthDestination = nil
        pendingSocialAuth = nil
    }

    public var authMethodLabel: String {
        switch (directAuthMethod ?? "").lowercased() {
        case "telegram", "telegram_bot": return "Telegram"
        case "phone": return "Телефон"
        case "apple": return "Apple"
        case "google": return "Google"
        case "email": return "Email"
        default:
            if directAccountKind == "telegram" { return "Telegram" }
            if let phone = directAccountPhone, !phone.isEmpty { return "Телефон" }
            if let email = directAccountEmail, !email.isEmpty { return "Email" }
            return "Direct"
        }
    }

    public var accountDisplayTitle: String {
        if let phone = directAccountPhone, !phone.isEmpty { return phone }
        if let email = directAccountEmail,
           !email.isEmpty,
           !email.hasSuffix("@phone.privatedirect"),
           !email.hasSuffix("@apple.privatedirect"),
           !email.hasSuffix("@google.privatedirect") {
            return email
        }
        if let name = directAccountUsername, !name.isEmpty { return name }
        return authMethodLabel
    }

    public func refreshDirectAccount() async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.refreshAccount {
            await run(self)
        }
    }

    func sendEmailCodeForAuth(email: String) async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.sendEmailCode {
            await run(self, email)
            return
        }
        checkoutAuthError = "Сервис входа недоступен"
    }

    func resendEmailCodeForAuth() async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.resendEmailCode {
            await run(self)
            return
        }
        checkoutAuthError = "Сервис входа недоступен"
    }

    func verifyEmailCodeForAuth() async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.verifyEmailCode {
            await run(self)
            return
        }
        checkoutAuthError = "Сервис входа недоступен"
    }

    func linkBotCodeForAuth() async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.linkBotCode {
            await run(self)
            return
        }
        checkoutAuthError = "Сервис входа недоступен"
    }

    func requestBotLoginConfirmForAuth(identifier: String) async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.requestBotLoginConfirm {
            await run(self, identifier)
            return
        }
        checkoutAuthError = "Сервис входа недоступен"
    }

    func sendPhoneCodeForAuth(phone: String) async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.sendPhoneCode {
            await run(self, phone)
            return
        }
        checkoutAuthError = "Сервис входа недоступен"
    }

    func verifyPhoneCodeForAuth() async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.verifyPhoneCode {
            await run(self)
            return
        }
        checkoutAuthError = "Сервис входа недоступен"
    }

    func signInWithAppleForAuth() async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.signInWithApple {
            await run(self)
            return
        }
        checkoutAuthError = "Сервис входа недоступен"
    }

    func signInWithGoogleForAuth() async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.signInWithGoogle {
            await run(self)
            return
        }
        checkoutAuthError = "Сервис входа недоступен"
    }

    func loginWithPasswordForAuth(email: String, password: String) async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.loginWithPassword {
            await run(self, email, password)
            return
        }
        checkoutAuthError = "Сервис входа недоступен"
    }

    func registerWithPasswordForAuth(
        name: String,
        email: String,
        password: String,
        confirmation: String
    ) async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.registerWithPassword {
            await run(self, name, email, password, confirmation)
            return
        }
        checkoutAuthError = "Сервис входа недоступен"
    }

    func requestPasswordResetForAuth(email: String) async -> Bool {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.requestPasswordReset {
            return await run(self, email)
        }
        checkoutAuthError = "Сервис входа недоступен"
        return false
    }

    public func attachDirectSubscription(url: String) async {
        guard let environments else { return }
        do {
            let profile = try await AutoSubscriptionImporter.importIfNeeded(url: url, environments: environments)
            await reloadSubscriptions()
            if let profile,
               let item = subscriptions.first(where: { $0.id == profile.mustID })
            {
                setActiveAccess(.premium)
                activate(subscriptionID: item.id)
                return
            }
            if let item = subscriptions.first(where: {
                DirectBuiltinProfile.isDirectOwned($0.profile.remoteURL)
                    && !DirectBuiltinProfile.isBuiltin($0.profile.remoteURL)
            }) {
                setActiveAccess(.premium)
                activate(subscriptionID: item.id)
            }
        } catch {
            paymentErrorMessage = error.localizedDescription
        }
    }

    /// Legacy local entitlement helper used after backend grant (or offline fallback).
    public func completeCheckout() {
        requestCheckoutPayment()
    }

    func applyLocalPremiumFromCheckout(pending: PendingCheckout?) {
        if checkoutReturnPage == .addOns {
            if pendingAddOnTrafficGB > 0 {
                if premiumTrafficGB < Self.unlimitedTrafficGB {
                premiumTrafficGB += pendingAddOnTrafficGB
                    if let remaining = premiumTrafficRemainingGB {
                        premiumTrafficRemainingGB = remaining + pendingAddOnTrafficGB
                    }
                }
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
            premiumRemainingDays = pending?.periodDays ?? selectedPlan.days
            if let gb = pending?.trafficGB ?? selectedPlan.trafficGB {
                premiumTrafficGB = gb
                premiumTrafficRemainingGB = gb
            } else {
                premiumTrafficGB = Self.unlimitedTrafficGB
                premiumTrafficRemainingGB = nil
            }
            premiumWhitelistGB = pending?.whitelistGB ?? selectedPlan.whitelistGB
            premiumDeviceLimit = max(1, pending?.devices ?? selectedPlan.devices)
            premiumDevicesUsed = min(premiumDevicesUsed, premiumDeviceLimit)
            if let pending {
                LastPaidCatalogCheckout.remember(from: pending)
                setActivePlanName(pending.planName ?? pending.title)
                if VPNDirectPlanCatalog.presetPeriodDays.contains(pending.periodDays) {
                    UserDefaults.standard.set(pending.periodDays, forKey: Self.premiumPeriodDaysKey)
                }
            } else if VPNDirectPlanCatalog.presetPeriodDays.contains(selectedPlan.days) {
                UserDefaults.standard.set(selectedPlan.days, forKey: Self.premiumPeriodDaysKey)
                setActivePlanName(selectedPlan.name)
            }
        }
        persistPremiumState()
        setActiveAccess(.premium)
        if let premiumID = premiumProfileID {
            activate(subscriptionID: premiumID)
        }
    }

    private static func checkoutTitle(for plan: PlanConfiguration) -> String {
        let period = VPNDirectPlanCatalog.periodLabel(days: plan.days)
        if let name = plan.name, !name.isEmpty {
            return "\(name) · \(period)"
        }
        return "Свой тариф · \(period)"
    }

    func setActiveAccess(_ source: AccessSource) {
        activeAccess = source
        Self.saveAccessSource(source)
    }

    private func persistFreeBalance() {
        UserDefaults.standard.set(freeHours, forKey: Self.freeHoursKey)
        UserDefaults.standard.set(freeTrafficMB, forKey: Self.freeTrafficKey)
        if let expires = freeExpiresAt {
            UserDefaults.standard.set(expires.timeIntervalSince1970, forKey: Self.freeExpiresAtKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.freeExpiresAtKey)
        }
    }

    func persistPremiumState() {
        UserDefaults.standard.set(hasPremiumEntitlement, forKey: Self.premiumEntitlementKey)
        UserDefaults.standard.set(premiumRemainingDays, forKey: Self.premiumDaysKey)
        UserDefaults.standard.set(premiumTrafficGB, forKey: Self.premiumTrafficKey)
        if let remaining = premiumTrafficRemainingGB {
            UserDefaults.standard.set(remaining, forKey: Self.premiumTrafficRemainingKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.premiumTrafficRemainingKey)
        }
        UserDefaults.standard.set(premiumWhitelistGB, forKey: Self.premiumWhitelistKey)
        UserDefaults.standard.set(premiumDevicesUsed, forKey: Self.premiumDevicesUsedKey)
        UserDefaults.standard.set(premiumDeviceLimit, forKey: Self.premiumDeviceLimitKey)
        UserDefaults.standard.set(autoRenewPremium, forKey: Self.premiumAutoRenewKey)
        if VPNDirectPlanCatalog.presetPeriodDays.contains(selectedPlan.days) {
            UserDefaults.standard.set(selectedPlan.days, forKey: Self.premiumPeriodDaysKey)
        }
        if !activePlanName.isEmpty {
            UserDefaults.standard.set(activePlanName, forKey: Self.activePlanNameKey)
        }
    }

    func setActivePlanName(_ name: String?) {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        activePlanName = trimmed
        UserDefaults.standard.set(trimmed, forKey: Self.activePlanNameKey)
    }

    public func persistAutoRenewPreference() {
        UserDefaults.standard.set(autoRenewPremium, forKey: Self.premiumAutoRenewKey)
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
                environments?.commandClient.connect()
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            do {
                try await applyConnectionModeBehavior(force: true)
            if isConnected {
                    await refreshAssignedFromGroups()
                    await mergeLivePings()
                    try? await Task.sleep(nanoseconds: 450_000_000)
                phase = .idle
                HapticManager.shared.play(.vpnSwitched)
                }
            } catch {
                phase = .idle
                alert = AlertState(action: "сменить режим подключения", error: error)
                HapticManager.shared.play(.error)
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
        let storedMode = await SharedPreferences.connectionMode.get()
        connectionMode = Self.normalizedConnectionMode(storedMode)
        if connectionMode != storedMode {
            await SharedPreferences.connectionMode.set(connectionMode)
        }
    }

    private static func normalizedConnectionMode(_ mode: String) -> String {
        mode == "Антиблокировка" ? "5G" : mode
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
        guard !isRefreshingSubscription else { return }
        isRefreshingSubscription = true
        HapticManager.shared.play(.selection)
        Task {
            defer {
                Task { @MainActor in self.isRefreshingSubscription = false }
            }
            do {
                guard let profile = try await ProfileManager.get(subscriptionID) else {
                    await MainActor.run {
                        self.alert = AlertState(errorMessage: String(localized: "Подписка не найдена."))
                    }
                    return
                }
                if DirectBuiltinProfile.isBuiltin(profile.remoteURL) {
                    await MainActor.run {
                        self.alert = AlertState(errorMessage: String(localized: "Встроенные подписки VPN Direct обновляются отдельно."))
                    }
                    return
                }
                guard profile.type == .remote,
                      let url = profile.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !url.isEmpty
                else {
                    await MainActor.run {
                        self.alert = AlertState(errorMessage: String(localized: "Обновить можно только удалённую подписку по ссылке."))
                    }
                    return
                }
                _ = url
                try await profile.updateRemoteProfile()
                environments?.profileUpdate.send()
                environments?.selectedProfileUpdate.send()
                await reloadSubscriptions()
                // If this profile is active and VPN is up, reload tunnel with fresh nodes.
                if await SharedPreferences.selectedProfileID.get() == subscriptionID,
                   let extensionProfile = try? await ExtensionProfile.load(),
                   await extensionProfile.status.isConnected
                {
                    try? await extensionProfile.reloadService()
                }
                await MainActor.run {
                    HapticManager.shared.play(.imported)
                }
            } catch {
                await MainActor.run {
                    self.alert = AlertState(action: "обновить подписку", error: error)
                    HapticManager.shared.play(.error)
                }
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

                // If this profile is in the VPN client — disconnect, clear selection, then delete.
                let selectedProfileID = await SharedPreferences.selectedProfileID.get()
                let isActiveInClient = activeSubscriptionID == subscriptionID
                    || selectedProfileID == subscriptionID
                if isActiveInClient {
                    connectTimeoutTask?.cancel()
                    connectPollTask?.cancel()
                    isStarting = false
                    connectTimeoutExtended = false
                    if let ext = environments?.extensionProfile {
                        ext.refreshStatus()
                        let status = ext.status
                        let needsStop = status.isConnected
                            || status == .connecting
                            || status == .reasserting
                            || phase == .connecting
                            || phase == .disconnecting
                            || phase == .switching
                        if needsStop {
                            HapticManager.shared.play(.vpnDisconnecting)
                            phase = .disconnecting
                            try? await ext.updateOnDemand(enabled: false, useDefaultRules: false)
                            try? await ext.stop()
                        }
                    }
                    phase = .idle
                    isConnected = false
                    activeSubscriptionID = 0
                    selectedServerID = nil
                    assignedServerID = nil
                    await SharedPreferences.selectedProfileID.set(-1)
                    await SharedPreferences.preferredOutboundTag.set("")
                    await disableVPNAutoConnect()
                    syncFromExtension()
                }

                try await ProfileManager.delete(profile)
                if detailPage == .subscription(subscriptionID) {
                    closeDetail()
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
                HapticManager.shared.play(.selection)
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

    private func applyConnectionModeBehavior(force: Bool = false) async throws {
        guard let servers = activeSubscription?.servers, !servers.isEmpty else { return }
        let usable = servers.filter { !isLocationCapExhausted($0) }
        let pool = usable.isEmpty ? servers : usable
        let groupTag = resolveSelectorGroupTag(fallback: activeServer?.groupTag ?? pool.first!.groupTag)

        switch connectionMode {
        case "Авто":
            selectedServerID = nil
            await SharedPreferences.preferredOutboundTag.set("")
            guard isConnected else { return }
            let autoTag = outboundExists(inGroup: groupTag, tag: "auto") ? "auto" : (pool.first?.id ?? "auto")
            // Prefer a concrete non-exhausted outbound over urltest `auto` when caps are exhausted.
            if autoTag == "auto", !usable.isEmpty, usable.count < servers.count {
                if let best = usable.filter({ $0.ping > 0 }).min(by: { $0.ping < $1.ping }) ?? usable.first {
                    try await commitServerPick(best, manualSelection: false)
                    return
                }
            }
            try await LibboxNewStandaloneCommandClient()!.selectOutbound(groupTag, outboundTag: autoTag)
            try? await LibboxNewStandaloneCommandClient()!.urlTest(autoTag == "auto" ? "auto" : groupTag)
                try? await Task.sleep(nanoseconds: 400_000_000)
                await refreshAssignedFromGroups()
                await mergeLivePings()
        case "Пользовательский":
            // Stick to the manually chosen outbound; never fall back to urltest `auto`.
            let stickyID = selectedServerID
                ?? assignedServerID.flatMap { id in pool.contains(where: { $0.id == id }) ? id : nil }
            if let stickyID, let server = pool.first(where: { $0.id == stickyID }), !isLocationCapExhausted(server) {
                try await commitServerPick(server, manualSelection: true)
            } else if let first = pool.first {
                try await commitServerPick(first, manualSelection: true)
            }
        case "Максимальная скорость":
            try await pickAndApplyServer(
                groupTag: groupTag,
                manualSelection: true,
                preferFreshPings: true,
                chooser: { list in
                    let filtered = list.filter { !self.isLocationCapExhausted($0) }
                    let src = filtered.isEmpty ? list : filtered
                    return src.filter { $0.ping > 0 }.min(by: { $0.ping < $1.ping }) ?? src.first
                }
            )
        case "Стабильный":
            let sticky = assignedServerID.flatMap { id in pool.contains(where: { $0.id == id }) ? id : nil }
                ?? selectedServerID.flatMap { id in pool.contains(where: { $0.id == id }) ? id : nil }
                ?? pool.first?.id
            if let sticky, let server = pool.first(where: { $0.id == sticky }) {
                try await commitServerPick(server, manualSelection: true)
            }
        case "Для видео":
            try await pickAndApplyServer(
                groupTag: groupTag,
                manualSelection: true,
                preferFreshPings: true,
                chooser: { list in
                    let filtered = list.filter { !self.isLocationCapExhausted($0) }
                    let src = filtered.isEmpty ? list : filtered
                    let stable = src.filter { $0.ping >= 40 && $0.ping <= 180 }
                    return stable.min(by: { $0.load < $1.load })
                        ?? src.filter { $0.ping > 0 }.min(by: { $0.ping < $1.ping })
                        ?? src.first
                }
            )
        case "5G", "Антиблокировка":
            try await pickAndApplyServer(
                groupTag: groupTag,
                manualSelection: true,
                preferFreshPings: true,
                chooser: { [assignedServerID, selectedServerID] list in
                    let pool = list.filter {
                        VPNServerNameParser.matchesAntiBlockOrMobileProfile($0) && !self.isLocationCapExhausted($0)
                    }
                    guard !pool.isEmpty else { return nil }
                    let sorted = pool.filter { $0.ping > 0 }.sorted(by: { $0.ping < $1.ping })
                    let ranked = sorted.isEmpty ? pool : sorted
                    let current = assignedServerID ?? selectedServerID
                    return ranked.first(where: { $0.id != current }) ?? ranked.first
                }
            )
        default:
            if force { break }
        }
    }

    private func resolveSelectorGroupTag(fallback: String) -> String {
        guard let groups = environments?.commandClient.groups else { return fallback }
        let selectable = groups.filter { $0.selectable }
        if let group = selectable.first(where: { $0.type == "selector" }) ?? selectable.first {
            return group.tag
        }
        return fallback
    }

    private func outboundExists(inGroup groupTag: String, tag: String) -> Bool {
        guard let groups = environments?.commandClient.groups,
              let group = groups.first(where: { $0.tag == groupTag }),
              let iterator = group.getItems()
        else {
            // Groups not loaded yet — assume graph has `auto` (TheTochka/Happ layout).
            return tag == "auto"
        }
        while iterator.hasNext() {
            if iterator.next()?.tag == tag { return true }
        }
        return false
    }

    private func pickAndApplyServer(
        groupTag: String,
        manualSelection: Bool,
        preferFreshPings: Bool,
        chooser: @escaping ([VPNServer]) -> VPNServer?
    ) async throws {
        var servers = activeSubscription?.servers ?? []
        if preferFreshPings, isConnected, !servers.contains(where: { $0.ping > 0 }) {
            try? await LibboxNewStandaloneCommandClient()!.urlTest(groupTag)
            try? await LibboxNewStandaloneCommandClient()!.urlTest("auto")
            try? await Task.sleep(nanoseconds: 450_000_000)
            await mergeLivePings()
            servers = activeSubscription?.servers ?? []
        }
        if let pick = chooser(servers) {
            try await commitServerPick(pick, manualSelection: manualSelection)
        }
        guard isConnected else { return }
            try? await LibboxNewStandaloneCommandClient()!.urlTest(groupTag)
        try? await Task.sleep(nanoseconds: 350_000_000)
            await mergeLivePings()
            let refreshed = activeSubscription?.servers ?? []
            if let pick = chooser(refreshed) {
            try await commitServerPick(pick, manualSelection: manualSelection)
        }
    }

    private func commitServerPick(_ server: VPNServer, manualSelection: Bool) async throws {
        if manualSelection {
            selectedServerID = server.id
            assignedServerID = server.id
            await SharedPreferences.preferredOutboundTag.set(server.id)
            await reportMeteringActiveLocation(serverID: server.id)
        } else {
            selectedServerID = nil
            assignedServerID = server.id
            await SharedPreferences.preferredOutboundTag.set("")
            await reportMeteringActiveLocation(serverID: nil)
        }
        guard isConnected else { return }
        let groupTag = resolveSelectorGroupTag(fallback: server.groupTag)
        try await LibboxNewStandaloneCommandClient()!.selectOutbound(groupTag, outboundTag: server.id)
    }

    public func bind(_ environments: ExtensionEnvironments) {
        self.environments = environments
        syncFromExtension()
        guard !didBind else { return }
        didBind = true
        Task {
            // Do NOT disable NE profiles on every cold start — that leaves status `.invalid`
            // and dial silently no-ops on `guard profile.status.isEnabled`.
            await SharedPreferences.includeAllNetworks.set(false)
            let resetKey = "direct.neProfileReset.v51"
            if !UserDefaults.standard.bool(forKey: resetKey) {
            await ExtensionProfile.disableAllSavedProfiles()
                environments.extensionProfile = nil
                UserDefaults.standard.set(true, forKey: resetKey)
            }
            await SingBoxConfigMigrator.migrateAllStoredProfiles()
            await loadSecuritySettings()
            autoConnect = false
            unknownWiFi = false
            await SharedPreferences.alwaysOn.set(false)
            await SharedPreferences.onDemandEnabled.set(false)
            // Build 53 force-cleared this preference — restore default ON once.
            let bypassRestoreKey = "direct.bypassRestore.v54"
            if !UserDefaults.standard.bool(forKey: bypassRestoreKey) {
                await SharedPreferences.bypassRussianSites.set(true)
                bypassRussianSites = true
                UserDefaults.standard.set(true, forKey: bypassRestoreKey)
            }
            await refreshCurrentWifi()
            let stored = await SharedPreferences.preferredOutboundTag.get()
            selectedServerID = stored.isEmpty ? nil : stored
            let storedMode = await SharedPreferences.connectionMode.get()
            connectionMode = Self.normalizedConnectionMode(storedMode)
            if connectionMode != storedMode {
                await SharedPreferences.connectionMode.set(connectionMode)
            }
            await reloadSubscriptions()
            DirectBackendRuntime.warmUp()
            if let run = DirectBackendRuntime.bootstrapSession {
                await run(self)
            }
            await refreshAppCatalog()
            try? await environments.ensureExtensionProfileReady()
            await applySecuritySettings()
            await migrateUrlTestBalancerIfNeeded()
            await migrateUrlTestToleranceIfNeeded()
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
            connectSawConnecting = true
            if phase == .idle { phase = .connecting }
            isConnected = false
        case .connected, .reasserting:
            connectTimeoutTask?.cancel()
            connectTimeoutTask = nil
            connectPollTask?.cancel()
            connectPollTask = nil
            isStarting = false
            connectSawConnecting = false
            let becameConnected = !wasConnected
            isConnected = true
            let shouldApplyMode = phase == .connecting
            phase = .idle
            alert = nil
            environments?.commandClient.connect()
            Task {
                // Only baseline on a real connect. Re-baselining on every foreground
                // sync zeroes the live TRAFFIC counter while the tunnel stays up.
                if becameConnected {
                    resetSessionTrafficBaseline()
                }
                await refreshAssignedFromGroups()
                if shouldApplyMode {
                    try? await applyConnectionModeBehavior(force: true)
                }
            }
        case .disconnecting:
            if phase == .idle { phase = .disconnecting }
            isConnected = false
        case .disconnected:
            persistSessionTrafficDelta()
            sessionTrafficBaseline = 0
            lastSessionTrafficTotal = 0
            if isStarting || phase == .connecting {
                // Do NOT kill the dial here. Extension start can take several seconds
                // (rule-set download); a premature cancel stops a healthy tunnel
                // (NEProviderStopReason.userInitiated) right after startService OK.
                // Timeout / polling handles real failures.
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

        // Keep home widget / Control Center in sync even when NE status is flaky there.
        publishWidgetStatus(connected: isConnected)

        if isConnected, !wasConnected {
            HapticManager.shared.play(.vpnConnected)
            DirectAppReviewPrompt.scheduleAfterSuccessfulConnect()
            // Fresh egress IP after tunnel is up (not the cached pre-connect WAN IP).
            Task {
                try? await Task.sleep(nanoseconds: 800_000_000)
                refreshPublicIP()
            }
        } else if !isConnected, wasConnected, wasPhase != .switching, !isStarting,
                  environments?.extensionProfile?.status == .disconnected
        {
            HapticManager.shared.play(.vpnDisconnected)
            refreshPublicIP()
        }
    }

    private func publishWidgetStatus(connected: Bool) {
        let server = activeServer
        DirectWidgetStatusBridge.publish(
            connected: connected,
            serverName: connected ? (server?.city ?? activeSubscription?.name ?? "VPN Direct") : "VPN Direct",
            countryCode: connected ? (server?.countryCode ?? "") : ""
        )
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

            // Catalog: Direct-owned remotes only (never third-party imports).
            let directServers = items
                .filter { DirectBuiltinProfile.isDirectOwned($0.profile.remoteURL) }
                .flatMap(\.servers)
            if !directServers.isEmpty {
                DirectLocationsCatalog.shared.replace(with: directServers)
            }
            // CDN refresh is TTL/ETag gated — safe at 2M+ clients.
            Task { await DirectLocationsCatalog.shared.refreshFromRemoteIfNeeded() }
            let selected = await SharedPreferences.selectedProfileID.get()
            if selected > 0, items.contains(where: { $0.id == selected }) {
                activeSubscriptionID = selected
            } else if selected <= 0 {
                // Explicitly cleared («Убрать из клиента») — keep home empty even if
                // other imported / builtin profiles remain in the list.
                activeSubscriptionID = 0
            } else if let first = items.first {
                // Stored id pointed at a deleted profile — recover to something valid.
                activeSubscriptionID = first.id
                await SharedPreferences.selectedProfileID.set(first.id)
            } else {
                activeSubscriptionID = 0
                await SharedPreferences.selectedProfileID.set(-1)
                await disableVPNAutoConnect()
            }
            if let item = subscriptions.first(where: { $0.id == activeSubscriptionID }),
               !DirectBuiltinProfile.isBuiltin(item.profile.remoteURL)
            {
                setActiveAccess(.imported(item.id))
            } else if activeSubscriptionID == 0 {
                setActiveAccess(.free)
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

    /// Rebuild remote graphs that still embed a sticky/flappy urltest tolerance.
    private func migrateUrlTestToleranceIfNeeded() async {
        if UserDefaults.standard.bool(forKey: Self.urltestToleranceMigratedKey) { return }
        defer { UserDefaults.standard.set(true, forKey: Self.urltestToleranceMigratedKey) }
        let profiles = (try? await ProfileManager.list()) ?? []
        var changed = false
        for profile in profiles where profile.type == .remote {
            guard let remoteURL = profile.remoteURL, !remoteURL.isEmpty else { continue }
            let json = (try? await profile.readAsync()) ?? ""
            // Migrate away from the old sticky 80 and the brief flappy 20.
            let needsRebuild =
                json.contains("\"tolerance\" : 80")
                || json.contains("\"tolerance\": 80")
                || json.contains("\"tolerance\":80")
                || json.contains("\"tolerance\" : 20")
                || json.contains("\"tolerance\": 20")
                || json.contains("\"tolerance\":20")
            guard needsRebuild else { continue }
            try? await profile.updateRemoteProfile()
            changed = true
        }
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
        // Manual re-tap of the same leaf just closes the sheet.
        // Auto (nil) must always re-bind urltest — otherwise a stale leaf pin sticks forever.
        if serverID != nil, serverID == selectedServerID {
            activeSheet = nil
            return
        }
        selectedServerID = serverID
        // Manual pick leaves "Авто" mode → next connect/applyConnectionModeBehavior
        // would wipe the selection and put urltest back. Mirror Happ/INCY: picking a
        // server implies user mode; picking Auto restores auto mode.
        let mode = serverID == nil ? "Авто" : "Пользовательский"
        if connectionMode != mode {
            connectionMode = mode
        }
        rememberRecentServer(serverID)
        activeSheet = nil
        HapticManager.shared.play(.selection)
        Task {
            await SharedPreferences.preferredOutboundTag.set(serverID ?? "")
            await SharedPreferences.connectionMode.set(mode)
            await reportMeteringActiveLocation(serverID: serverID)
            // Only switch live outbound when tunnel + command.sock are actually up.
            guard isConnected,
                  !isStarting,
                  phase != .connecting,
                  environments?.extensionProfile?.status.isConnectedStrict == true
            else { return }
            phase = .switching
            HapticManager.shared.play(.vpnSwitching)
            do {
                if let serverID, let server = activeSubscription?.servers.first(where: { $0.id == serverID }) {
                    try await LibboxNewStandaloneCommandClient()!.selectOutbound(server.groupTag, outboundTag: serverID)
                    assignedServerID = serverID
                } else {
                    let groupTag = resolveSelectorGroupTag(
                        fallback: activeSubscription?.servers.first?.groupTag ?? "proxy"
                    )
                    // Auto mode: keep the selector on native urltest `auto` — never pin a leaf.
                    try await LibboxNewStandaloneCommandClient()!.selectOutbound(groupTag, outboundTag: "auto")
                    try? await LibboxNewStandaloneCommandClient()!.urlTest("auto")
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await refreshAssignedFromGroups()
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
                phase = .idle
                HapticManager.shared.play(.vpnSwitched)
                await mergeLivePings()
                // Give the new outbound a moment, then re-check egress IP.
                try? await Task.sleep(nanoseconds: 500_000_000)
                refreshPublicIP()
            } catch {
                phase = .idle
                alert = AlertState(action: "switch server", error: error)
            }
        }
    }

    /// Локации tab: switch when entitled + live Direct config, otherwise open tariffs.
    public func selectDirectLocation(serverID: String?) {
        if let sid = serverID,
           isLocationCapExhausted(serverID: sid, locationLabel: serversForLocationPicker.first(where: { $0.id == sid })?.locationLabel) {
            alert = AlertState(errorMessage: String(localized: "Трафик по этой локации исчерпан. Она видна в списке, но подключение недоступно до сброса периода."))
            return
        }
        if canSwitchDirectLocations {
            // Always switch on a Direct-owned profile, never a third-party import.
            if let direct = subscriptions.first(where: {
                DirectBuiltinProfile.isDirectOwned($0.profile.remoteURL) && !$0.servers.isEmpty
            }) {
                if activeSubscriptionID != direct.id {
                    setActiveAccess(DirectBuiltinProfile.isBuiltin(direct.profile.remoteURL) ? .premium : .imported(direct.id))
                    activate(subscriptionID: direct.id)
                }
            } else {
                ensureDirectProfileActive()
            }
            select(serverID: serverID)
            return
        }
        openPremiumPlans(mode: .presets)
    }

    public func toggleConnection() {
        // Tap during hang/connecting cancels instead of ignoring input.
        if phase == .connecting || phase == .switching {
            Task { await cancelPendingConnection(showError: false) }
            return
        }
        guard phase == .idle else { return }

        // Disconnect / cancel never requires disclosure.
        if dialIsConnected {
        Task { await toggleConnectionAsync() }
            return
        }

        // All users (including existing installs) must accept before first connect.
        guard privacyDisclosureAccepted else {
            showPrivacyDisclosure = true
            HapticManager.shared.play(.sheetPresented)
            return
        }

        Task { await toggleConnectionAsync() }
    }

    public var privacyDisclosureAccepted: Bool {
        UserDefaults.standard.bool(forKey: Self.privacyDisclosureAcceptedKey)
    }

    public func acceptPrivacyDisclosureAndConnect() {
        UserDefaults.standard.set(true, forKey: Self.privacyDisclosureAcceptedKey)
        showPrivacyDisclosure = false
        #if os(iOS)
        DirectPushRegistration.requestPermissionIfNeeded()
        #endif
        guard phase == .idle, !dialIsConnected else { return }
        Task { await toggleConnectionAsync() }
    }

    public func declinePrivacyDisclosure() {
        showPrivacyDisclosure = false
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
            try? await LibboxNewStandaloneCommandClient()!.urlTest("auto")
            try? await Task.sleep(nanoseconds: 500_000_000)
            await mergeLivePings()
        }
    }

    /// Happ-style list ping (https://www.happ.su/main/dev-docs/ping):
    /// - VPN on → **via Proxy** (`urlTestOutbound` GET to gstatic generate_204 through each node)
    /// - VPN off → **TCP** connect RTT to node host:port
    public func pingAllServers() {
        guard let subscription = activeSubscription, !subscription.servers.isEmpty else {
            alert = AlertState(errorMessage: String(localized: "Нет серверов для проверки."))
            return
        }
        guard !isPingingServers else { return }
        isPingingServers = true
        let subscriptionID = subscription.id
        let servers = subscription.servers
        let profile = subscription.profile
        let groupTag = activeServer?.groupTag ?? servers.first?.groupTag
        let wasConnected = isConnected
        let mode = ServerEndpointPing.preferredMode(isConnected: wasConnected)

        Task {
            defer {
                Task { @MainActor in self.isPingingServers = false }
            }

            let delays: [String: Int]
            switch mode {
            case .viaProxy:
                // Per-node via Proxy (does not flip the live selector). More accurate than
                // group urlTest history alone — same path Happ uses for list latency.
                let measured = await ServerEndpointPing.measureViaProxyAll(tags: servers.map(\.id))
                if measured.isEmpty, let groupTag {
                    // Fallback: classic group urlTest + history merge.
                    try? await LibboxNewStandaloneCommandClient()!.urlTest(groupTag)
                    try? await LibboxNewStandaloneCommandClient()!.urlTest("auto")
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    await mergeLivePings()
                    let hasPing = await MainActor.run {
                        self.activeSubscription?.servers.contains(where: { $0.ping > 0 }) ?? false
                    }
                    await MainActor.run {
                        HapticManager.shared.play(hasPing ? .selection : .error)
                        if !hasPing {
                            self.alert = AlertState(errorMessage: String(localized: "Не удалось измерить задержку. Попробуйте ещё раз."))
                        }
                    }
                    return
                }
                // Refresh Auto/group history for balancer, then keep per-node via-Proxy as source of truth for the list.
                if let groupTag {
                    try? await LibboxNewStandaloneCommandClient()!.urlTest(groupTag)
                    try? await LibboxNewStandaloneCommandClient()!.urlTest("auto")
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    await mergeLivePings()
                }
                delays = measured
            case .tcp:
                let json: String
                do {
                    json = try await profile.origin.readAsync()
                } catch {
                    await MainActor.run {
                        self.alert = AlertState(action: "read profile for ping", error: error)
                    }
                    return
                }
                let endpoints = ServerEndpointPing.index(fromJSON: json)
                delays = await ServerEndpointPing.measureTCPAll(
                    endpoints: endpoints,
                    serverIDs: servers.map(\.id)
                )
            }

            await MainActor.run {
                self.applyPingResults(delays, subscriptionID: subscriptionID)
                HapticManager.shared.play(delays.isEmpty ? .error : .selection)
                if delays.isEmpty {
                    self.alert = AlertState(errorMessage: String(localized: "Не удалось измерить задержку. Проверьте сеть."))
                }
            }
        }
    }

    private func applyPingResults(_ delays: [String: Int], subscriptionID: Int64) {
        guard !delays.isEmpty else { return }
        subscriptions = subscriptions.map { sub in
            guard sub.id == subscriptionID else { return sub }
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
                    groupTag: server.groupTag,
                    locationLabel: server.locationLabel
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
    }

    public func updateFromGroups() {
        Task {
            // Always refresh the live Auto outbound — otherwise "Сейчас" stays on
            // servers.first (usually Germany) while the picker is open.
            await refreshAssignedFromGroups()
            // Large subscriptions + open picker: skip full list rebuild on every tick.
            if activeSheet == .serverPicker { return }
            await mergeLivePings()
        }
    }

    private func toggleConnectionAsync() async {
        guard let environments else { return }
        guard !environments.emptyProfiles else {
            alert = AlertState(errorMessage: String(localized: "Добавьте подписку, чтобы подключить VPN."))
            selectedTab = .management
            return
        }
        guard activeSubscriptionID > 0 else {
            alert = AlertState(errorMessage: String(localized: "Выберите подписку на вкладке «Подписки»."))
            selectedTab = .management
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
        // `.invalid` after a prefs wipe is normal — `start()` re-enables the manager.
        // Never silent-return here; that made connect look completely broken.

        do {
            // Disconnect only when actually up — `.connecting` must not take stop path.
            if profile.status.isConnectedStrict {
                persistSessionTrafficDelta()
                connectTimeoutTask?.cancel()
                HapticManager.shared.play(.vpnDisconnecting)
                phase = .disconnecting
                try await profile.stop()
                isStarting = false
                isConnected = false
                phase = .idle
            } else if profile.status == .connecting || isStarting || phase == .connecting {
                await cancelPendingConnection(showError: false)
            } else {
                // Align access with the selected profile before any Free/Premium gate.
                if let item = activeSubscription, !DirectBuiltinProfile.isBuiltin(item.profile.remoteURL) {
                    setActiveAccess(.imported(item.id))
                }
                if !skipAccessChoiceGate, shouldShowAccessChoiceOnConnect {
                    presentAccessChoice(reason: nil)
                    return
                }
                // Do not save On-Demand prefs here — races saveToPreferences inside start().
                await SharedPreferences.alwaysOn.set(false)
                await SharedPreferences.onDemandEnabled.set(false)
                connectAttemptID &+= 1
                connectTimeoutExtended = false
                connectSawConnecting = false
                isStarting = true
                phase = .connecting
                HapticManager.shared.play(.vpnConnecting)
                VPNDebugLog.write("dial begin selected=\(activeSubscriptionID) access=\(String(describing: activeAccess))")
                scheduleConnectTimeout()
                startConnectStatusPolling()
                try await profile.start()
                // Give the extension a moment to finish startTunnel / startService
                // before we decide the dial failed.
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                profile.refreshStatus()
                syncFromExtension()
                VPNDebugLog.write("dial afterStart status=\(profile.status.rawValue) isConnected=\(isConnected)")
                if isConnected {
                    return
                }
                // If still not up, keep polling — timeout handles hard failure.
            }
        } catch {
            VPNDebugLog.write("dial FAIL \(error.localizedDescription)")
            var disconnectHint: String?
            if #available(iOS 16.0, *) {
                do {
                    try await profile.fetchLastDisconnectError()
                } catch {
                    disconnectHint = error.localizedDescription
                    VPNDebugLog.write("lastDisconnect \(error.localizedDescription)")
                }
            }
            if let disconnectHint, !disconnectHint.isEmpty {
                await cancelPendingConnection(showError: true, error: NSError(
                    domain: "VPNConnection",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "\(error.localizedDescription)\n\(disconnectHint)"]
                ))
            } else {
            await cancelPendingConnection(showError: true, error: error)
            }
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

        await cancelPendingConnection(
            showError: true,
            error: Self.readLastTunnelError(afterDialMarker: true).map {
                NSError(domain: "VPNConnection", code: -4, userInfo: [NSLocalizedDescriptionKey: $0])
            }
        )
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
        connectSawConnecting = false
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
            let text = error.map { "Не удалось подключиться: \($0.localizedDescription)" }
                ?? "Не удалось подключиться. Проверьте подписку и сеть."
            // Third-party imports must NOT bounce into Free/Premium access choice.
            if let item = activeSubscription, !DirectBuiltinProfile.isBuiltin(item.profile.remoteURL) {
                alert = AlertState(errorMessage: text)
            } else {
                presentAccessChoice(reason: text)
            }
        }
        syncFromExtension()
    }

    /// Reads the last `startService FAIL` line written by the packet tunnel for this dial.
    private static func readLastTunnelError(afterDialMarker: Bool = false) -> String? {
        let url = FilePath.workingDirectory.appendingPathComponent("vpn-debug.log")
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8)
        else { return nil }
        let lines = text.split(separator: "\n").map(String.init)
        let window: ArraySlice<String>
        if afterDialMarker, let idx = lines.lastIndex(where: { $0.contains("dial begin") }) {
            window = lines[(idx + 1)...]
        } else {
            window = lines[...]
        }
        for line in window.reversed() {
            if line.contains("startService FAIL") {
                if let range = line.range(of: "startService FAIL ") {
                    return String(line[range.upperBound...])
                }
                return line
            }
        }
        return nil
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

    @MainActor
    private func refreshAssignedFromGroups() async {
        guard let groups = environments?.commandClient.groups else { return }
        let next: String?
        if let pick = resolveAutoOutboundPick(from: groups) {
            next = pick
        } else {
        let selectable = groups.filter { $0.selectable }
        guard let group = selectable.first(where: { $0.type == "selector" }) ?? selectable.first else { return }
            if group.selected == "auto", let pick = resolveAutoOutboundPick(from: groups) {
                next = pick
            } else if !group.selected.isEmpty, group.selected != "auto" {
                next = group.selected
            } else {
                next = nil
            }
        }
        guard let next, !next.isEmpty, next != "auto" else { return }
        if assignedServerID != next {
            assignedServerID = next
        }
    }

    /// Prefer the live pick inside urltest `auto`, not the parent selector's `"auto"` token
    /// (that previously made UI fall back to the first country — usually Germany).
    private func resolveAutoOutboundPick(from groups: [LibboxOutboundGroup]) -> String? {
        guard let auto = groups.first(where: { $0.tag == "auto" }) else { return nil }
        let selected = auto.selected.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selected.isEmpty, selected != "auto" {
            return selected
        }
        // Fallback: lowest measured delay among auto members.
        guard let iterator = auto.getItems() else { return nil }
        var bestTag: String?
        var bestDelay = Int.max
        while iterator.hasNext() {
            guard let item = iterator.next() else { continue }
            let delay = Int(item.urlTestDelay)
            if delay > 0, delay < bestDelay {
                bestDelay = delay
                bestTag = item.tag
            }
        }
        return bestTag
    }

    private func mergeLivePings() async {
        guard let groups = environments?.commandClient.groups else { return }
        let selectable = groups.filter { $0.selectable }
        guard let group = selectable.first(where: { $0.type == "selector" }) ?? selectable.first else { return }

        var delays: [String: Int] = [:]
        if let iterator = group.getItems() {
        while iterator.hasNext() {
            guard let item = iterator.next() else { continue }
            let delay = Int(item.urlTestDelay)
            if delay > 0 { delays[item.tag] = delay }
        }
        }
        // urltest `auto` holds the real per-country delays used for selection.
        if let auto = groups.first(where: { $0.tag == "auto" }), let iterator = auto.getItems() {
            while iterator.hasNext() {
                guard let item = iterator.next() else { continue }
                let delay = Int(item.urlTestDelay)
                if delay > 0 { delays[item.tag] = delay }
            }
        }
        guard !delays.isEmpty else {
            if let pick = resolveAutoOutboundPick(from: groups) {
                assignedServerID = pick
            }
            return
        }

        subscriptions = subscriptions.map { sub in
            var changed = false
            let servers = sub.servers.map { server -> VPNServer in
                guard let ping = delays[server.id] else { return server }
                let load = min(95, max(18, ping / 2 + (abs(server.id.hashValue) % 40)))
                if server.ping == ping, server.load == load { return server }
                changed = true
                return VPNServer(
                    id: server.id,
                    city: server.city,
                    country: server.country,
                    countryCode: server.countryCode,
                    ping: ping,
                    load: load,
                    groupTag: server.groupTag,
                    locationLabel: server.locationLabel
                )
            }
            guard changed else { return sub }
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
        if let pick = resolveAutoOutboundPick(from: groups) {
            assignedServerID = pick
        } else if !group.selected.isEmpty, group.selected != "auto" {
            assignedServerID = group.selected
        }

        // If Auto is on and a measured node is clearly faster than the sticky pick, nudge urltest.
        await nudgeAutoIfStale(delays: delays)
    }

    private func nudgeAutoIfStale(delays: [String: Int]) async {
        guard usesAutoSelection, isConnected, !delays.isEmpty else { return }
        let ranked = delays.filter { $0.value > 0 }.sorted { $0.value < $1.value }
        guard let best = ranked.first else { return }
        let currentID = assignedServerID
        let currentDelay = currentID.flatMap { id in
            delays[id] ?? delays.first(where: { $0.key.hasPrefix(id) || id.hasPrefix($0.key) })?.value
        } ?? Int.max
        // Client-side Auto nudge: only move when clearly better (≈100ms+ cases),
        // not on normal 10–40ms jitter between FR/NL/DE.
        let switchMargin = 80
        guard best.value + switchMargin < currentDelay else { return }
        // Keep selector on urltest `auto` — pinning a leaf breaks Auto permanently.
        try? await LibboxNewStandaloneCommandClient()!.urlTest("auto")
        try? await Task.sleep(nanoseconds: 350_000_000)
        await refreshAssignedFromGroups()
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
                    self?.maybePeriodicURLTest()
                    self?.syncFreeHoursFromExpiry()
                    self?.evaluateAccessEntitlements()
                    self?.updateTraffic()
                }
            }
        }
    }

    private func updateRuntime() {
        // Publishing every second while the server picker is open rebuilds ~30 rows
        // and makes the sheet feel stuck / untappable.
        if activeSheet == .serverPicker { return }
        guard isProtected,
              let connectedDate = environments?.extensionProfile?.connectedDate
        else {
            if runtimeText != "00:00:00" {
            runtimeText = "00:00:00"
            }
            lastPeriodicURLTestAt = nil
            return
        }
        let interval = max(0, Date().timeIntervalSince(connectedDate))
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        let next = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        if runtimeText != next {
            runtimeText = next
        }
    }

    /// Same Libbox urlTest path as the Ping button — every 12 seconds while connected.
    /// Skip while the server picker sheet is open so a large subscription (30+ nodes)
    /// does not thrash the sheet with group updates + full list rebuilds.
    private func maybePeriodicURLTest() {
        guard isProtected, !isPingingServers else { return }
        if activeSheet == .serverPicker { return }
        let now = Date()
        if let last = lastPeriodicURLTestAt, now.timeIntervalSince(last) < 12 { return }
        lastPeriodicURLTestAt = now
        requestURLTest()
    }

    private func updateTraffic() {
        if activeSheet == .serverPicker { return }
        let persisted = DailyTrafficStore.storedBytesForToday()

        let next: String
        if isProtected, let status = environments?.commandClient.status {
            let sessionTotal = status.uplinkTotal &+ status.downlinkTotal
            // Extension counters can restart after suspend — don't invent a huge negative delta.
            if sessionTrafficBaseline > 0, sessionTotal < sessionTrafficBaseline {
                sessionTrafficBaseline = sessionTotal
            } else if sessionTrafficBaseline == 0 {
                sessionTrafficBaseline = sessionTotal
            }
            lastSessionTrafficTotal = sessionTotal
            let delta = max(0, sessionTotal - sessionTrafficBaseline)
            next = Self.formatBytes(persisted &+ delta)
        } else if persisted > 0 {
            next = Self.formatBytes(persisted)
        } else {
            next = "—"
        }
        if trafficText != next {
            trafficText = next
        }
    }

    /// Flush live session bytes into today's store and advance the baseline so a
    /// later reset / counter rewind cannot wipe the counter on foreground.
    public func checkpointSessionTraffic() {
        persistSessionTrafficDelta()
        if let status = environments?.commandClient.status {
            let total = status.uplinkTotal &+ status.downlinkTotal
            sessionTrafficBaseline = total
            lastSessionTrafficTotal = total
        } else if lastSessionTrafficTotal > sessionTrafficBaseline {
            sessionTrafficBaseline = lastSessionTrafficTotal
        }
        updateTraffic()
    }

    private func resetSessionTrafficBaseline() {
        // Keep any uncommitted session bytes before re-baselining.
        persistSessionTrafficDelta()
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
