import SwiftUI
import Library

#if os(iOS)

/// Локации — витрина без подписки; после покупки — тот же выбор серверов,
/// что в sheet смены сервера на главной (авто + список + пинг).
struct DirectServersPage: View {
    @ObservedObject var model: VPNConnectionModel

    @State private var searchText = ""

    private var servers: [DirectServerItem] {
        let source = model.directServerItems
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return source }
        return source.filter {
            $0.country.localizedCaseInsensitiveContains(query)
                || $0.city.localizedCaseInsensitiveContains(query)
                || $0.countryCode.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedServer: DirectServerItem? {
        if let id = model.selectedServerID, let match = item(for: id) {
            return match
        }
        if let active = model.activeServer, let match = item(for: active.id) {
            return match
        }
        return servers.first ?? model.directServerItems.first
    }

    private func item(for id: String) -> DirectServerItem? {
        let needle = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        let pool = servers.isEmpty ? model.directServerItems : servers
        if let exact = pool.first(where: { $0.id == needle }) {
            return exact
        }
        let hits = pool.filter { needle.hasPrefix($0.id) || $0.id.hasPrefix(needle) }
        return hits.max(by: { $0.id.count < $1.id.count })
    }

    private var canSwitch: Bool { model.canSwitchDirectLocations }

    var body: some View {
        Group {
            if canSwitch {
                switchableBody
            } else {
                showcaseBody
            }
        }
        .background(DS.paper.ignoresSafeArea())
        .onAppear {
            Task { await DirectLocationsCatalog.shared.refreshFromRemoteIfNeeded() }
        }
    }

    /// Same picker as home «смена сервера», under the page header + tariff actions.
    private var switchableBody: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                locationsHeader
                    .padding(.top, DS.pageTop)
                    .padding(.bottom, 16)

                accessActions
                    .padding(.bottom, 14)
            }
            .padding(.horizontal, 20)

