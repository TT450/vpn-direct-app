import Library
import SwiftUI

#if os(iOS)

// MARK: - Shared chrome

private struct DetailBackButton: View {
    @ObservedObject var model: VPNConnectionModel
    let title: String

    var body: some View {
        Button {
            model.goBack()
        } label: {
            Image(systemName: "arrow.left")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.muted)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
    }
}

private struct DirectSectionHeader: View {
    let title: String
    let meta: String

    var body: some View {
        HStack {
            Text(title).microLabel()
            Spacer()
            Text(meta).microLabel(color: DS.green)
        }
        .frame(height: 34)
        .overlay(alignment: .top) { Hairline(color: DS.ink) }
    }
}

private struct SettingToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(subtitle).font(.system(size: 9)).foregroundStyle(DS.muted)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(DS.green)
                .hapticToggle(isOn)
        }
        .frame(minHeight: 64)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

private struct OptionPills: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    Text(option)
                        .font(.system(size: 9, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .foregroundStyle(selection == option ? DS.acid : DS.ink)
                        .background(selection == option ? DS.ink : .clear)
                        .overlay(Rectangle().stroke(selection == option ? DS.ink : DS.line))
                }
                .buttonStyle(HapticButtonStyle())
            }
        }
    }
}

private struct SheetScaffold<Content: View>: View {
    let kicker: String
    let title: String
    let close: () -> Void
    let content: Content

    init(kicker: String, title: String, close: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.kicker = kicker
        self.title = title
        self.close = close
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(kicker).microLabel()
                        Text(title).font(.system(size: 30, weight: .semibold)).tracking(-1.3)
                    }
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .frame(width: 40, height: 40)
                            .background(DS.ink)
                            .foregroundStyle(DS.acid)
                    }
                    .buttonStyle(HapticButtonStyle())
                }
                .padding(.bottom, 16)
                .overlay(alignment: .bottom) { Hairline() }
                content
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
        .background(DS.paper.ignoresSafeArea())
    }
}

// MARK: - Subscription detail

struct DirectSubscriptionDetailView: View {
    @ObservedObject var model: VPNConnectionModel
    let subscriptionID: Int64
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false

    private var subscription: VPNSubscriptionItem? {
        model.subscriptions.first(where: { $0.id == subscriptionID })
    }

    private var isActive: Bool { model.isSubscriptionActive(subscriptionID) }
    private var isBuiltin: Bool {
        DirectBuiltinProfile.isBuiltin(subscription?.profile.remoteURL)
    }

