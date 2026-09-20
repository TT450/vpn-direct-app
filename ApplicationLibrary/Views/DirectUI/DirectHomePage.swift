import SwiftUI

#if os(iOS)

struct DirectHomePage: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var showRemoveImportedConfirmation = false
    @State private var showSupport = false
    @State private var showDevices = false
    @State private var showMoreMenu = false
    @State private var toastText: String?
    @State private var renewBusy = false
    @State private var locationListContentHeight: CGFloat = 0
    @State private var locationListViewportHeight: CGFloat = 0

    private let stroke = DS.line
    private let accent = DS.green
    private let accentSoft = DS.acid
    private let danger = DS.danger
    private let inkDark = DS.ink

    var body: some View {
        ZStack(alignment: .top) {
            DS.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                vpnCard
                    .padding(.bottom, 14)
                locationHeader
                locationList
                    .padding(.top, 10)
                Spacer(minLength: 8)
                quickActions
                    // Never let this strip absorb leftover vertical space.
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, DS.pageTop)
            .padding(.bottom, 12)

            if let toastText {
                Text(toastText)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 32)
                    .background(inkDark)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }

            if showMoreMenu {
                moreActionsOverlay
                    .transition(.opacity)
                    .zIndex(40)
            }
        }
        .animation(.easeOut(duration: 0.18), value: showMoreMenu)
        .background(DS.paper.ignoresSafeArea())
        .overlay {
            if model.showPrivacyDisclosure {
                DirectPrivacyDisclosureView(
                    onAccept: {
                        HapticManager.shared.play(.sheetDismissed)
                        model.acceptPrivacyDisclosureAndConnect()
                    },
                    onDecline: {
                        HapticManager.shared.play(.sheetDismissed)
                        model.declinePrivacyDisclosure()
                    }
                )
            }
        }
        .alert("Убрать подписку из клиента?", isPresented: $showRemoveImportedConfirmation) {
            Button("Убрать", role: .destructive) {
                model.removeImportedFromClient()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Подписка останется в списке внешних, но на главной больше не будет активной.")
        }
        .sheet(isPresented: $showSupport) {
            DirectSupportView()
                .background(DS.paper.ignoresSafeArea())
                .modifier(DirectHomeUtilitySheetChrome())
        }
        .sheet(isPresented: $showDevices) {
            DirectDevicesView(model: model)
                .background(DS.paper.ignoresSafeArea())
                .modifier(DirectHomeUtilitySheetChrome())
        }
        .task {
            await model.refreshLocationCaps()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                await model.refreshLocationCaps()
            }
        }
    }

    // MARK: - VPN card

    private var vpnCard: some View {
        VStack(spacing: 0) {
            vpnCardHeader
            Hairline(color: Color.black.opacity(0.10))
            vpnCardBody
            Hairline(color: Color.black.opacity(0.10))
            vpnCardFooter
        }
        .background(Color.white.opacity(0.55))
        .overlay(Rectangle().stroke(DS.ink, lineWidth: 1))
    }

    private var vpnCardHeader: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 6, height: 6)
            Text(statusTitle.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(statusColor)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(directSlotLabel)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(DS.ink.opacity(0.85))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var vpnCardBody: some View {
        HStack(alignment: .center, spacing: 12) {
            // Left stack height matches the 96pt power square.
            VStack(alignment: .leading, spacing: 5) {
                Text(protectionHeadline)
                    .font(.system(size: 20, weight: .semibold))
                    .kerning(-0.5)
                    .foregroundStyle(DS.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    if let server = cardLocationServer {
                        FlagImage(
                            code: server.countryCode,
                            width: 18,
                            height: 12,
                            fallbackLabel: model.flagFallbackLabel(for: server)
                        )
                        Text(cardLocationLine(for: server))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DS.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        Text(cardLocationFallback)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DS.muted)
                            .lineLimit(1)
                    }
                }

                HStack(alignment: .top, spacing: 22) {
                    vpnMetric(label: "LATENCY", value: cardLatencyValue)
                    vpnMetric(label: "TRAFFIC", value: cardTrafficValue)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: DirectHomeConnectButton.side, alignment: .leading)

            DirectHomeConnectButton(
                isOn: model.isProtected,
                isBusy: model.isBusy
            ) {
                model.toggleConnection()
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
    }

    private var vpnCardFooter: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(model.isProtected ? DS.ink : DS.muted)
                .frame(width: 5, height: 5)
            Text(model.isProtected ? "PROTECTED" : "UNPROTECTED")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(DS.ink.opacity(0.85))
            Spacer(minLength: 8)
            Text(cardProtocolModeLabel)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.3)
                .foregroundStyle(DS.ink.opacity(0.85))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func vpnMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(DS.muted)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(DS.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    /// Status dot/text: muted forest green when connected — never lime.
    private var statusDotColor: Color {
        if model.isBusy { return Color.orange }
        return model.isProtected ? DS.green : danger
    }

    private var protectionHeadline: String {
        if model.isBusy {
            switch model.phase {
            case .connecting: return "Защищаем\nСеть"
            case .disconnecting: return "Отключаем\nЗащиту"
            case .switching: return "Смена\nсервера…"
            case .idle: break
            }
        }
        return model.isProtected ? "Интернет\nзащищён" : "Интернет\nне защищён"
    }

    private var cardLocationServer: VPNServer? {
        model.activeServer ?? model.pinnedLocationServer
    }

    private func cardLocationLine(for server: VPNServer) -> String {
        let city = server.locationLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let country = server.country.trimmingCharacters(in: .whitespacesAndNewlines)
        if country.isEmpty || city.caseInsensitiveCompare(country) == .orderedSame {
            return city.isEmpty ? "—" : city
        }
        return "\(city) · \(country)"
    }

    private var cardLocationFallback: String {
        if model.isBusy { return "Определяем…" }
        return "Локация не выбрана"
    }

    private var cardLatencyValue: String {
        guard let ping = cardLocationServer?.ping, ping > 0 else { return "— MS" }
        return "\(ping) MS"
    }

    private var cardTrafficValue: String {
        let raw = model.trafficText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw != "—" else { return "—" }
        let unit = model.trafficUnit == "ГБ" ? "GB" : "MB"
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        return "\(normalized) \(unit)"
    }

    private var directSlotLabel: String {
        if isNativeDirectSubscription {
            return "DIRECT / 01"
        }
        let name = profileTitle.uppercased()
        let token = String(name.prefix(6))
        return token.isEmpty ? "IMPORT / 01" : "\(token) / 01"
    }

    private var cardProtocolModeLabel: String {
        let proto = isNativeDirectSubscription ? "VLESS" : "PROXY"
        let mode: String = {
            switch model.connectionMode {
            case "Авто": return "AUTO"
            case "Максимальная скорость": return "SPEED"
            case "Стабильный": return "STABLE"
            case "Для видео": return "VIDEO"
            case "5G", "Антиблокировка": return "5G"
            case "Пользовательский": return "MANUAL"
            default:
                let raw = model.connectionModeDisplayTitle.uppercased()
                return String(raw.prefix(8))
            }
        }()
        return "\(proto) · \(mode)"
    }

    private var statusTitle: String {
        if model.isBusy {
            switch model.phase {
            case .connecting: return "Защищаем Сеть"
            case .disconnecting: return "Отключаем Защиту"
            case .switching: return "Смена сервера…"
            case .idle: break
            }
        }
        return model.isProtected ? "Подключено" : "Отключено"
    }

    private var statusColor: Color {
        if model.isBusy { return Color.orange }
        // Forest green for connected — never acid/lime.
        return model.isProtected ? DS.green : danger
    }

    private var profileTitle: String {
        (model.activeSubscription?.name ?? "VPN Direct").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNativeDirectSubscription: Bool {
        guard let sub = model.activeSubscription else {
            // No imported profile yet — still our product surface (free/premium stubs).
            return model.isNativeDirectSubscriptionActive || model.hasPremiumEntitlement || model.isFreeAccessActive
        }
        return DirectBuiltinProfile.isDirectOwned(sub.profile.remoteURL)
    }

    private var providerInitial: String {
        let name = profileTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = name.first else { return "?" }
        return String(first).uppercased()
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("БЫСТРЫЕ ДЕЙСТВИЯ")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(DS.ink)
                Spacer(minLength: 8)
                Text("7 ФУНКЦИЙ")
                    .font(.system(size: 9, weight: .regular))
                    .tracking(0.5)
                    .foregroundStyle(DS.muted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Hairline(color: DS.line)

            HStack(alignment: .center, spacing: 0) {
                DirectHomeQuickCell(
                    title: "Ping",
                    caption: "СЕРВЕР",
                    icon: .refreshCw,
                    busy: model.isPingingServers
                ) {
                    model.pingAllServers()
                    toast("Обновляем пинг…")
                }
                quickCellDivider
                DirectHomeQuickCell(
                    title: "Подписка",
                    caption: "SYNC",
                    icon: .refreshCcw,
                    busy: model.isRefreshingSubscription,
                    disabled: !canUpdateSubscription
                ) {
                    model.refreshActiveSubscription()
                    toast("Обновляем подписку…")
                }
                quickCellDivider
                DirectHomeQuickCell(
                    title: "Продлить",
                    caption: "PLAN",
                    icon: .plus,
                    busy: renewBusy,
                    disabled: !isNativeDirectSubscription
                ) {
                    renewBusy = true
                    Task {
                        await model.beginRenewCheckout()
                        renewBusy = false
                    }
                }
                quickCellDivider
                DirectHomeQuickCell(
                    title: nil,
                    caption: "БОЛЬШЕ",
                    icon: .ellipsis
                ) {
                    showMoreMenu = true
                    HapticManager.shared.play(.menuOpened)
                }
            }
            .frame(height: DirectHomeQuickCell.rowHeight)
        }
        .background(Color.white)
        .overlay(Rectangle().stroke(DS.ink, lineWidth: 1))
        .padding(.top, 6)
    }

    private var quickCellDivider: some View {
        Rectangle()
            .fill(DS.line)
            .frame(width: 1)
            .frame(maxHeight: .infinity)
    }

    /// Same ink-card language as burger «Добавить подписку».
    private var moreActionsOverlay: some View {
        let items: [(String, String, String, String, Bool, () -> Void)] = [
            ("01", "Устройства", "Контроль сессий", "DEVICES", !isNativeDirectSubscription, {
                showDevices = true
            }),
            ("02", "Убрать", "Снять с главной", "RESET", !canSoftRemove, {
                showRemoveImportedConfirmation = true
            }),
            ("03", "Режим", "Профиль подключения", "MODE", false, {
                model.activeSheet = .profiles
            }),
            ("04", "Support", "Помощь VPN Direct", "HELP", !isNativeDirectSubscription, {
                showSupport = true
            }),
        ]

        return ZStack(alignment: .bottom) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    showMoreMenu = false
                    HapticManager.shared.play(.menuClosed)
                }

            VStack(spacing: 0) {
                HStack {
                    Text("ЕЩЁ ДЕЙСТВИЯ").microLabel(color: .white.opacity(0.48))
                    Spacer()
                    Text("04 ПУНКТА").microLabel(color: .white.opacity(0.48))
                }
                .padding(16)

                ForEach(items, id: \.0) { item in
                    Button {
                        guard !item.4 else { return }
                        showMoreMenu = false
                        HapticManager.shared.play(.selection)
                        item.5()
                    } label: {
                        HStack(spacing: 13) {
                            Text(item.0).microLabel(color: .white.opacity(0.35))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.1)
                                    .font(.system(size: 14, weight: .medium))
                                Text(item.2)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.46))
                            }
                            Spacer()
                            Text(item.3)
                                .microLabel(color: item.4 ? .white.opacity(0.22) : DS.acid)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 58)
                        .contentShape(Rectangle())
                        .opacity(item.4 ? 0.38 : 1)
                    }
                    .buttonStyle(HapticButtonStyle())
                    .disabled(item.4)
                    .overlay(alignment: .top) { Hairline(color: .white.opacity(0.1)) }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .background(DS.ink)
            .overlay(Rectangle().stroke(Color.white.opacity(0.08), lineWidth: 1))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Locations

    private var locationHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Локация")
                .font(.system(size: 20, weight: .semibold))
                .kerning(-0.4)
                .foregroundStyle(DS.ink)
            Spacer(minLength: 8)
            Button {
                model.openChangeServer()
            } label: {
                Text("ВСЕ ЛОКАЦИИ →")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(DS.ink.opacity(0.75))
            }
            .buttonStyle(HapticButtonStyle())
        }
        .frame(minHeight: 24)
    }

    private var homeServers: [VPNServer] {
        let all = model.activeSubscription?.servers ?? []
        let pinnedID = model.pinnedLocationServer?.id
        let rest = all.filter { $0.id != pinnedID }
        // Mode card + pinned + up to 9 more on home.
        return Array(rest.prefix(9))
    }

    private var locationList: some View {
        // Require clear overflow before enabling edge fade — otherwise the first
        // row sits under the top gradient even when the list does not scroll.
        let canScroll = locationListContentHeight > locationListViewportHeight + 28
        let pinned = model.pinnedLocationServer
        let autoSelected = model.usesAutoSelection
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                DirectHomeAutoLocationCard(
                    title: homeAutoTitle,
                    subtitle: homeAutoSubtitle,
                    ping: model.activeServer?.pingLabel ?? "— MS"
                ) {
                    model.activeSheet = .profiles
                }

                VStack(spacing: 0) {
                    if let pinned {
                        DirectHomeLocationRow(
                            title: pinned.locationLabel,
                            meta: homeLocationMeta(for: pinned),
                            ping: pinned.pingLabel,
                            flagCode: pinned.countryCode,
                            flagFallback: model.flagFallbackLabel(for: pinned),
                            selected: !autoSelected && model.selectedServerID == pinned.id,
                            exhausted: model.isLocationCapExhausted(pinned),
                            usage: homeLocationUsage(for: pinned)
                        ) {
                            model.select(serverID: pinned.id)
                            toast("Локация: \(pinned.locationLabel)")
                        }
                        if !homeServers.isEmpty {
                            Hairline(color: DS.line)
                        }
                    }

                    ForEach(Array(homeServers.enumerated()), id: \.element.id) { index, server in
                        DirectHomeLocationRow(
                            title: server.locationLabel,
                            meta: homeLocationMeta(for: server),
                            ping: server.pingLabel,
                            flagCode: server.countryCode,
                            flagFallback: model.flagFallbackLabel(for: server),
                            selected: !autoSelected && model.selectedServerID == server.id,
                            exhausted: model.isLocationCapExhausted(server),
                            usage: homeLocationUsage(for: server)
                        ) {
                            model.select(serverID: server.id)
                            toast("Локация: \(server.locationLabel)")
                        }
                        if index < homeServers.count - 1 {
                            Hairline(color: DS.line)
                        }
                    }
                }
                .background(DS.paper)
            }
            // Whole locations block — thin black frame like the mock.
            .overlay(Rectangle().stroke(DS.ink, lineWidth: 1))
            .padding(.top, 1)
            .padding(.trailing, 1)
            .padding(.bottom, canScroll ? 10 : 8)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: DirectHomeLocationContentHeightKey.self,
                        value: geo.size.height
                    )
                }
            )
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .clipped()
        .hapticHeavyScroll(step: 36)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: DirectHomeLocationViewportHeightKey.self,
                    value: geo.size.height
                )
            }
        )
        .onPreferenceChange(DirectHomeLocationContentHeightKey.self) { locationListContentHeight = $0 }
        .onPreferenceChange(DirectHomeLocationViewportHeightKey.self) { locationListViewportHeight = $0 }
        .mask(
            Group {
                if canScroll {
                    // Fade only the bottom edge — never the first location card.
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.90),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    Color.black
                }
            }
        )
    }

    private var homeAutoTitle: String {
        switch model.connectionMode {
        case "Авто":
            return "Автоматически"
        default:
            return model.connectionModeDisplayTitle
        }
    }

    private var homeAutoSubtitle: String {
        switch model.connectionMode {
        case "Авто":
            return "ЛУЧШИЙ СЕРВЕР ПО СКОРОСТИ"
        case "5G", "Антиблокировка":
            return "ДЛЯ СОТОВОЙ СВЯЗИ"
        default:
            return model.connectionModeDisplaySubtitle.uppercased()
        }
    }

    private func homeLocationMeta(for server: VPNServer) -> String {
        let country = server.country.trimmingCharacters(in: .whitespacesAndNewlines)
        let countryPart = country.isEmpty ? "—" : country.uppercased()
        guard let cap = model.locationCap(for: server),
              let gb = cap.capGb, gb > 0, gb.isFinite
        else {
            return "\(countryPart) • ∞ БЕЗЛИМИТ"
        }
        return "\(countryPart) • ЛИМИТНАЯ ЛОКАЦИЯ"
    }

    private func homeLocationUsage(for server: VPNServer) -> DirectHomeLocationUsage {
        guard let cap = model.locationCap(for: server),
              let limit = cap.capGb, limit > 0, limit.isFinite
        else {
            return .unlimited
        }
        let used: Double = {
            if let used = cap.usedGb, used.isFinite, used >= 0 { return used }
            if let rem = cap.remainingGb, rem.isFinite { return max(0, limit - rem) }
            return 0
        }()
        let remaining: Double = {
            if let rem = cap.remainingGb, rem.isFinite { return max(0, rem) }
            return max(0, limit - used)
        }()
        let usedFraction = model.locationQuotaUsedFraction(for: server) ?? min(1, max(0, used / limit))
        return .limited(
            usedLabel: "\(Self.formatHomeGb(used)) / \(Self.formatHomeGb(limit))",
            remainLabel: "\(Self.formatHomeGb(remaining)) ОСТАЛОСЬ",
            usedFraction: usedFraction
        )
    }

    private static func formatHomeGb(_ gb: Double) -> String {
        guard gb.isFinite else { return "—" }
        if abs(gb - gb.rounded()) < 0.05 {
            return "\(Int(gb.rounded())) GB"
        }
        return String(format: "%.1f GB", gb)
    }

    // MARK: - Utility helpers

    private var canSoftRemove: Bool {
        guard let sub = model.activeSubscription else { return false }
        return !DirectBuiltinProfile.isDirectOwned(sub.profile.remoteURL)
    }

    private var canUpdateSubscription: Bool {
        guard let sub = model.activeSubscription else { return false }
        let remote = sub.profile.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return sub.profile.type == .remote && !remote.isEmpty
    }

    private func toast(_ text: String) {
        withAnimation(.easeOut(duration: 0.18)) { toastText = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 0.18)) { toastText = nil }
        }
    }
}

