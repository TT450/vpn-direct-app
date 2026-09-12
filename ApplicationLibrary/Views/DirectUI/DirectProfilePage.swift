import Library
import SwiftUI

#if os(iOS)

struct DirectProfilePage: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var utility: UtilityPage?

    private enum UtilityPage: String, Identifiable {
        case devices
        case payments
        case promo
        case support
        case linking
        var id: String { rawValue }
    }

    private var settings: [(String, String, String, DetailPage)] {
        [
            ("Безопасность", "Автоподключение, DNS и российские сайты", "shield", .security),
            ("Подключение", "Протокол, failover и антиблокировка", "point.3.connected.trianglepath.dotted", .connection),
            ("Диагностика", "Проверка и автоматическое исправление", "waveform.path.ecg", .diagnostics),
            ("Мои серверы", "Избранное и история подключений", "star", .activity),
            ("Системные настройки", "Ядро, туннель и служебные параметры", "slider.horizontal.3", .systemWarning),
        ]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(kicker: "АККАУНТ / ALD–0248", title: "Профиль", subtitle: "Управление приложением и безопасностью")

                HStack(spacing: 16) {
                    Text("A")
                        .font(.system(size: 30, weight: .medium, design: .monospaced))
                        .foregroundStyle(DS.acid)
                        .frame(width: 62, height: 62)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.25)))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ").microLabel(color: .white.opacity(0.45))
                        Text("Ваш профиль").font(.system(size: 19, weight: .semibold))
                        Text(model.isProtected ? "Статус: Защищено" : "Статус: Отключено")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").foregroundStyle(DS.acid)
                }
                .padding(.horizontal, 16)
                .frame(height: 116)
                .background(DS.ink)
                .foregroundStyle(.white)
                .padding(.top, 28)

                HStack(spacing: 0) {
                    ProfileStat(label: "ПОДПИСОК", value: String(format: "%02d", model.subscriptions.count))
                    ProfileStat(label: "УСТРОЙСТВ", value: deviceCountLabel)
                    ProfileStat(label: "ЗАЩИЩЕНО", value: model.isProtected ? model.runtimeText : "00:00")
                }
                .frame(height: 76)
                .overlay(alignment: .bottom) { Hairline() }

                sectionHeader("АККАУНТ", "01")
                    .padding(.top, 18)
                UtilityProfileRow(mark: "DEV", title: "Устройства", detail: "Активные сеансы и лимит тарифа") {
                    utility = .devices
                }
                UtilityProfileRow(mark: "PAY", title: "Платежи", detail: "История оплат и возвратов") {
                    utility = .payments
                }
                UtilityProfileRow(mark: "PROMO", title: "Промокод", detail: "Активировать код от VPN Direct", accent: true) {
                    utility = .promo
                }
                UtilityProfileRow(mark: "HELP", title: "Поддержка", detail: "Оплата, вход, подписка и подключение") {
                    utility = .support
                }
                UtilityProfileRow(mark: "LINK", title: "Способы входа", detail: "Apple, email и Telegram — безопасная склейка") {
                    utility = .linking
                }

                sectionHeader("НАСТРОЙКИ", "02")
                    .padding(.top, 18)
                VStack(spacing: 0) {
                    ForEach(Array(settings.enumerated()), id: \.offset) { index, item in
                        Button {
                            model.openDetail(item.3)
                        } label: {
                            HStack(spacing: 13) {
                                Text(String(format: "%02d", index + 1)).microLabel()
                                Image(systemName: item.2).frame(width: 23)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.0).font(.system(size: 14, weight: .semibold))
                                    Text(item.1).font(.system(size: 10)).foregroundStyle(DS.muted)
                                }
                                Spacer()
                                Image(systemName: "arrow.right").font(.system(size: 11))
                            }
                            .frame(height: 67)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(HapticButtonStyle())
                        .overlay(alignment: .bottom) { Hairline() }
                    }
                }
                .padding(.top, 5)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .sheet(item: $utility) { page in
            Group {
                switch page {
                case .devices: DirectDevicesView(model: model)
                case .payments: DirectPaymentHistoryView(model: model)
                case .promo: DirectPromoView()
                case .support: DirectSupportView()
                case .linking: DirectAccountLinkingView()
                }
            }
            .background(DS.paper.ignoresSafeArea())
            .tint(DS.ink)
        }
    }

    private var deviceCountLabel: String {
        let limit = model.hasPremiumEntitlement ? model.premiumDeviceLimit : model.selectedPlan.devices
        return String(format: "%02d", max(1, min(limit, 99)))
    }

    private func sectionHeader(_ title: String, _ number: String) -> some View {
        HStack {
            Text(number).microLabel(color: DS.ink)
            Text(title).microLabel(color: DS.ink)
            Spacer()
        }
        .frame(height: 36)
        .overlay(alignment: .top) { Hairline(color: DS.ink) }
    }
}

private struct UtilityProfileRow: View {
    let mark: String
    let title: String
    let detail: String
    var accent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(mark)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent ? DS.acid : DS.ink)
                    .frame(width: 42, height: 42)
                    .background(accent ? DS.ink : Color.white.opacity(0.38))
                    .overlay(Rectangle().stroke(accent ? Color.clear : DS.line))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(detail).font(.system(size: 10)).foregroundStyle(DS.muted)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 11))
            }
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .overlay(alignment: .bottom) { Hairline() }
    }
}

private struct ProfileStat: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).microLabel()
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 12)
        .overlay(alignment: .leading) { Hairline().frame(width: 1) }
    }
}

#endif
