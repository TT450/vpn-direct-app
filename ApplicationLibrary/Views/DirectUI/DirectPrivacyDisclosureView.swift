import SwiftUI

#if os(iOS)

/// First-use disclosure required before the user can activate the VPN tunnel.
/// The view is intentionally non-dismissible: the user must explicitly accept or decline.
struct DirectPrivacyDisclosureView: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    private let privacyURL = URL(string: "https://vpn-direct.com/privacy")!
    private let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let serviceURL = URL(string: "https://vpn-direct.com/pricing")!

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                DS.ink.opacity(0.22)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())

                disclosurePanel
                    .frame(width: max(0, proxy.size.width - 40), height: max(0, proxy.size.height - 108))
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
        .zIndex(100)
    }

    private var disclosurePanel: some View {
        VStack(spacing: 0) {
            panelHeader
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("ПЕРЕД ПОДКЛЮЧЕНИЕМ")
                        .microLabel(color: DS.acid)

                    Text("VPN DIRECT И ВАША ПРИВАТНОСТЬ")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("VPN Direct создаёт системное VPN‑подключение и направляет сетевой трафик через выбранный маршрут. Перед первым использованием мы обязаны ясно объяснить, какие данные обрабатываются и для чего.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)

                    disclosureBlock(
                        index: "01",
                        title: "ЧТО МЫ НЕ СОБИРАЕМ",
                        text: "Мы не записываем содержимое вашего трафика, историю посещённых сайтов или DNS‑запросы и не используем VPN‑активность для рекламного профилирования."
                    )

                    disclosureBlock(
                        index: "02",
                        title: "ЧТО МОЖЕТ ОБРАБАТЫВАТЬСЯ",
                        text: "Для работы аккаунта, подписки и поддержки могут обрабатываться необходимые служебные сведения — например идентификатор аккаунта, данные подписки и платежа. Подробный перечень и сроки хранения указаны в Политике конфиденциальности."
                    )

                    disclosureBlock(
                        index: "03",
                        title: "КАК ИСПОЛЬЗУЮТСЯ ДАННЫЕ",
                        text: "Данные используются для работы сервиса, выдачи и обслуживания доступа, поддержки и выполнения обязательных юридических требований. Данные, полученные через VPN‑соединение, не продаются, не используются для рекламы и не раскрываются третьим лицам."
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ДОКУМЕНТЫ")
                            .microLabel(color: .white.opacity(0.42))

                        documentLink("Политика конфиденциальности", url: privacyURL)
                        documentLink("Условия использования / EULA", url: eulaURL)
                        documentLink("Тарифы и условия сервиса", url: serviceURL)
                    }
                    .padding(.top, 2)

                    Text("Нажимая «СОГЛАСИТЬСЯ», вы подтверждаете, что ознакомились с этим уведомлением и разрешаете VPN Direct использовать системное VPN‑подключение на этом устройстве.")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.48))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 22)
            }

            actions
        }
        .background(DS.ink)
        .overlay(Rectangle().stroke(DS.acid.opacity(0.72), lineWidth: 1))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DS.acid)
                .frame(height: 3)
        }
        .shadow(color: .black.opacity(0.30), radius: 28, y: 14)
    }

    private var panelHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("VPN DIRECT")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text("PRIVACY DISCLOSURE / 5.4")
                    .microLabel(color: .white.opacity(0.42))
            }
            Spacer()
            Text("REQUIRED")
                .microLabel(color: DS.acid)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .overlay(Rectangle().stroke(DS.acid.opacity(0.65), lineWidth: 1))
        }
        .padding(.horizontal, 20)
        .frame(height: 62)
        .overlay(alignment: .bottom) { Hairline(color: .white.opacity(0.14)) }
    }

    private func disclosureBlock(index: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(index)
                .microLabel(color: DS.acid)
                .frame(width: 22, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(text)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 12)
        .overlay(alignment: .top) { Hairline(color: .white.opacity(0.10)) }
    }

    private func documentLink(_ title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.acid)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS.acid)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .overlay(Rectangle().stroke(DS.line.opacity(0.8), lineWidth: 1))
        }
        .buttonStyle(HapticButtonStyle())
    }

    private var actions: some View {
        HStack(spacing: 0) {
            Button {
                HapticManager.shared.play(.warning)
                onDecline()
            } label: {
                Text("ОТКАЗАТЬСЯ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.68))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())
            .overlay(alignment: .trailing) { Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 30) }

            Button {
                HapticManager.shared.play(.authSuccess)
                onAccept()
            } label: {
                HStack(spacing: 7) {
                    Text("СОГЛАСИТЬСЯ")
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(DS.acid)
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())
        }
        .overlay(alignment: .top) { Hairline(color: .white.opacity(0.14)) }
    }
}

#endif
