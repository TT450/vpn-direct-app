import Library
import SwiftUI

#if os(iOS)

struct DirectProfilePage: View {
    @ObservedObject var model: VPNConnectionModel
    @ObservedObject private var balanceFlow = DirectBalanceFlow.shared
    @State private var utility: UtilityPage?

    private enum UtilityPage: String, Identifiable {
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
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 16) {
                    Text(model.isDirectAuthenticated ? "D" : "A")
                        .font(.system(size: 30, weight: .medium, design: .monospaced))
                        .foregroundStyle(DS.acid)
                        .frame(width: 62, height: 62)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.25)))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("DIRECT ACCOUNT").microLabel(color: .white.opacity(0.45))
                        Text(model.isDirectAuthenticated
                             ? model.accountDisplayTitle
                             : "Войти в Direct")
                            .font(.system(size: 19, weight: .semibold))
                            .lineLimit(1)
                        Text(model.isDirectAuthenticated
                             ? "\(model.authMethodLabel) · только этот аккаунт"
                             : "Оплата и вход")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "arrow.up.right").foregroundStyle(DS.acid)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 116)
                .background(DS.ink)
                .foregroundStyle(.white)
                .contentShape(Rectangle())
                .onTapGesture {
                    if model.isDirectAuthenticated {
                        model.openDetail(.account)
                    } else {
                        model.openAuthFromAccount()
                    }
                    HapticManager.shared.play(.selection)
                }

                balanceCard
                    .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, DS.pageTop)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.paper)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("АККАУНТ", "01")
                        .padding(.top, 10)
                    UtilityProfileRow(mark: "PROMO", title: "Промокод", detail: "Активировать код от VPN Direct", accent: true) {
                        utility = .promo
                    }
                    UtilityProfileRow(mark: "HELP", title: "Поддержка", detail: "Оплата, вход, подписка и подключение") {
                        utility = .support
                    }
                    UtilityProfileRow(mark: "LINK", title: "Способы входа", detail: "Apple, email и бот — безопасная склейка") {
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
                                            .lineLimit(1)
                                        Text(item.1).font(.system(size: 10)).foregroundStyle(DS.muted)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "arrow.right").font(.system(size: 11))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 67)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(HapticButtonStyle())
                            .overlay(alignment: .bottom) { Hairline() }
                        }
                    }
                    .padding(.top, 5)

                    sectionHeader("ЮРИДИЧЕСКАЯ ИНФОРМАЦИЯ", "03")
                        .padding(.top, 18)
                    DirectLegalInformationSection(model: model)
                        .padding(.top, 5)
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.paper.ignoresSafeArea())
        .sheet(item: $utility) { page in
            Group {
                switch page {
                case .promo: DirectPromoView(model: model)
                case .support: DirectSupportView()
                case .linking: DirectAccountLinkingView(model: model)
                }
            }
            .background(DS.paper.ignoresSafeArea())
            .tint(DS.ink)
            .modifier(DirectUtilitySheetChrome())
        }
        .task {
            await balanceFlow.refresh()
        }
    }

    private var balanceCard: some View {
        Button {
            HapticManager.shared.play(.selection)
            model.openDetail(.balanceAccount)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("БАЛАНС").microLabel(color: .white.opacity(0.42))
                    Text(balanceFlow.balanceDisplay)
                        .font(.system(size: 26, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("Пополнение и история")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.48))
                }
                Spacer(minLength: 8)
                Text("USD")
                    .microLabel(color: DS.acid)
                    .frame(width: 48, height: 48)
                    .overlay(Rectangle().stroke(DS.acid.opacity(0.5)))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.ink)
            .overlay(Rectangle().stroke(DS.acid.opacity(0.7)))
        }
        .buttonStyle(HapticButtonStyle())
    }

    private func sectionHeader(_ title: String, _ number: String) -> some View {
        HStack {
            Text(number).microLabel(color: DS.ink)
            Text(title).microLabel(color: DS.ink)
            Spacer()
        }
        .frame(height: 36)
    }
}

/// Same presentation chrome as server picker / connection sheets: flat corners, drag handle, detents.
private struct DirectUtilitySheetChrome: ViewModifier {
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

#endif
