import SwiftUI

#if os(iOS)

struct DirectHomePage: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var showRemoveImportedConfirmation = false
    @State private var showSupport = false
    @State private var showDevices = false
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
                    .padding(.bottom, 16)
                locationHeader
                locationList
                    .padding(.top, 16)
                Spacer(minLength: 0)
                quickActions
            }
            .padding(.horizontal, 19)
            .padding(.top, 8)
            .padding(.bottom, 16)

            if let toastText {
                Text(toastText)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 32)
                    .background(inkDark)
                    .padding(.horizontal, 19)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
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
        HStack(spacing: 0) {
            statusBadge

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text("●")
                        .font(.system(size: 8))
                    Text(statusTitle)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(statusColor)

                Text(profileTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.leading, 10)

            Spacer(minLength: 8)

            DirectHomeToggleButton(
                isOn: model.isProtected,
                isBusy: model.isBusy
            ) {
                model.toggleConnection()
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 96)
        .background(DS.paper)
        .overlay(Rectangle().stroke(stroke, lineWidth: 1))
    }

    private var statusBadge: some View {
        Group {
            if isNativeDirectSubscription {
                DirectHomeBrandMark(size: 47)
            } else {
                Text(providerInitial)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .frame(width: 47, height: 47)
                    .background(DS.ink)
            }
        }
        .frame(width: 47, height: 47)
        .clipped()
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

    private var statusTitle: String {
        if model.isBusy {
            switch model.phase {
            case .connecting: return "Подключение…"
            case .disconnecting: return "Отключение…"
            case .switching: return "Смена сервера…"
            case .idle: break
            }
        }
        return model.isProtected ? "Подключено" : "Отключено"
    }

    private var statusColor: Color {
        if model.isBusy { return Color.orange }
        return model.isProtected ? accent : danger
    }

    private var profileTitle: String {
        (model.activeSubscription?.name ?? "VPN Direct").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        GeometryReader { geo in
            let gap: CGFloat = 7
            // Wider cards (~3.6 visible), shorter strip — icon left, 2-line title right.
            let cardWidth = max(96, (geo.size.width - gap * 3) / 3.6)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: gap) {
                    DirectHomeAction(title: "Обновить\nпинг", icon: .refreshCw, busy: model.isPingingServers) {
                        model.pingAllServers()
                        toast("Обновляем пинг…")
                    }
                    .frame(width: cardWidth)

                    DirectHomeAction(
                        title: "Обновить\nподписку",
                        icon: .refreshCcw,
                        busy: model.isRefreshingSubscription,
                        disabled: !canUpdateSubscription
                    ) {
                        model.refreshActiveSubscription()
                        toast("Обновляем подписку…")
                    }
                    .frame(width: cardWidth)

                    DirectHomeAction(
                        title: "Продлить\nподписку",
                        icon: .calendar,
                        busy: renewBusy,
                        disabled: !isNativeDirectSubscription
                    ) {
                        renewBusy = true
                        Task {
                            await model.beginRenewCheckout()
                            renewBusy = false
                        }
                    }
                    .frame(width: cardWidth)

                    DirectHomeAction(
                        title: "Контроль\nустройств",
                        icon: .smartphone,
                        disabled: !isNativeDirectSubscription
                    ) {
                        showDevices = true
                    }
                    .frame(width: cardWidth)

                    DirectHomeAction(
                        title: "Убрать\nподписку",
                        icon: .x,
                        disabled: !canSoftRemove
                    ) {
                        showRemoveImportedConfirmation = true
                    }
                    .frame(width: cardWidth)

                    DirectHomeAction(title: "Режим\nподключения", icon: .slidersHorizontal) {
                        model.activeSheet = .profiles
                    }
                    .frame(width: cardWidth)

                    DirectHomeAction(
                        title: "Поддержка\nVPNDirect",
                        icon: .messagesSquare,
                        disabled: !isNativeDirectSubscription
                    ) {
                        showSupport = true
                    }
                    .frame(width: cardWidth)
                }
                .padding(.leading, 19)
                .padding(.trailing, 19)
            }
        }
        .frame(height: 40)
        .padding(.horizontal, -19)
        .padding(.top, 8)
    }

    // MARK: - Locations

    private var locationHeader: some View {
        HStack {
            Text("Выбор локации")
                .font(.system(size: 18, weight: .bold))
                .kerning(-0.45)
                .foregroundStyle(DS.ink)
            Spacer(minLength: 8)
            Button {
                model.openChangeServer()
            } label: {
                HStack(spacing: 6) {
                    Text("Все локации")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.ink)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(DS.paper)
                .overlay(Rectangle().stroke(stroke, lineWidth: 1.5))
            }
            .buttonStyle(HapticButtonStyle())
        }
        .frame(height: 44)
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
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 7) {
                DirectHomeLocationRow(
                    title: model.connectionModeDisplayTitle,
                    subtitle: model.connectionModeDisplaySubtitle,
                    ping: model.activeServer?.pingLabel ?? "— MS",
                    flagCode: nil,
                    useGlobe: true,
                    selected: true
                ) {
                    model.activeSheet = .profiles
                    toast("Режим: \(model.connectionModeDisplayTitle)")
                }

                if let pinned {
                    DirectHomeLocationRow(
                        title: pinned.locationLabel,
                        subtitle: model.locationQuotaSubtitle(for: pinned),
                        ping: pinned.pingLabel,
                        flagCode: pinned.countryCode,
                        flagFallback: model.flagFallbackLabel(for: pinned),
                        useGlobe: false,
                        selected: true,
                        exhausted: model.isLocationCapExhausted(pinned),
                        usedFraction: model.locationQuotaUsedFraction(for: pinned)
                    ) {
                        model.select(serverID: pinned.id)
                        toast("Локация: \(pinned.locationLabel)")
                    }
                }

                ForEach(homeServers) { server in
                    DirectHomeLocationRow(
                        title: server.locationLabel,
                        subtitle: model.locationQuotaSubtitle(for: server),
                        ping: server.pingLabel,
                        flagCode: server.countryCode,
                        flagFallback: model.flagFallbackLabel(for: server),
                        useGlobe: false,
                        selected: false,
                        exhausted: model.isLocationCapExhausted(server),
                        usedFraction: model.locationQuotaUsedFraction(for: server)
                    ) {
                        model.select(serverID: server.id)
                        toast("Локация: \(server.locationLabel)")
                    }
                }
            }
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