// MARK: - Connect / Disconnect

private struct DirectHomeConnectButton: View {
    let isOn: Bool
    let isBusy: Bool
    let action: () -> Void

    /// Fixed square — left copy stack is sized to match this height.
    static let side: CGFloat = 96
    private var side: CGFloat { Self.side }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                // Outer ring + solid core.
                ZStack {
                    Circle()
                        .stroke(glyphColor, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    Circle()
                        .fill(glyphColor)
                        .frame(width: 11, height: 11)
                }
                Text(buttonTitle)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(glyphColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: side, height: side)
            .background(buttonBackground)
            .overlay(Rectangle().stroke(DS.ink, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .frame(width: side, height: side)
        .aspectRatio(1, contentMode: .fit)
        .fixedSize()
        .disabled(isBusy)
        .opacity(isBusy ? 0.85 : 1)
        .accessibilityLabel(buttonTitle)
        .accessibilityValue(isOn ? "Включено" : "Выключено")
    }

    private var buttonTitle: String {
        if isBusy { return "WAIT…" }
        return isOn ? "DISCONNECT" : "CONNECT"
    }

    /// ON = lime (acid). OFF = white. Busy = orange. Never forest green.
    private var buttonBackground: Color {
        if isBusy { return Color.orange.opacity(0.9) }
        return isOn ? DS.acid : Color.white
    }

    private var glyphColor: Color {
        DS.ink
    }
}

// MARK: - Quick action cell

private struct DirectHomeQuickCell: View {
    let title: String?
    let caption: String
    let icon: DirectLucideIcon.Name
    var busy = false
    var disabled = false
    let action: () -> Void

    static let rowHeight: CGFloat = 44

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    HStack(alignment: .center, spacing: 4) {
                        DirectLucideIcon(
                            name: busy ? .ellipsis : icon,
                            size: 11,
                            color: foreground
                        )
                        .frame(width: 12, height: 12)

                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(foreground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                } else {
                    DirectLucideIcon(name: icon, size: 13, color: foreground)
                }

                Text(caption)
                    .font(.system(size: 8, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(disabled ? DS.muted.opacity(0.45) : DS.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(busy ? 0.7 : 1)
        }
        .buttonStyle(HapticButtonStyle())
        .frame(maxWidth: .infinity)
        .frame(height: Self.rowHeight)
        .disabled(disabled || busy)
    }

    private var foreground: Color {
        disabled ? DS.muted.opacity(0.4) : DS.ink
    }
}

private enum DirectHomeLocationUsage: Equatable {
    case unlimited
    case limited(usedLabel: String, remainLabel: String, usedFraction: Double)
}

private struct DirectHomeAutoLocationCard: View {
    let title: String
    let subtitle: String
    let ping: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Lime tile + black frame; rings + solid core.
                ZStack {
                    Rectangle()
                        .fill(DS.acid)
                    Circle()
                        .stroke(DS.ink, lineWidth: 1.7)
                        .frame(width: 20, height: 20)
                    Circle()
                        .stroke(DS.ink, lineWidth: 1.7)
                        .frame(width: 11, height: 11)
                    Circle()
                        .fill(DS.ink)
                        .frame(width: 4.5, height: 4.5)
                }
                .frame(width: 40, height: 40)
                .overlay(Rectangle().stroke(DS.ink, lineWidth: 1.4))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(Color.white.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(normalizedPing(ping))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.acid)
                    Text("BEST")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.ink)
        }
        .buttonStyle(HapticButtonStyle())
    }

    private func normalizedPing(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return t.isEmpty ? "— MS" : t
    }
}

private struct DirectHomeLocationRow: View {
    let title: String
    let meta: String
    let ping: String
    let flagCode: String?
    var flagFallback: String? = nil
    let selected: Bool
    var exhausted: Bool = false
    var usage: DirectHomeLocationUsage = .unlimited
    let action: () -> Void

