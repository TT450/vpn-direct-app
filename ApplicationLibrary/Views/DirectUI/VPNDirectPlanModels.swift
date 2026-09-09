import Foundation

#if os(iOS)

/// Unified plan shape for presets and the constructor.
public struct PlanConfiguration: Equatable, Codable, Hashable {
    public var name: String?
    public var days: Int
    public var devices: Int
    /// `nil` = Unlimited.
    public var trafficGB: Int?
    /// `0` = no white-list traffic.
    public var whitelistGB: Int

    public init(
        name: String? = nil,
        days: Int,
        devices: Int,
        trafficGB: Int?,
        whitelistGB: Int
    ) {
        self.name = name
        self.days = days
        self.devices = devices
        self.trafficGB = trafficGB
        self.whitelistGB = whitelistGB
    }

    public var trafficLabel: String {
        guard let trafficGB else { return "Unlimited" }
        if trafficGB >= 1000, trafficGB % 1000 == 0 {
            return "\(trafficGB / 1000) TB"
        }
        return "\(trafficGB) GB"
    }

    public var whitelistLabel: String {
        whitelistGB <= 0 ? "Без White-list" : "\(whitelistGB) GB White-list"
    }

    public var summaryLine: String {
        var parts = ["\(days) дн", "\(devices) устр.", trafficLabel]
        if whitelistGB > 0 {
            parts.append("\(whitelistGB) GB WL")
        }
        return parts.joined(separator: " · ")
    }

    public var displayTitle: String {
        if let name, !name.isEmpty { return name }
        return "Свой тариф"
    }
}

public enum VPNDirectPlanMode: String, CaseIterable, Identifiable {
    case presets
    case constructor

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .presets: return "Готовые тарифы"
        case .constructor: return "Конструктор"
        }
    }
}

public struct VPNDirectPlanPreset: Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let tagline: String
    public let trafficGB: Int?
    public let whitelistGB: Int
    public let devices: Int
    public let defaultDays: Int
    public let isFeatured: Bool

    public func configuration(days: Int) -> PlanConfiguration {
        PlanConfiguration(
            name: name,
            days: days,
            devices: devices,
            trafficGB: trafficGB,
            whitelistGB: whitelistGB
        )
    }
}

public enum VPNDirectPlanCatalog {
    public static let presetPeriodDays: [Int] = [30, 90, 180, 365]
    public static let constructorDays: [Int] = [7, 14, 30, 90, 180, 365]
    public static let constructorDevices: [Int] = [1, 3, 5, 10, 20]
    public static let constructorTrafficGB: [Int?] = [50, 100, 300, 500, 1000, 2000, nil]
    public static let constructorWhitelistGB: [Int] = [0, 20, 50, 100, 250, 500]

    public static let presets: [VPNDirectPlanPreset] = [
        VPNDirectPlanPreset(
            id: "travel",
            name: "Travel",
            tagline: "VPN на неделю · поездка или временный доступ",
            trafficGB: 30,
            whitelistGB: 10,
            devices: 1,
            defaultDays: 7,
            isFeatured: false
        ),
        VPNDirectPlanPreset(
            id: "start",
            name: "Start",
            tagline: "Для одного устройства",
            trafficGB: 100,
            whitelistGB: 20,
            devices: 1,
            defaultDays: 30,
            isFeatured: false
        ),
        VPNDirectPlanPreset(
            id: "plus",
            name: "Plus",
            tagline: "Оптимальный выбор для большинства",
            trafficGB: 300,
            whitelistGB: 50,
            devices: 3,
            defaultDays: 30,
            isFeatured: true
        ),
        VPNDirectPlanPreset(
            id: "pro",
            name: "Pro",
            tagline: "Для активного использования",
            trafficGB: 700,
            whitelistGB: 100,
            devices: 5,
            defaultDays: 30,
            isFeatured: false
        ),
        VPNDirectPlanPreset(
            id: "max",
            name: "Max",
            tagline: "Для семьи / команды",
            trafficGB: 2000,
            whitelistGB: 250,
            devices: 10,
            defaultDays: 30,
            isFeatured: false
        ),
        VPNDirectPlanPreset(
            id: "ultra",
            name: "Ultra",
            tagline: "Максимальный пакет без лимита трафика",
            trafficGB: nil,
            whitelistGB: 500,
            devices: 20,
            defaultDays: 30,
            isFeatured: false
        ),
    ]

    public static let featured = presets.first(where: \.isFeatured) ?? presets[2]

    public static func preset(id: String) -> VPNDirectPlanPreset? {
        presets.first { $0.id == id }
    }

    public static func defaultConfiguration() -> PlanConfiguration {
        featured.configuration(days: featured.defaultDays)
    }

    public static func periodLabel(days: Int) -> String {
        switch days {
        case 7: return "7 дней"
        case 14: return "14 дней"
        case 30: return "30 дней"
        case 90: return "90 дней"
        case 180: return "180 дней"
        case 365: return "365 дней"
        default: return "\(days) дн"
        }
    }

    public static func trafficOptionLabel(_ gb: Int?) -> String {
        guard let gb else { return "Unlimited" }
        if gb >= 1000, gb % 1000 == 0 { return "\(gb / 1000) TB" }
        return "\(gb) GB"
    }

    public static func whitelistOptionLabel(_ gb: Int) -> String {
        gb <= 0 ? "Без White-list" : "\(gb) GB"
    }
}

#endif