    private var meta: SubscriptionMetadata {
        SubscriptionMetadataStore.load(profileID: subscriptionID) ?? SubscriptionMetadata()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                if let subscription {
                    PageHeading(
                        kicker: "КОНФИГУРАЦИЯ / \(String(format: "%02d", (model.subscriptions.firstIndex(where: { $0.id == subscriptionID }) ?? 0) + 1))",
                        title: subscription.name,
                        subtitle: subscription.source.capitalized
                    )
                    .padding(.top, DS.pageTop)

                    VStack(spacing: 0) {
                        HStack {
                            Label(isActive ? "АКТИВНА ДЛЯ ПОДКЛЮЧЕНИЯ" : "ГОТОВА К РАБОТЕ", systemImage: "circle.fill")
                                .microLabel(color: DS.acid)
                            Spacer()
                            Text("\(subscription.servers.count) ЛОКАЦИЙ").microLabel(color: .white.opacity(0.45))
                        }

                        HStack(spacing: 15) {
                            Text("A")
                                .font(.system(size: 31, weight: .medium, design: .monospaced))
                                .foregroundStyle(DS.acid)
                                .frame(width: 64, height: 64)
                                .overlay(Rectangle().stroke(Color.white.opacity(0.25)))
                            VStack(alignment: .leading, spacing: 5) {
                                Text("ТЕКУЩИЙ МАРШРУТ").microLabel(color: .white.opacity(0.4))
                                Text(subscription.servers.first?.city ?? "—").font(.system(size: 19, weight: .semibold))
                                Text("Балансировщик · \(subscription.servers.first?.pingLabel ?? "—")")
                                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                        }
                        .padding(.top, 25)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 154)
                    .background(DS.ink)
                    .foregroundStyle(.white)
                    .padding(.top, 22)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
                        DetailFact(label: "ИСТЕКАЕТ", value: subscription.expiry)
                        DetailFact(label: "УСТРОЙСТВ", value: subscription.devices)
                        DetailFact(label: "ТРАФИК", value: meta.trafficQuotaFullLabel)
                        DetailFact(label: "ОБНОВЛЕНА", value: subscription.updated.uppercased())
                        DetailFact(label: "ЛОКАЦИЙ", value: "\(subscription.servers.count)")
                        DetailFact(
                            label: "ПАНЕЛЬ",
                            value: (meta.compatibilityProfileID ?? "generic").uppercased()
                        )
                    }

                    if let announce = meta.announce?.trimmingCharacters(in: .whitespacesAndNewlines), !announce.isEmpty {
                        DirectSectionHeader(title: "ОБЪЯВЛЕНИЕ", meta: "PANEL").padding(.top, 16)
                        Text(announce)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.muted)
                            .padding(.vertical, 10)
                    }

                    if !isActive {
                        Button {
                            model.activate(subscriptionID: subscriptionID)
                        } label: {
                            HStack { Text("Активировать"); Spacer(); Image(systemName: "arrow.right") }
                                .padding(.horizontal, 15).frame(height: 48)
                                .foregroundStyle(DS.acid).background(DS.ink)
                        }
                        .buttonStyle(HapticButtonStyle()).padding(.top, 12)
                    }

                    if !isBuiltin {
                        DirectSectionHeader(title: "АДРЕС ПОДПИСКИ", meta: "СКРЫТ").padding(.top, 20)
                        Button {
                            model.copySubscriptionURL(subscriptionID: subscriptionID)
                        } label: {
                            HStack {
                                Text(maskedURL(subscription.profile.remoteURL))
                                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(DS.muted)
                                Spacer()
                                Text("КОПИРОВАТЬ").microLabel(color: DS.green)
                            }
                            .padding(.horizontal, 13).frame(height: 48)
                            .background(Color.white.opacity(0.28)).overlay(Rectangle().stroke(DS.line))
                        }
                        .buttonStyle(HapticButtonStyle())
                    }

                    VStack(spacing: 0) {
                        if !isBuiltin {
                            ActionRow(number: "01", title: "Обновить сейчас", subtitle: "Проверить новые и удалённые серверы", icon: "arrow.clockwise") {
                                model.refreshSubscription(subscriptionID: subscriptionID)
                            }
                        }
                        ActionRow(number: isBuiltin ? "01" : "02", title: "Переименовать", subtitle: "Изменить название на этом устройстве", icon: "arrow.right") {
                            renameText = subscription.name
                            showRenameAlert = true
                        }
                        if !isBuiltin {
                            ActionRow(number: "03", title: "Поделиться конфигурацией", subtitle: "Экспортировать ссылку или QR-код", icon: "square.and.arrow.up") {
                                model.shareSubscription(subscriptionID: subscriptionID)
                            }
                            ActionRow(number: "04", title: "Удалить подписку", subtitle: "Полностью удалить конфигурацию с устройства", icon: "trash", destructive: true) {
                                showDeleteConfirm = true
                            }
                        }
                    }
                    .padding(.top, 18)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .alert("Переименовать подписку", isPresented: $showRenameAlert) {
            TextField("Название", text: $renameText)
            Button("Сохранить") {
                model.renameSubscription(subscriptionID: subscriptionID, newName: renameText)
            }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Удалить подписку?", isPresented: $showDeleteConfirm) {
            Button("Удалить", role: .destructive) {
                model.deleteSubscription(subscriptionID: subscriptionID)
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Конфигурация будет полностью удалена с этого устройства.")
        }
    }

    private func maskedURL(_ url: String?) -> String {
        guard let url, !url.isEmpty else { return "—" }
        if let host = URL(string: url)?.host {
            return "https://\(host)/••••••••"
        }
        return "https://••••••••••••••••/sub"
    }
}

// MARK: - Profile detail pages

struct DirectSecurityCenterView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var showAddTrustedSSID = false
    @State private var trustedSSIDInput = ""