            DirectServerPickerContent(
                model: model,
                serverSource: .liveDirect,
                selectServer: { model.selectDirectLocation(serverID: $0) }
            )
        }
    }

    private var showcaseBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                locationsHeader
                    .padding(.top, DS.pageTop)
                    .padding(.bottom, 16)

                accessActions

                searchField
                    .padding(.top, 14)

                if model.directServerItems.isEmpty {
                    emptyLocations
                        .padding(.top, 14)
                } else if let current = selectedServer {
                    currentServerCard(current)
                        .padding(.top, 14)

                    sectionHeader
                        .padding(.top, 22)

                    VStack(spacing: 0) {
                        ForEach(servers.filter { $0.id != current.id }) { server in
                            serverRow(server)
                            Hairline()
                        }
                    }
                    .overlay(Rectangle().stroke(DS.line))

                    Text(footerNote)
                        .font(.system(size: 9))
                        .foregroundStyle(DS.muted)
                        .padding(.top, 10)
                        .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var locationsHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text("DIRECT / LOCATIONS").microLabel()
                    .lineLimit(1)
                Text("Локации")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(planStripDetail)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            refreshButton
        }
    }

    private var isRefreshing: Bool {
        model.isRefreshingSubscription
    }

    private var refreshButton: some View {
        Button {
            model.refreshActiveSubscription()
        } label: {
            ZStack {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.ink)
                    .opacity(isRefreshing ? 0 : 1)
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(width: 36, height: 36)
            .background(DS.paper)
            .overlay(Rectangle().stroke(DS.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isRefreshing)
        .accessibilityLabel("Обновить подписку")
    }

    private var footerNote: String {
        "Список из каталога Direct. После покупки тарифа локации станут переключаемыми."
    }

    private var accessActions: some View {
        HStack(spacing: 8) {
            Button {
                model.openPremiumPlans(mode: .presets)
            } label: {
                accessOption(
                    kicker: "ТАРИФЫ",
                    title: "Готовые планы",
                    detail: "START · PLUS · PRO",
                    primary: false
                )
            }
            .buttonStyle(HapticButtonStyle())

            Button {
                model.openPremiumPlans(mode: .constructor)
            } label: {
                accessOption(
                    kicker: "КОНСТРУКТОР",
                    title: "Собрать свой",
                    detail: "ДНИ · УСТРОЙСТВА · ТРАФИК",
                    primary: true
                )
            }
            .buttonStyle(HapticButtonStyle())
        }
    }

    private func accessOption(
        kicker: String,
        title: String,
        detail: String,
        primary: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 6) {
                Text(kicker)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(primary ? DS.acid : DS.ink)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(primary ? DS.acid : DS.muted)
            }

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(primary ? DS.paper : DS.ink)
                .lineLimit(1)

            Text(detail)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(primary ? DS.paper.opacity(0.58) : DS.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(primary ? DS.ink : DS.paper)
        .overlay(Rectangle().stroke(primary ? DS.ink : DS.line, lineWidth: primary ? 1.5 : 1))
    }

    private var planStripDetail: String {
        let count = canSwitch ? model.liveDirectServers.count : model.directServerItems.count
        if canSwitch {
            return "\(count) локаций • можно сменить"
        }
        if model.hasPremiumEntitlement {
            return "\(count) локаций • конфиг обновляется"
        }
        return "\(count) локаций • витрина"
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.muted)
            TextField("Страна или город", text: $searchText)
                .font(.system(size: 11, design: .monospaced))
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DS.muted)
                }
            }
        }
        .foregroundStyle(DS.ink)
        .padding(.horizontal, 12)
        .frame(height: 43)
        .overlay(Rectangle().stroke(DS.line, lineWidth: 1))
    }

    private func currentServerCard(_ server: DirectServerItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ЛОКАЦИЯ").microLabel(color: DS.muted)
                Spacer()
                Text("○ ВИТРИНА")
                    .microLabel(color: DS.muted)
            }

            HStack(spacing: 12) {
                FlagImage(code: server.countryCode, width: 36, height: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(server.country)
                        .font(.system(size: 19, weight: .semibold))
                    Text(server.city)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DS.muted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(server.latency > 0 ? "\(server.latency) ms" : "— ms")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    Text(qualityLabel(for: server))
                        .microLabel(color: DS.green)
                }
            }
            .padding(.vertical, 14)

            Button {
                model.openPremiumPlans(mode: .presets)
            } label: {
                HStack {
                    Text(model.hasPremiumEntitlement ? "ОБНОВИТЬ КОНФИГ" : "ПОДКЛЮЧИТЬ ТАРИФ")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.acid)
                .padding(.horizontal, 13)
                .frame(height: 46)
                .background(DS.ink)
            }
            .buttonStyle(HapticButtonStyle())
        }
        .padding(14)
        .background(DS.paper)
        .overlay(Rectangle().stroke(DS.ink, lineWidth: 1.5))
    }

    private var sectionHeader: some View {
        HStack {
            Text("ДРУГИЕ ЛОКАЦИИ").microLabel(color: DS.ink)
            Spacer()
            Text("\(max(servers.count - (selectedServer == nil ? 0 : 1), 0))")
                .microLabel(color: DS.muted)
        }
        .frame(height: 38)
        .overlay(alignment: .top) { Hairline(color: DS.ink) }
    }

    private func serverRow(_ server: DirectServerItem) -> some View {
        Button {
            model.openPremiumPlans(mode: .presets)
        } label: {
            HStack(spacing: 11) {
                FlagImage(code: server.countryCode, width: 30, height: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(server.country)
                        .font(.system(size: 13, weight: .semibold))
                    Text(server.city)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(DS.muted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(server.latency > 0 ? "\(server.latency) ms" : "— ms")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    Text(qualityLabel(for: server))
                        .microLabel(color: DS.green)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.muted)
            }
            .foregroundStyle(DS.ink)
            .padding(.vertical, 13)
            .padding(.horizontal, 12)
        }
        .buttonStyle(HapticButtonStyle())
    }

    private var emptyLocations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Нет локаций")
                .font(.system(size: 15, weight: .semibold))
            Text("Каталог ещё не загружен. Обновите или откройте тарифы VPN Direct.")
                .font(.system(size: 12))
                .foregroundStyle(DS.muted)
            Button {
                model.openPremiumPlans(mode: .presets)
            } label: {
                HStack {
                    Text("Открыть тарифы")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.acid)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(DS.ink)
            }
            .buttonStyle(HapticButtonStyle())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(DS.line))
    }

    private func qualityLabel(for server: DirectServerItem) -> String {
        guard server.latency > 0 else { return "—" }
        if server.latency < 50 { return "ОТЛИЧНО" }
        if server.latency < 100 { return "ХОРОШО" }
        return "СРЕДНЕ"
    }
}

public struct DirectServerItem: Identifiable, Hashable {
    public let id: String
    public let countryCode: String
    public let country: String
    public let city: String
    public let latency: Int
    public let load: Int
    public let region: String

    public init(
        id: String? = nil,
        countryCode: String,
        country: String,
        city: String,
        latency: Int,
        load: Int,
        region: String
    ) {
        self.id = id ?? "\(countryCode)-\(city)"
        self.countryCode = countryCode
        self.country = country
        self.city = city
        self.latency = latency
        self.load = load
        self.region = region
    }

    public static func from(server: VPNServer) -> DirectServerItem {
        DirectServerItem(
            id: server.id,
            countryCode: server.countryCode,
            country: server.country.isEmpty ? server.locationLabel : server.country,
            city: server.city.isEmpty ? server.locationLabel : server.city,
            latency: server.ping,
            load: server.load,
            region: Self.region(for: server.countryCode)
        )
    }

    public static func region(for countryCode: String) -> String {
        switch countryCode.uppercased() {
        case "US", "CA", "BR", "MX", "AR", "CL", "CO", "PE":
            return "AMERICAS"
        case "SG", "JP", "HK", "KR", "TW", "IN", "CN", "AU", "NZ", "TH", "VN", "ID", "MY", "PH", "AE", "TR":
            return "ASIA"
        default:
            return "EUROPE"
        }
    }
}

#endif