// MARK: - Toggle

private struct DirectHomeToggleButton: View {
    let isOn: Bool
    let isBusy: Bool
    let action: () -> Void

    private let onStroke = Color(red: 0.333, green: 0.851, blue: 0.596)
    private let onText = Color(red: 0.384, green: 0.863, blue: 0.6)
    private let onKnob = Color(red: 0.443, green: 0.898, blue: 0.655)
    private let offColor = Color(red: 0.89, green: 0.231, blue: 0.231)

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(isBusy ? Color.orange : (isOn ? onStroke : offColor), lineWidth: 2)
                    )
                Text(isBusy ? "…" : (isOn ? "ON" : "OFF"))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(isBusy ? Color.orange : (isOn ? onText : offColor))
                    .frame(maxWidth: .infinity, alignment: isOn ? .leading : .trailing)
                    .padding(.horizontal, 14)
                DirectLucideIcon(
                    name: .power,
                    size: 18,
                    color: isOn ? Color(red: 0.031, green: 0.067, blue: 0.043) : .white
                )
                .frame(width: 35, height: 35)
                .background(isBusy ? Color.orange : (isOn ? onKnob : offColor))
                .offset(x: isOn ? 24 : -24)
            }
            .frame(width: 94, height: 43)
            .clipped()
            .opacity(isBusy ? 0.72 : 1)
        }
        .buttonStyle(HapticButtonStyle())
        .disabled(isBusy)
    }
}

// MARK: - Action / Row

private struct DirectHomeAction: View {
    let title: String
    let icon: DirectLucideIcon.Name
    var busy = false
    var disabled = false
    let action: () -> Void