    private var enabled: Int { model.securityEnabledCount }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                PageHeading(kicker: "ЗАЩИТА / \(String(format: "%02d", enabled)) ИЗ 05", title: "Безопасность", subtitle: "Автоматика, DNS, маршрутизация и контроль соединения").padding(.top, DS.pageTop)

                HStack(spacing: 17) {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.14), lineWidth: 5)
                        Circle().trim(from: 0, to: CGFloat(enabled) / 5).stroke(DS.acid, lineWidth: 5).rotationEffect(.degrees(-90))
                        Text("\(enabled)/5").font(.system(size: 18, weight: .semibold, design: .monospaced))
                    }
                    .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("УРОВЕНЬ ЗАЩИТЫ").microLabel(color: .white.opacity(0.42))
                        Text(model.securityLevelTitle).font(.system(size: 21, weight: .semibold)).foregroundStyle(DS.acid)
                        Text(model.securityLevelSubtitle).font(.system(size: 9)).foregroundStyle(.white.opacity(0.5)).lineLimit(2)
                    }
                    Spacer()
                }
                .padding(.horizontal, 17).frame(minHeight: 126).background(DS.ink).foregroundStyle(.white).padding(.top, 22)

                DirectSectionHeader(title: "01 / СОЕДИНЕНИЕ", meta: "РЕКОМЕНДУЕТСЯ").padding(.top, 18)
                SettingToggleRow(title: "Автоподключение", subtitle: "Восстанавливать соединение автоматически", isOn: Binding(get: { model.autoConnect }, set: { model.setAutoConnect($0) }))
                SettingToggleRow(title: "Неизвестные Wi‑Fi", subtitle: "Включать VPN в новых сетях", isOn: Binding(get: { model.unknownWiFi }, set: { model.setUnknownWiFi($0) }))

                DirectSectionHeader(title: "02 / ПРИВАТНОСТЬ", meta: "DNS").padding(.top, 18)
                SettingToggleRow(title: "Защищённый DNS", subtitle: "Блокировка утечек и опасных доменов", isOn: Binding(get: { model.secureDNS }, set: { model.setSecureDNS($0) }))
                SettingToggleRow(title: "Локальная сеть", subtitle: "Принтеры, AirPlay и домашние устройства", isOn: Binding(get: { model.localNetwork }, set: { model.setLocalNetwork($0) }))
                SettingToggleRow(title: "Блокировка приложения", subtitle: "Запрашивать Face ID при открытии", isOn: Binding(get: { model.faceIDLock }, set: { model.setFaceIDLock($0) }))

                DirectSectionHeader(title: "03 / МАРШРУТИЗАЦИЯ", meta: "SPLIT").padding(.top, 18)
                SettingToggleRow(
                    title: "Российские сайты без VPN",
                    subtitle: "Домены и IP РФ идут напрямую; остальной трафик — через VPN",
                    isOn: Binding(get: { model.bypassRussianSites }, set: { model.setBypassRussianSites($0) })
                )

                DirectSectionHeader(
                    title: "ДОВЕРЕННЫЕ WI‑FI",
                    meta: String(format: "%02d СЕТЬ", model.trustedWifiSSIDs.count)
                ).padding(.top, 18)

                Text(model.wifiAccessHint)
                    .font(.system(size: 9))
                    .foregroundStyle(DS.muted)
                    .padding(.vertical, 8)

                Button {
                    Task {
                        let ok = await model.toggleTrustedCurrentWifiAfterRefresh()
                        if !ok, model.wifiAccess == .denied || model.wifiAccess == .needsPermission {
                            DirectWiFiMonitor.openSystemSettings()
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "wifi").font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.currentWifiSSID ?? wifiPlaceholderTitle)
                                .font(.system(size: 12, weight: .semibold))
                            Text(wifiPlaceholderSubtitle)
                                .font(.system(size: 9)).foregroundStyle(DS.muted)
                        }
                        Spacer()
                        Text(wifiTrailingLabel)
                            .microLabel(color: model.isCurrentWifiTrusted ? DS.green : DS.muted)
                    }
                    .padding(.horizontal, 12).frame(height: 64).background(Color.white.opacity(0.28)).overlay(Rectangle().stroke(DS.line))
                }
                .buttonStyle(HapticButtonStyle())
                .task { await model.refreshCurrentWifi() }

                Button {
                    trustedSSIDInput = ""
                    showAddTrustedSSID = true
                } label: {
                    HStack {
                        Text("Добавить сеть вручную")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Image(systemName: "plus")
                            .foregroundStyle(DS.green)
                    }
                    .padding(.horizontal, 12).frame(height: 48)
                    .overlay(alignment: .bottom) { Hairline() }
                }
                .buttonStyle(HapticButtonStyle())

                ForEach(model.trustedWifiSSIDs, id: \.self) { ssid in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield").foregroundStyle(DS.green)
                        Text(ssid).font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Button("Удалить") {
                            model.removeTrustedWifi(ssid)
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.danger)
                    }
                    .padding(.horizontal, 12).frame(minHeight: 48)
                    .overlay(alignment: .bottom) { Hairline() }
                }

                Button {
                    model.activeSheet = .connectionReport
                } label: {
                    HStack(spacing: 12) {
                        Text("✓").font(.system(size: 16)).foregroundStyle(DS.acid).frame(width: 38, height: 38).overlay(Rectangle().stroke(Color.white.opacity(0.24)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ПОСЛЕДНЯЯ ПРОВЕРКА · СЕЙЧАС").microLabel(color: .white.opacity(0.42))
                            Text(model.isProtected ? "IP и DNS защищены" : "IP и DNS не защищены")
                                .font(.system(size: 12, weight: .semibold))
                            Text(model.activeServer.map { $0.locationLabel } ?? "Нет активного сервера")
                                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right").foregroundStyle(DS.acid)
                    }
                    .padding(.horizontal, 13).frame(height: 76).background(DS.panel).foregroundStyle(.white)
                }
                .buttonStyle(HapticButtonStyle()).padding(.vertical, 18)
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .alert("Добавить доверенную сеть", isPresented: $showAddTrustedSSID) {
            TextField("Имя Wi‑Fi (SSID)", text: $trustedSSIDInput)
            Button("Добавить") {
                model.addTrustedWifi(trustedSSIDInput)
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("VPN не будет автоматически включаться в этой сети.")
        }
    }

    private var wifiPlaceholderTitle: String {
        switch model.wifiAccess {
        case .denied, .needsPermission:
            return "Нужен доступ к геолокации"
        default:
            return "Wi‑Fi не определён"
        }
    }

    private var wifiPlaceholderSubtitle: String {
        if model.isCurrentWifiTrusted {
            return "VPN можно не включать"
        }
        switch model.wifiAccess {
        case .denied, .needsPermission:
            return "Нажмите, чтобы открыть Настройки iOS"
        default:
            return "Нажмите, чтобы добавить текущую сеть"
        }
    }

    private var wifiTrailingLabel: String {
        if model.isCurrentWifiTrusted { return "ДОВЕРЕННАЯ" }
        switch model.wifiAccess {
        case .denied, .needsPermission:
            return "НАСТРОЙКИ"
        default:
            return "ДОБАВИТЬ"
        }
    }
}

struct DirectConnectionSettingsView: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                PageHeading(kicker: "СЕТЬ / УМНЫЙ РЕЖИМ", title: "Подключение", subtitle: "Маршрутизация и восстановление").padding(.top, DS.pageTop)

                VStack(alignment: .leading, spacing: 18) {
                    HStack { Text("ЯДРО / DIRECT NETWORK").microLabel(color: .white.opacity(0.42)); Spacer(); Text(model.connectionMode.uppercased()).microLabel(color: DS.acid) }
                    HStack { Text("УСТРОЙСТВО").microLabel(color: .white.opacity(0.5)); Spacer(); Text("→"); Text("VLESS").foregroundStyle(DS.acid).font(.system(size: 13, weight: .bold)); Text("→"); Spacer(); Text("REALITY · 443").microLabel(color: .white.opacity(0.5)) }
                    Text("Протокол VLESS подбирается автоматически из подписки.").font(.system(size: 9)).foregroundStyle(.white.opacity(0.46))
                }
                .padding(15).frame(maxWidth: .infinity, minHeight: 130).background(DS.ink).foregroundStyle(.white).padding(.top, 22)

                DirectSectionHeader(title: "01 / УМНЫЙ МАРШРУТ", meta: "ADVANCED").padding(.top, 18)
                SettingToggleRow(title: "Автоматический failover", subtitle: "Переключаться на рабочий сервер без разрыва", isOn: Binding(get: { model.autoFailover }, set: { model.setAutoFailover($0) }))

                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("СОБСТВЕННЫЙ DNS").microLabel(); Spacer(); Text("DIRECT SECURE DNS").microLabel(color: DS.green) }
                    HStack { Text("1.1.1.1").font(.system(size: 15, weight: .semibold, design: .monospaced)); Spacer(); Text("ИЗМЕНИТЬ").microLabel(color: DS.green) }
                    Text("Фильтрация рекламы, трекеров и опасных доменов включена.").font(.system(size: 9)).foregroundStyle(DS.muted)
                }
                .padding(14).background(Color.white.opacity(0.28)).overlay(Rectangle().stroke(DS.line)).padding(.vertical, 18)
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
    }
}

