import SwiftUI
import Library

#if os(iOS)

/// Локации — showcase без подписки (каталог CDN/seed) и свитчер после покупки
/// (те же live outbounds, что в sheet смены сервера).
struct DirectServersPage: View {
    @ObservedObject var model: VPNConnectionModel
    @ObservedObject private var catalog = DirectLocationsCatalog.shared

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
        // Auto / live urltest pick — never fall back to list order (Germany-first).
        if let active = model.activeServer, let match = item(for: active.id) {
            return match
        }
        if canSwitch, model.usesAutoSelection {
            return nil
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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(
                    kicker: "DIRECT / LOCATIONS",
                    title: "Локации",
                    subtitle: canSwitch
                        ? "Выберите локацию VPN Direct"
                        : "Актуальные локации VPN Direct — подключите тариф, чтобы сменить"
                )
                .padding(.top, DS.pageTop)
                .padding(.bottom, 16)

                subscriptionStrip

                searchField
                    .padding(.top, 14)

                if model.directServerItems.isEmpty {
                    emptyLocations
                        .padding(.top, 14)
                } else {
                    if canSwitch {
                        autoRow
                            .padding(.top, 14)
                    }

                    if let current = selectedServer {
                        currentServerCard(current)
                            .padding(.top, canSwitch ? 10 : 14)

                        sectionHeader
                            .padding(.top, 22)

                        VStack(spacing: 0) {
                            ForEach(servers.filter { $0.id != current.id }) { server in
                                serverRow(server)
                                Hairline()
                            }
                        }
                        .overlay(Rectangle().stroke(DS.line))
                    } else {
                        determiningCard
                            .padding(.top, canSwitch ? 10 : 14)

                        sectionHeader
                            .padding(.top, 22)

                        VStack(spacing: 0) {
                            ForEach(servers) { server in
                                serverRow(server)
                                Hairline()
                            }
                        }
                        .overlay(Rectangle().stroke(DS.line))
                    }

                    Text(footerNote)
                        .font(.system(size: 9))
                        .foregroundStyle(DS.muted)
                        .padding(.top, 10)
                        .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 20)
        }
        .background(DS.paper.ignoresSafeArea())
        .onAppear {
            Task { await DirectLocationsCatalog.shared.refreshFromRemoteIfNeeded() }
        }
    }

    private var footerNote: String {
        if canSwitch {
            return "Смена локации работает так же, как в окне выбора сервера. Пинг зависит от сети."
        }
        return "Список из каталога Direct. После покупки тарифа локации станут переключаемыми."
    }

    private var subscriptionStrip: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("03 / VPN DIRECT").microLabel(color: DS.muted)
                    Text("Доступ")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(DS.ink)
                    Text(planStripDetail)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(DS.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 8)

                Button {
                    refreshLocations()
                } label: {
                    Image(systemName: (model.isPingingServers || catalog.isRefreshing) ? "hourglass" : "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.ink)
                        .frame(width: 34, height: 34)
                        .overlay(Rectangle().stroke(DS.ink, lineWidth: 1))
                }
                .buttonStyle(HapticButtonStyle())
                .accessibilityLabel("Обновить локации")
            }
            .padding(.bottom, 10)

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
        .padding(.bottom, 2)
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
        let count = model.directServerItems.count
        if canSwitch {
            return "\(count) локаций · можно сменить"
        }
        if model.hasPremiumEntitlement {
            return "\(count) локаций · конфиг обновляется"
        }
        return "\(count) локаций · витрина"
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

    private var autoRow: some View {
        Button {
            model.selectDirectLocation(serverID: nil)
        } label: {
            HStack(spacing: 12) {
                Text("A")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .frame(width: 36, height: 36)
                    .background(DS.ink)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Автовыбор")
                        .font(.system(size: 14, weight: .semibold))
                    Text(autoSubtitle)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(DS.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
                if model.usesAutoSelection {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.green)
                }
            }
            .foregroundStyle(DS.ink)
            .padding(12)
            .overlay(Rectangle().stroke(model.usesAutoSelection ? DS.ink : DS.line, lineWidth: model.usesAutoSelection ? 1.5 : 1))
        }
        .buttonStyle(HapticButtonStyle())
    }

    private var autoSubtitle: String {
        if model.usesAutoSelection {
            if let server = model.activeServer {
                return "Активен · \(server.locationLabel)"
            }
            return model.isProtected ? "Активен · определяем маршрут…" : "Активен · лучший пинг"
        }
        return "Включить авто"
    }

    private var determiningCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ТЕКУЩАЯ ЛОКАЦИЯ").microLabel(color: DS.muted)
            Text("Определяем маршрут…")
                .font(.system(size: 19, weight: .semibold))
            Text("Автовыбор ещё выбирает лучший сервер")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DS.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(DS.paper)
        .overlay(Rectangle().stroke(DS.ink, lineWidth: 1.5))
    }

    private func currentServerCard(_ server: DirectServerItem) -> some View {
        let online = isOnline(server)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(canSwitch ? "ТЕКУЩАЯ ЛОКАЦИЯ" : "ЛОКАЦИЯ").microLabel(color: DS.muted)
                Spacer()
                Text(online ? "● ONLINE" : (canSwitch ? "○ ВЫБРАНА" : "○ ВИТРИНА"))
                    .microLabel(color: online ? DS.green : DS.muted)
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
                activate(server)
            } label: {
                HStack {
                    Text(primaryCTATitle(online: online))
                    Spacer()
                    Image(systemName: online ? "checkmark" : "arrow.right")
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(online ? DS.ink : DS.acid)
                .padding(.horizontal, 13)
                .frame(height: 46)
                .background(online ? DS.acid : DS.ink)
            }
            .buttonStyle(HapticButtonStyle())
        }
        .padding(14)
        .background(DS.paper)
        .overlay(Rectangle().stroke(DS.ink, lineWidth: 1.5))
    }

    private func primaryCTATitle(online: Bool) -> String {
        if canSwitch {
            return online ? "ПОДКЛЮЧЕНО" : "ВЫБРАТЬ"
        }
        if model.hasPremiumEntitlement {
            return "ОБНОВИТЬ КОНФИГ"
        }
        return "ПОДКЛЮЧИТЬ ТАРИФ"
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
            activate(server)
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

    private func isOnline(_ server: DirectServerItem) -> Bool {
        guard model.isConnected else { return false }
        if let selected = model.selectedServerID {
            return selected == server.id
        }
        return model.activeServer?.id == server.id
    }

    private func qualityLabel(for server: DirectServerItem) -> String {
        guard server.latency > 0 else { return "—" }
        if server.latency < 50 { return "ОТЛИЧНО" }
        if server.latency < 100 { return "ХОРОШО" }
        return "СРЕДНЕ"
    }

    private func activate(_ server: DirectServerItem) {
        model.selectDirectLocation(serverID: server.id)
    }

    private func refreshLocations() {
        if canSwitch {
            model.ensureDirectProfileActive()
            model.pingAllServers()
        }
        Task { await DirectLocationsCatalog.shared.refreshFromRemoteIfNeeded(force: true) }
        HapticManager.shared.play(.selection)
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