    private let stroke = DS.line

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 6) {
                DirectLucideIcon(
                    name: busy ? .ellipsis : icon,
                    size: 15,
                    color: disabled ? DS.muted.opacity(0.4) : DS.ink
                )
                .frame(width: 17, height: 17)

                Text(title)
                    .font(.system(size: 9))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .lineSpacing(-1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .foregroundStyle(disabled ? DS.muted.opacity(0.4) : DS.ink)
            .background(DS.paper)
            .overlay(Rectangle().stroke(stroke, lineWidth: 1))
            .opacity(busy ? 0.7 : 1)
        }
        .buttonStyle(HapticButtonStyle())
        .disabled(disabled || busy)
    }
}

private struct DirectHomeLocationRow: View {
    let title: String
    let subtitle: String
    let ping: String
    let flagCode: String?
    var flagFallback: String? = nil
    let useGlobe: Bool
    let selected: Bool
    var exhausted: Bool = false
    /// Limited locations only — `nil` hides the bottom meter.
    var usedFraction: Double? = nil
    let action: () -> Void

    private let accent = DS.green
    private let selectedBg = DS.acid.opacity(0.14)
    private let selectedStroke = DS.green
    private let stroke = DS.line

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Group {
                        if useGlobe {
                            DirectLucideIcon(name: .globe, size: 22, color: DS.acid)
                        } else if let flagCode, !flagCode.isEmpty {
                            FlagImage(code: flagCode, width: 34, height: 24, fallbackLabel: flagFallback)
                        } else if let flagFallback, !flagFallback.isEmpty {
                            FlagImage(code: "XX", width: 34, height: 24, fallbackLabel: flagFallback)
                        } else {
                            DirectLucideIcon(name: .globe, size: 22, color: accent)
                        }
                    }
                    .frame(width: 38, height: 36)
                    .padding(.trailing, 8)
                    .opacity(exhausted ? 0.5 : 1)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(title)
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(rowTitleColor)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: 8.5))
                            .foregroundStyle(rowSubtitleColor)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(exhausted ? DS.danger : (useGlobe ? DS.acid : DS.green))
                            .frame(width: 7, height: 7)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(exhausted ? "—" : ping)
                                .font(.system(size: 9.8, weight: .regular))
                                .foregroundStyle(rowPrimaryText)
                            Text(exhausted ? "Лимит" : "Пинг")
                                .font(.system(size: 8))
                                .foregroundStyle(rowSecondaryText)
                        }
                    }

                    ZStack {
                        Rectangle()
                            .stroke(
                                selected && !exhausted
                                    ? (useGlobe ? DS.acid : accent)
                                    : rowCheckboxStroke,
                                lineWidth: 1.6
                            )
                            .frame(width: 18, height: 18)
                        if selected && !exhausted {
                            Rectangle()
                                .fill(useGlobe ? DS.acid : accent)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.leading, 14)
                }
                .padding(.horizontal, 9)
                .padding(.top, usedFraction == nil ? 0 : 8)
                .frame(minHeight: usedFraction == nil ? 56 : 48)

                if let usedFraction {
                    DirectLocationQuotaBar(usedFraction: usedFraction)
                        .padding(.horizontal, 9)
                        .padding(.top, 6)
                        .padding(.bottom, 8)
                }
            }
            .background(rowBackground)
            .overlay(Rectangle().stroke(rowStroke, lineWidth: 1))
            .opacity(exhausted ? 0.9 : 1)
        }
        .buttonStyle(HapticButtonStyle())
    }

    private var rowBackground: Color {
        if useGlobe { return DS.ink }
        return selected && !exhausted ? selectedBg : DS.paper
    }

    private var rowStroke: Color {
        if useGlobe { return DS.ink }
        return selected && !exhausted ? selectedStroke : stroke
    }

    private var rowPrimaryText: Color {
        if useGlobe { return .white }
        return exhausted ? DS.muted : DS.ink
    }

    private var rowSecondaryText: Color {
        if useGlobe { return .white.opacity(0.45) }
        return Color.gray
    }

    private var rowTitleColor: Color {
        if useGlobe { return .white }
        return exhausted ? DS.muted : DS.ink
    }

    private var rowSubtitleColor: Color {
        if useGlobe { return .white.opacity(0.55) }
        return exhausted ? DS.danger : Color.gray
    }

    private var rowCheckboxStroke: Color {
        if useGlobe { return DS.acid.opacity(0.55) }
        return DS.muted.opacity(0.45)
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
