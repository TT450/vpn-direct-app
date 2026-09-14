import Library
import SwiftUI

#if os(iOS)

/// Profile section containing user-facing legal documents and application metadata.
struct DirectLegalInformationSection: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var showDeleteConfirmation = false
    @State private var deletionInProgress = false
    @State private var deletionError: String?

    private let privacyURL = URL(string: "https://vpn-direct.com/privacy.html")!
    private let termsURL = URL(string: "https://vpn-direct.com/terms.html")!
    private let eulaURL = URL(string: "https://vpn-direct.com/eula.html")!
    private let vpnDataURL = URL(string: "https://vpn-direct.com/vpn-data.html")!
    private let pricingTermsURL = URL(string: "https://vpn-direct.com/pricing-terms.html")!
    private let refundURL = URL(string: "https://vpn-direct.com/refund-policy.html")!
    private let licenseURL = URL(string: "https://vpn-direct.com/open-source-licenses.html")!
    private let noticeURL = URL(string: "https://vpn-direct.com/third-party-notices.html")!
    private let appStoreURL = URL(string: "https://apps.apple.com/ru/app/id6807402257")!

    private var core: VPNDirectCoreCapabilities {
        VPNDirectCoreCapabilities.current
    }

    var body: some View {
        VStack(spacing: 0) {
            LegalProfileRow(
                icon: "hand.raised.fill",
                title: "Политика конфиденциальности",
                subtitle: "Какие данные обрабатываются, зачем и как удаляются",
                url: privacyURL
            )
            LegalProfileRow(
                icon: "doc.text",
                title: "Условия использования",
                subtitle: "Правила использования приложения и сервиса",
                url: termsURL
            )
            LegalProfileRow(
                icon: "apple.logo",
                title: "EULA",
                subtitle: "Стандартное лицензионное соглашение App Store",
                url: eulaURL
            )
            LegalProfileRow(
                icon: "lock.shield",
                title: "VPN и обработка данных",
                subtitle: "Обработка данных VPN‑соединения и ограничения их использования",
                url: vpnDataURL
            )
            LegalProfileRow(
                icon: "creditcard",
                title: "Тарифы и условия сервиса",
                subtitle: "Стоимость и условия предоставления VPN‑ресурса",
                url: pricingTermsURL
            )
            LegalProfileRow(
                icon: "arrow.uturn.backward.circle",
                title: "Возврат App Store",
                subtitle: "Запрос возврата платежа, проведённого через Apple",
                url: refundURL
            )
            LegalProfileRow(
                icon: "doc.badge.gearshape",
                title: "Лицензия открытого кода",
                subtitle: "Лицензионные условия исходного кода приложения",
                url: licenseURL
            )
            LegalProfileRow(
                icon: "shippingbox",
                title: "Уведомления о компонентах",
                subtitle: "Third‑party notices и сведения о сторонних компонентах",
                url: noticeURL
            )

            HStack {
                Text("О ПРИЛОЖЕНИИ").microLabel(color: DS.ink)
                Spacer()
            }
            .frame(height: 36)
            .overlay(alignment: .top) { Hairline(color: DS.ink) }
            .padding(.top, 18)

            VStack(spacing: 0) {
                AboutAppRow(label: "НАЗВАНИЕ", value: "VPN Direct")
                AboutAppRow(label: "ВЕРСИЯ", value: "\(Bundle.main.version) (\(Bundle.main.versionNumber))")
                AboutAppRow(label: "ЯДРО", value: "\(core.coreName) · \(core.coreVersion)")
                AboutAppRow(label: "SING-BOX", value: core.singBoxVersion)
                AboutAppRow(label: "VPN ENGINE", value: "Network Extension · Packet Tunnel")
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 4)
            .background(DS.panel)
            .foregroundStyle(.white)
            .padding(.top, 5)

            Link(destination: appStoreURL) {
                HStack(spacing: 13) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.10, green: 0.42, blue: 1.0))
                        .frame(width: 25)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Оценить в App Store")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.ink)
                        Text("Открыть страницу VPN Direct в App Store")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.muted)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.muted)
                }
                .frame(minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())
            .overlay(alignment: .bottom) { Hairline() }
            .padding(.top, 5)

            Button {
                guard !deletionInProgress else { return }
                HapticManager.shared.play(.warning)
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: 13) {
                    Image(systemName: "person.crop.circle.badge.minus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.danger)
                        .frame(width: 25)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Удалить аккаунт")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.danger)
                        Text("Безвозвратно удалить данные аккаунта с сервера")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.muted)
                    }
                    Spacer()
                    if deletionInProgress {
                        ProgressView()
                            .tint(DS.danger)
                    } else {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DS.danger)
                    }
                }
                .frame(minHeight: 67)
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())
            .disabled(deletionInProgress)
            .overlay(alignment: .bottom) { Hairline() }
            .padding(.top, 18)

            if let deletionError {
                Text(deletionError)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DS.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
        .alert("Удалить аккаунт?", isPresented: $showDeleteConfirmation) {
            Button("Удалить аккаунт", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Все данные этого аккаунта, хранящиеся на сервере, будут удалены. Это действие нельзя отменить.")
        }
    }

    @MainActor
    private func deleteAccount() async {
        guard !deletionInProgress else { return }
        deletionError = nil
        deletionInProgress = true
        defer { deletionInProgress = false }

        DirectBackendRuntime.warmUp()
        guard let deleteAccount = DirectBackendRuntime.deleteAccount else {
            deletionError = "Удаление аккаунта пока недоступно."
            HapticManager.shared.play(.error)
            return
        }

        do {
            try await deleteAccount(model)
            if let logout = DirectBackendRuntime.logout {
                await logout(model)
            }
            HapticManager.shared.play(.authSuccess)
        } catch {
            deletionError = error.localizedDescription
            HapticManager.shared.play(.error)
        }
    }
}

private struct LegalProfileRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DS.ink)
                    .frame(width: 25)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.ink)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(DS.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.muted)
            }
            .frame(minHeight: 67)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .overlay(alignment: .bottom) { Hairline() }
    }
}

private struct AboutAppRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .microLabel(color: .white.opacity(0.42))
                .frame(width: 84, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) { Hairline(color: .white.opacity(0.10)) }
    }
}

#endif