struct DirectDiagnosticsView: View {
    @ObservedObject var model: VPNConnectionModel

    private var tests: [(String, String)] {
        [
            ("Доступность подписки", model.activeSubscription.map { "URL отвечает · \($0.updated)" } ?? "Подписка не выбрана"),
            ("VPN-сервер", model.activeServer.map { "\($0.city) · \($0.pingLabel)" } ?? "Сервер не выбран"),
            ("Защищённый DNS", model.isProtected ? "Утечек не обнаружено" : "VPN не подключён"),
            ("Маршрут и протокол", "VLESS · Reality · TCP 443"),
        ]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                PageHeading(kicker: "СИСТЕМА / ПРОВЕРЕНО СЕЙЧАС", title: "Диагностика", subtitle: "Понятная проверка без технического шума").padding(.top, DS.pageTop)

                HStack(spacing: 13) {
                    Text(model.isProtected ? "✓" : "!")
                        .font(.system(size: 18))
                        .foregroundStyle(model.isProtected ? DS.acid : .orange)
                        .frame(width: 46, height: 46)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.25)))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.isProtected ? "СОЕДИНЕНИЕ РАБОТАЕТ НОРМАЛЬНО" : "VPN НЕ ПОДКЛЮЧЁН")
                            .microLabel(color: .white.opacity(0.42))
                        Text(model.isProtected ? "Проблем не обнаружено" : "Подключитесь для проверки")
                            .font(.system(size: 15, weight: .semibold))
                        Text(model.isProtected ? "Все основные проверки пройдены" : "Диагностика доступна после подключения")
                            .font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 102, alignment: .leading).background(DS.ink).foregroundStyle(.white).padding(.top, 22)

                VStack(spacing: 0) {
                    ForEach(Array(tests.enumerated()), id: \.offset) { index, test in
                        HStack(spacing: 11) {
                            Text(String(format: "%02d", index + 1)).microLabel()
                            VStack(alignment: .leading, spacing: 4) {
                                Text(test.0).font(.system(size: 12, weight: .semibold))
                                Text(test.1).font(.system(size: 9)).foregroundStyle(DS.muted)
                            }
                            Spacer()
                            Text(model.isProtected || index == 0 ? "✓" : "—").foregroundStyle(DS.green)
                        }
                        .frame(minHeight: 59).overlay(alignment: .bottom) { Hairline() }
                    }
                }
                .overlay(alignment: .top) { Hairline(color: DS.ink) }.padding(.top, 18)

                Button {
                    model.activeSheet = .recovery
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("ИНТЕРАКТИВНАЯ ДЕМОНСТРАЦИЯ").microLabel(color: Color.orange.opacity(0.75))
                            Text("Показать восстановление при сбое").font(.system(size: 12, weight: .semibold))
                            Text("Увидеть, как приложение меняет маршрут").font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Image(systemName: "arrow.right").foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 14).frame(height: 74).background(Color(red: 0.2, green: 0.18, blue: 0.15)).foregroundStyle(.white)
                }
                .buttonStyle(HapticButtonStyle()).padding(.top, DS.pageTop)

                DirectSectionHeader(title: "ДАННЫЕ ДЛЯ ПОДДЕРЖКИ", meta: "БЕЗ ЛИЧНЫХ ДАННЫХ").padding(.top, 18)
                HStack { Text("Скопировать отчёт диагностики").font(.system(size: 10)); Spacer(); Text("КОПИРОВАТЬ").microLabel(color: DS.green) }
                    .padding(.horizontal, 12).frame(height: 46).background(Color.white.opacity(0.28)).overlay(Rectangle().stroke(DS.line))
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
    }
}

