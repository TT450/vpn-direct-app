import SwiftUI

#if os(iOS)

/// Direct account screen — login / logout / link bot / refresh from backend.
struct DirectAccountView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(
                    kicker: "VPN DIRECT / АККАУНТ",
                    title: model.isDirectAuthenticated ? "Аккаунт" : "Вход",
                    subtitle: model.isDirectAuthenticated
                        ? "Управление Direct-сессией на \(DirectBackend.host)"
                        : "Нужен только для оплаты и синхронизации с ботом"
                )
                .padding(.top, DS.pageTop)

                if model.isDirectAuthenticated {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("СЕССИЯ").microLabel(color: DS.acid)
                        Text(model.directAccountEmail ?? "Авторизован")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        if let url = model.directSubscriptionURL {
                            Text(url)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(2)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.panel)
                    .padding(.top, 22)

                    Button {
                        Task {
                            busy = true
                            await model.refreshDirectAccount()
                            busy = false
                            message = "Обновлено"
                        }
                    } label: {
                        row("Обновить с бека", "GET /api/v1/me")
                    }

                    Button {
                        model.authFlowReturnsToAccount = true
                        model.checkoutAuthError = nil
                        model.openDetail(.authBot)
                    } label: {
                        row("Привязать бота", "Код из Telegram")
                    }

                    Button {
                        model.openAuthFromAccount()
                    } label: {
                        row("Другой способ входа", "Email, Apple, восстановление")
                    }

                    Button {
                        Task {
                            busy = true
                            await model.logoutDirectAccount()
                            busy = false
                        }
                    } label: {
                        row("Выйти", "Сбросить session token")
                    }
                } else {
                    Text(
                        "Войдите по Email, Apple или коду из бота. Просмотр тарифов и импорт внешних подписок "
                            + "доступны без регистрации."
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(DS.muted)
                    .lineSpacing(4)
                    .padding(.top, 22)

                    Button {
                        model.openAuthFromAccount()
                    } label: {
                        accountPrimaryAction("Войти")
                    }
                    .padding(.top, 20)

                    Button {
                        model.authFlowReturnsToAccount = true
                        model.checkoutAuthError = nil
                        model.openDetail(.authRegister)
                    } label: {
                        accountSecondaryAction("Регистрация")
                    }
                    .padding(.top, 8)
                }

                if let message {
                    Text(message).font(.system(size: 11)).foregroundStyle(DS.muted).padding(.top, 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
            .disabled(busy)
        }
        .background(DS.paper.ignoresSafeArea())
        .buttonStyle(HapticButtonStyle())
    }

    private func row(_ title: String, _ subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(subtitle).font(.system(size: 10)).foregroundStyle(DS.muted)
            }
            Spacer()
            Image(systemName: "arrow.right").font(.system(size: 11))
        }
        .frame(minHeight: 64)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func accountPrimaryAction(_ title: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "arrow.right")
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(DS.acid)
        .padding(.horizontal, 15)
        .frame(height: 50)
        .background(DS.ink)
    }

    private func accountSecondaryAction(_ title: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "arrow.right")
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(DS.ink)
        .padding(.horizontal, 15)
        .frame(height: 50)
        .overlay(Rectangle().stroke(DS.ink))
    }
}

#endif