    private let flagW: CGFloat = 34
    private let flagH: CGFloat = 24
    private let flagGap: CGFloat = 12
    private let checkbox: CGFloat = 18

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    flag
                        .padding(.trailing, flagGap)
                        .padding(.top, 1)
                        .opacity(exhausted ? 0.5 : 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(exhausted ? DS.muted : DS.ink)
                            .lineLimit(1)
                        Text(meta)
                            .font(.system(size: 9, weight: .medium))
                            .tracking(0.3)
                            .foregroundStyle(exhausted ? DS.danger : DS.muted)
                            .lineLimit(1)

                        if case .unlimited = usage {
                            Text("∞ БЕЗЛИМИТНЫЙ ТРАФИК")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DS.green)
                                .padding(.top, 4)
                        }
                    }

                    Spacer(minLength: 10)

                    VStack(alignment: .trailing, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(exhausted ? "—" : displayPing)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(exhausted ? DS.muted : DS.ink)
                            checkboxView
                        }
                        if case .unlimited = usage {
                            Text("—")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(DS.ink)
                                .frame(width: checkbox, alignment: .center)
                        }
                    }
                    .padding(.top, 1)
                }

                if case .limited(let usedLabel, let remainLabel, let usedFraction) = usage {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(usedLabel)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(DS.ink)
                        HStack(alignment: .center, spacing: 8) {
                            DirectLocationQuotaBar(usedFraction: usedFraction, height: 3)
                            Text(remainLabel)
                                .font(.system(size: 9, weight: .medium))
                                .tracking(0.2)
                                .foregroundStyle(DS.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.leading, flagW + flagGap)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 11)
            .padding(.bottom, 11)
            .opacity(exhausted ? 0.88 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
    }

    private var displayPing: String {
        ping.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var flag: some View {
        Group {
            if let flagCode, !flagCode.isEmpty {
                FlagImage(code: flagCode, width: flagW, height: flagH, fallbackLabel: flagFallback)
            } else if let flagFallback, !flagFallback.isEmpty {
                FlagImage(code: "XX", width: flagW, height: flagH, fallbackLabel: flagFallback)
            } else {
                Rectangle()
                    .fill(DS.ink.opacity(0.08))
                    .frame(width: flagW, height: flagH)
                    .overlay(Rectangle().stroke(Color.black.opacity(0.12), lineWidth: 0.5))
            }
        }
        .frame(width: flagW, height: flagH)
    }

    private var checkboxView: some View {
        ZStack {
            Rectangle()
                .fill(selected && !exhausted ? DS.acid : Color.white)
            Rectangle()
                .stroke(DS.ink, lineWidth: 1.35)
            if selected && !exhausted {
                Path { path in
                    path.move(to: CGPoint(x: 4.2, y: 9.2))
                    path.addLine(to: CGPoint(x: 7.4, y: 12.4))
                    path.addLine(to: CGPoint(x: 13.8, y: 5.6))
                }
                .stroke(DS.ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .square, lineJoin: .miter))
            }
        }
        .frame(width: checkbox, height: checkbox)
    }
}

private struct DirectHomeBrandMark: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let image = Self.loadLogo() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text("D")
                    .font(.system(size: size * 0.42, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DS.ink)
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .accessibilityLabel("VPN Direct")
    }

    private static func loadLogo() -> UIImage? {
        for name in ["DirectAppIcon", "AppIcon"] {
            if let image = UIImage(named: name), image.size.width > 1 {
                return image
            }
        }
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String]
        {
            for file in files.reversed() {
                if let image = UIImage(named: file), image.size.width > 1 {
                    return image
                }
            }
        }
        return nil
    }
}

private struct DirectHomeLocationContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct DirectHomeLocationViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct DirectHomeUtilitySheetChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(0)
                .preferredColorScheme(.light)
        } else if #available(iOS 16.0, *) {
            content
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.light)
        } else {
            content.preferredColorScheme(.light)
        }
    }
}

#endif