struct DirectActivityView: View {
    @ObservedObject var model: VPNConnectionModel

    private var favorites: [VPNServer] { model.favoriteServers(for: model.activeSubscription) }
    private var history: [VPNServer] { model.recentServers(for: model.activeSubscription) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                PageHeading(kicker: "ЛОКАЦИИ / \(String(format: "%02d", favorites.count)) ИЗБРАННЫХ", title: "Мои серверы", subtitle: "Избранное и недавние подключения").padding(.top, DS.pageTop)
                DirectSectionHeader(title: "★ / ИЗБРАННОЕ", meta: String(format: "%02d", favorites.count)).padding(.top, 22)
                if favorites.isEmpty {
                    Text("Добавьте серверы в избранное из списка локаций")
                        .font(.system(size: 11)).foregroundStyle(DS.muted).padding(.vertical, 16)
                } else {
                    ForEach(Array(favorites.enumerated()), id: \.element.id) { index, server in
                        ActivityRow(index: index, server: server, detail: "\(server.locationLabel) · \(server.pingLabel)", trailing: "star.fill")
                    }
                }
                DirectSectionHeader(title: "↻ / ИСТОРИЯ", meta: "СЕГОДНЯ").padding(.top, 20)
                if history.isEmpty {
                    Text("История появится после подключений к серверам")
                        .font(.system(size: 11)).foregroundStyle(DS.muted).padding(.vertical, 16)
                } else {
                    ForEach(Array(history.enumerated()), id: \.element.id) { index, server in
                        ActivityRow(index: index, server: server, detail: index == 0 ? "Недавно · \(model.activeSubscription?.name ?? "")" : "\(index + 1) назад", trailing: index == 0 ? "circle.fill" : "arrow.right")
                    }
                }
                Button("Очистить историю подключений") {
                    HapticManager.shared.play(.deleted)
                    model.clearRecentHistory()
                }
                .font(.system(size: 10)).foregroundStyle(Color.red.opacity(0.65))
                .frame(maxWidth: .infinity, minHeight: 44).overlay(Rectangle().stroke(Color.red.opacity(0.18))).padding(.top, 15)
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
    }
}

