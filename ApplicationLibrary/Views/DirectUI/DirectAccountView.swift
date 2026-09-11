import SwiftUI

#if os(iOS)

/// Direct account screen — login / logout / switch independent accounts.
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
                        ? "Сессия только этого аккаунта — другие способы входа независимы"
                        : "Нужен для оплаты. Способы входа не объединяются"
                )
                .padding(.top, DS.pageTop)

                if model.isDirectAuthenticated {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("СЕССИЯ · \(model.authMethodLabel.uppercased())").microLabel(color: DS.acid)
                        Text(model.accountDisplayTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        if let kind = model.directAccountKind {
                            Text(kind == "telegram" ? "Аккаунт Telegram" : "Аккаунт приложения")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.55))
                        }
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
                        row("Обновить аккаунт", "Синхронизация подписки этого аккаунта")
                    }

                    Button {
                        model.openDetail(.authBot)
                    } label: {
                        row("Код из бота", "Вход в аккаунт @vpndirectbot")
                    }

                    Button {
                        model.openDetail(.authPhone)
                    } label: {
                        row("По номеру телефона", "Отдельный app-аккаунт")
                    }

                    Button {
                        model.openAuthFromAccount()
                    } label: {
                        row("Другой способ входа", "Email, Apple, Google — тоже отдельные аккаунты")
                    }

                    Button {
                        Task {
                            busy = true
                            await model.logoutDirectAccount()
                            busy = false
                        }
                    } label: {
                        row("Выйти", "Завершить сессию")
                    }
                } else {
                    Text(
                        "Email, Apple, Google, телефон и код из бота — независимые аккаунты. "
                            + "Просмотр тарифов и импорт внешних подписок доступны без регистрации."
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
        .alert("Другой аккаунт", isPresented: $model.authAccountSwitchWarning) {
            Button("Продолжить", role: .destructive) { model.confirmAccountSwitchAndContinue() }
            Button("Отмена", role: .cancel) { model.cancelAccountSwitch() }
        } message: {
            Text("Новый вход откроет другой независимый аккаунт. Текущая подписка останется на прежнем.")
        }
    }

    private func row(_ title: String, _ subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(subtitle).font(.system(size: 10)).foregroundStyle(DS.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.muted)
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { Hairline() }
        .foregroundStyle(DS.ink)
    }

    private func accountPrimaryAction(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(DS.ink)
            .foregroundStyle(.white)
    }

    private func accountSecondaryAction(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(Rectangle().stroke(DS.line))
            .foregroundStyle(DS.ink)
    }
}

#endif