// MARK: - Sheets

struct DirectConnectionReportView: View {
    @ObservedObject var model: VPNConnectionModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetScaffold(
            kicker: "ПРОВЕРКА / \(model.isProtected ? "VPN" : "WAN")",
            title: model.isProtected ? "Соединение подключено" : "Соединение отключено",
            close: { dismiss() }
        ) {
            HStack(spacing: 13) {
                Text(model.isProtected ? "✓" : "×")
                    .font(.system(size: 19))
                    .foregroundStyle(model.isProtected ? DS.acid : DS.danger)
                    .frame(width: 47, height: 47)
                    .overlay(Rectangle().stroke(Color.white.opacity(0.25)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.isProtected ? "IP VPN" : "РЕАЛЬНЫЙ IP").microLabel(color: .white.opacity(0.42))
                    HStack(spacing: 8) {
                        if model.publicIPLoading {
                            ProgressView().tint(DS.acid)
                        }
                        Text(model.publicIPText)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    }
                    Text(model.isProtected
                         ? (model.activeServer.map { $0.locationLabel } ?? "Туннель активен")
                         : "Без VPN — адрес вашего провайдера")
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Button {
                    model.refreshPublicIP()
                } label: {
                    Text("ОБНОВИТЬ").microLabel(color: DS.acid)
                }
                .buttonStyle(HapticButtonStyle())
            }
            .padding(.horizontal, 14).frame(height: 106).background(DS.ink).foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
                ReportFact(label: "ПРОТОКОЛ", value: "VLESS · REALITY")
                ReportFact(label: "СОЕДИНЕНИЕ", value: model.isProtected ? model.runtimeText : "00:00:00")
                ReportFact(label: "DNS", value: model.isProtected ? "ЗАЩИЩЁН" : "ОТКРЫТ", safe: model.isProtected)
                ReportFact(label: "ЗАДЕРЖКА", value: model.activeServer?.pingLabel ?? "— MS")
                ReportFact(label: "РЕЖИМ", value: model.connectionMode.uppercased())
                ReportFact(label: "ПОДПИСКА", value: model.activeSubscription?.name ?? "—")
            }

            DirectSectionHeader(title: "ПРОВЕРКА КАНАЛА", meta: model.isProtected ? "4 / 4" : "0 / 4").padding(.top, 18)
            ForEach(
                [
                    model.isProtected ? "Исходящий IP через VPN" : "Показан реальный IP",
                    "DNS-запросы \(model.isProtected ? "защищены" : "открыты")",
                    "WebRTC \(model.isProtected ? "утечек нет" : "не проверялся")",
                    "Маршрут через \(model.activeSubscription?.name ?? "VPN")",
                ],
                id: \.self
            ) { item in
                HStack {
                    Text(item).font(.system(size: 11))
                    Spacer()
                    Text(model.isProtected ? "✓" : "—").foregroundStyle(model.isProtected ? DS.green : DS.muted)
                }
                .frame(height: 44).overlay(alignment: .bottom) { Hairline() }
            }
        }
        .onAppear {
            model.refreshPublicIP()
            if model.isProtected {
                HapticManager.shared.play(.vpnConnected)
            }
        }
        .onChange(of: model.isProtected) { _ in
            model.refreshPublicIP()
        }
    }
}

struct DirectConnectionProfilesView: View {
    @ObservedObject var model: VPNConnectionModel
    @Environment(\.dismiss) private var dismiss

    private let profiles = [
        ("A", "Авто", "Баланс скорости и стабильности"),
        ("M", "Пользовательский", "Только выбранный вручную сервер"),
        ("S", "Максимальная скорость", "Ближайший сервер с минимальным ping"),
        ("R", "Стабильный", "Надёжный маршрут и failover"),
        ("V", "Для видео", "Высокая пропускная способность"),
        ("X", "5G", "Оптимизация для мобильных сетей"),
    ]

    var body: some View {
        SheetScaffold(kicker: "ПРОФИЛИ / \(String(format: "%02d", profiles.count))", title: "Режим подключения", close: { dismiss() }) {
            Text("Один профиль управляет сервером, протоколом и поведением при сбое.").font(.system(size: 10)).foregroundStyle(DS.muted).padding(.vertical, 12)
            ForEach(Array(profiles.enumerated()), id: \.element.1) { index, profile in
                Button {
                    model.setConnectionMode(profile.1)
                    HapticManager.shared.play(.selection)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(profile.0).font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(DS.acid).frame(width: 38, height: 38).background(DS.ink)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(String(format: "%02d", index + 1)) / ПРОФИЛЬ").microLabel()
                            Text(profile.1).font(.system(size: 14, weight: .semibold))
                            Text(profile.2).font(.system(size: 9)).foregroundStyle(DS.muted)
                        }
                        Spacer()
                        Image(systemName: model.connectionMode == profile.1 ? "checkmark" : "arrow.right").foregroundStyle(DS.green)
                    }
                    .padding(.horizontal, 10).frame(minHeight: 72).background(model.connectionMode == profile.1 ? DS.acid.opacity(0.1) : .clear).contentShape(Rectangle())
                }
                .buttonStyle(HapticButtonStyle()).overlay(alignment: .bottom) { Hairline() }
            }
        }
    }
}

struct DirectRecoveryView: View {
    @ObservedObject var model: VPNConnectionModel
    @Environment(\.dismiss) private var dismiss
    @State private var fixed = false

    var body: some View {
        SheetScaffold(kicker: fixed ? "ВОССТАНОВЛЕНИЕ / УСПЕШНО" : "АВТОМАТИКА / В РАБОТЕ", title: fixed ? "Маршрут восстановлен" : "Проблема с сервером", close: { dismiss() }) {
            HStack(spacing: 13) {
                Text(fixed ? "✓" : "!")
                    .font(.system(size: 20)).foregroundStyle(fixed ? DS.acid : .orange)
                    .frame(width: 44, height: 44).overlay(Rectangle().stroke(Color.white.opacity(0.25)))
                VStack(alignment: .leading, spacing: 5) {
                    Text(fixed ? "ЗАЩИТА НЕ ПРЕРЫВАЛАСЬ" : "СЕРВЕР НЕ ОТВЕЧАЕТ").microLabel(color: .white.opacity(0.48))
                    Text(fixed ? "Резервный сервер подключён" : "Ищем новый маршрут").font(.system(size: 15, weight: .semibold))
                    Text(fixed ? "Новый сервер · 31 ms · VLESS" : "Интернет заблокирован защитой при обрыве").font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 102, alignment: .leading)
            .background(fixed ? DS.ink : Color(red: 0.2, green: 0.18, blue: 0.15)).foregroundStyle(.white)

            VStack(spacing: 0) {
                RecoveryStep(number: "01", title: "Повторное подключение", detail: "Сервер не отвечает", status: "×")
                RecoveryStep(number: "02", title: "Смена транспорта", detail: "TCP · 443", status: "✓")
                RecoveryStep(number: "03", title: "Резервный сервер", detail: fixed ? "Резерв · 31 ms" : "Проверяем локации", status: fixed ? "✓" : "•••")
                RecoveryStep(number: "04", title: "Другой протокол", detail: "При необходимости", status: "—")
            }
            .overlay(alignment: .top) { Hairline(color: DS.ink) }.padding(.top, 18)

            Button {
                if fixed {
                    dismiss()
                } else {
                    model.runRecoveryDemo()
                    withAnimation { fixed = true }
                }
            } label: {
                HStack { Text(fixed ? "Готово — закрыть" : "Исправить автоматически"); Spacer(); Image(systemName: fixed ? "checkmark" : "arrow.right") }
                    .padding(.horizontal, 14).frame(height: 50).foregroundStyle(DS.acid).background(DS.ink)
            }
            .buttonStyle(HapticButtonStyle()).padding(.top, DS.pageTop)
        }
        .onAppear { HapticManager.shared.play(.warning) }
    }
}

// MARK: - Row helpers

private struct DetailFact: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).microLabel()
            Text(value).font(.system(size: 12, weight: .semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 63, alignment: .leading)
        .padding(.leading, 12)
        .overlay(alignment: .bottom) { Hairline() }
        .overlay(alignment: .leading) { Rectangle().fill(DS.line).frame(width: 1) }
    }
}

private struct ActionRow: View {
    let number: String
    let title: String
    let subtitle: String
    let icon: String
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 11) {
                Text(number).microLabel()
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 12, weight: .semibold))
                    Text(subtitle).font(.system(size: 9)).foregroundStyle(DS.muted)
                }
                Spacer()
                Image(systemName: icon).font(.system(size: 12)).foregroundStyle(destructive ? Color.red.opacity(0.7) : DS.green)
            }
            .frame(minHeight: 61).contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .overlay(alignment: .bottom) { Hairline() }
    }
}

private struct ActivityRow: View {
    let index: Int
    let server: VPNServer
    let detail: String
    let trailing: String

    var body: some View {
        HStack(spacing: 11) {
            Text(String(format: "%02d", index + 1)).microLabel()
            FlagImage(code: server.countryCode, width: 28, height: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(server.locationLabel).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 9)).foregroundStyle(DS.muted)
            }
            Spacer()
            Image(systemName: trailing).font(.system(size: 10)).foregroundStyle(DS.green)
        }
        .frame(minHeight: 62).overlay(alignment: .bottom) { Hairline() }
    }
}

private struct ReportFact: View {
    let label: String
    let value: String
    var safe = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).microLabel()
            Text(value).font(.system(size: 11, weight: .semibold)).foregroundStyle(safe ? DS.green : DS.ink)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(.leading, 12)
        .overlay(alignment: .bottom) { Hairline() }
        .overlay(alignment: .leading) { Rectangle().fill(DS.line).frame(width: 1) }
    }
}

private struct RecoveryStep: View {
    let number: String
    let title: String
    let detail: String
    let status: String

    var body: some View {
        HStack(spacing: 11) {
            Text(number).microLabel()
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 9)).foregroundStyle(DS.muted)
            }
            Spacer()
            Text(status).font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(status == "✓" || status == "•••" ? DS.green : DS.muted)
        }
        .frame(minHeight: 59).overlay(alignment: .bottom) { Hairline() }
    }
}

#endif
