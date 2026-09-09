import SwiftUI

#if os(iOS)

// MARK: - Auth shared UI

private enum DirectAuthUI {
    static let fieldFill = Color.white.opacity(0.45)
}

private struct DirectAuthShell<Content: View>: View {
    let kicker: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(kicker: kicker, title: title, subtitle: subtitle)
                    .padding(.top, DS.pageTop)
                    .padding(.bottom, 24)
                content()
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20)
        }
        .background(DS.paper.ignoresSafeArea())
    }
}

private struct DirectAuthField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var secure = false
    @Binding var revealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).microLabel(color: DS.ink)
            HStack(spacing: 9) {
                Group {
                    if secure && !revealed {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                if secure {
                    Button { revealed.toggle() } label: {
                        Image(systemName: revealed ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 13)
            .frame(height: 50)
            .background(DirectAuthUI.fieldFill)
            .overlay(Rectangle().stroke(DS.line))
        }
    }
}

private struct DirectAuthPrimaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: icon)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(DS.acid)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(DS.ink)
        }
        .buttonStyle(HapticButtonStyle())
    }
}

private struct DirectAuthProviderButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 19)
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.muted)
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(DS.ink)
            .padding(.horizontal, 13)
            .frame(height: 48)
            .background(DirectAuthUI.fieldFill)
            .overlay(Rectangle().stroke(DS.line))
        }
        .buttonStyle(HapticButtonStyle())
    }
}

private struct DirectAuthDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            Hairline()
            Text("ИЛИ").microLabel(color: DS.muted)
            Hairline()
        }
        .padding(.vertical, 15)
    }
}

// MARK: - Welcome

struct DirectAuthWelcomeView: View {
    let onEmail: () -> Void
    let onApple: () -> Void
    let onGoogle: () -> Void
    let onTelegram: () -> Void
    let onRegister: () -> Void

    init(onEmail: @escaping () -> Void = {}, onApple: @escaping () -> Void = {}, onGoogle: @escaping () -> Void = {}, onTelegram: @escaping () -> Void = {}, onRegister: @escaping () -> Void = {}) {
        self.onEmail = onEmail; self.onApple = onApple; self.onGoogle = onGoogle; self.onTelegram = onTelegram; self.onRegister = onRegister
    }

    var body: some View {
        DirectAuthShell(kicker: "VPN DIRECT / ACCOUNT", title: "Добро пожаловать", subtitle: "Войдите, чтобы управлять VPN Direct и своими подписками.") {
            VStack(spacing: 10) {
                DirectAuthPrimaryButton(title: "ВОЙТИ ПО EMAIL", icon: "arrow.right", action: onEmail)
                DirectAuthDivider()
                DirectAuthProviderButton(title: "Продолжить с Apple", icon: "apple.logo", action: onApple)
                DirectAuthProviderButton(title: "Продолжить с Google", icon: "g.circle", action: onGoogle)
                DirectAuthProviderButton(title: "Продолжить с Telegram", icon: "paperplane.fill", action: onTelegram)
                Hairline().padding(.vertical, 8)
                Button(action: onRegister) {
                    HStack(spacing: 5) {
                        Text("Нет аккаунта?").foregroundStyle(DS.muted)
                        Text("Зарегистрироваться").fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(DS.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(HapticButtonStyle())
            }
        }
    }
}

// MARK: - Email login

struct DirectEmailLoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var revealed = false
    let onLogin: (String, String) -> Void
    let onForgotPassword: () -> Void
    let onRegister: () -> Void
    let onBack: () -> Void

    init(onLogin: @escaping (String, String) -> Void = { _, _ in }, onForgotPassword: @escaping () -> Void = {}, onRegister: @escaping () -> Void = {}, onBack: @escaping () -> Void = {}) {
        self.onLogin = onLogin; self.onForgotPassword = onForgotPassword; self.onRegister = onRegister; self.onBack = onBack
    }

    var body: some View {
        DirectAuthShell(kicker: "ACCOUNT / EMAIL", title: "Вход", subtitle: "Введите данные аккаунта VPN Direct.") {
            VStack(alignment: .leading, spacing: 14) {
                DirectAuthField(label: "EMAIL", placeholder: "you@example.com", text: $email, revealed: .constant(false))
                DirectAuthField(label: "ПАРОЛЬ", placeholder: "Введите пароль", text: $password, secure: true, revealed: $revealed)
                Button("Забыли пароль?", action: onForgotPassword)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.ink)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .buttonStyle(.plain)
                DirectAuthPrimaryButton(title: "ВОЙТИ", icon: "arrow.right") { onLogin(email, password) }
                Hairline().padding(.vertical, 5)
                HStack(spacing: 5) {
                    Text("Нет аккаунта?").foregroundStyle(DS.muted)
                    Button("Зарегистрироваться", action: onRegister).fontWeight(.semibold).foregroundStyle(DS.ink)
                }
                .font(.system(size: 11))
                Button("← Назад", action: onBack)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.muted)
                    .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Registration

struct DirectRegistrationView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var revealed = false
    @State private var confirmationRevealed = false
    let onRegister: (String, String, String, String) -> Void
    let onApple: () -> Void
    let onGoogle: () -> Void
    let onTelegram: () -> Void
    let onLogin: () -> Void

    init(onRegister: @escaping (String, String, String, String) -> Void = { _, _, _, _ in }, onApple: @escaping () -> Void = {}, onGoogle: @escaping () -> Void = {}, onTelegram: @escaping () -> Void = {}, onLogin: @escaping () -> Void = {}) {
        self.onRegister = onRegister; self.onApple = onApple; self.onGoogle = onGoogle; self.onTelegram = onTelegram; self.onLogin = onLogin
    }

    var body: some View {
        DirectAuthShell(kicker: "ACCOUNT / NEW", title: "Регистрация", subtitle: "Создайте аккаунт VPN Direct за минуту.") {
            VStack(alignment: .leading, spacing: 12) {
                DirectAuthField(label: "ИМЯ", placeholder: "Как к вам обращаться", text: $name, revealed: .constant(false))
                DirectAuthField(label: "EMAIL", placeholder: "you@example.com", text: $email, revealed: .constant(false))
                DirectAuthField(label: "ПАРОЛЬ", placeholder: "Минимум 8 символов", text: $password, secure: true, revealed: $revealed)
                DirectAuthField(label: "ПОВТОРИТЕ ПАРОЛЬ", placeholder: "Введите пароль ещё раз", text: $confirmation, secure: true, revealed: $confirmationRevealed)
                Text("Создавая аккаунт, вы соглашаетесь с условиями использования и политикой конфиденциальности.")
                    .font(.system(size: 9)).foregroundStyle(DS.muted).fixedSize(horizontal: false, vertical: true)
                DirectAuthPrimaryButton(title: "СОЗДАТЬ АККАУНТ", icon: "arrow.right") { onRegister(name, email, password, confirmation) }
                DirectAuthDivider()
                DirectAuthProviderButton(title: "Продолжить с Apple", icon: "apple.logo", action: onApple)
                DirectAuthProviderButton(title: "Продолжить с Google", icon: "g.circle", action: onGoogle)
                DirectAuthProviderButton(title: "Продолжить с Telegram", icon: "paperplane.fill", action: onTelegram)
                HStack(spacing: 5) {
                    Text("Уже есть аккаунт?").foregroundStyle(DS.muted)
                    Button("Войти", action: onLogin).fontWeight(.semibold).foregroundStyle(DS.ink)
                }
                .font(.system(size: 11)).padding(.top, 4)
            }
        }
    }
}

// MARK: - Telegram

struct DirectTelegramLoginView: View {
    enum Stage { case ready, waiting, confirmed }
    @State private var stage: Stage = .ready
    @State private var username = ""
    @State private var code = ""
    let onStart: (String) -> Void
    let onConfirm: (String, String) -> Void
    let onBack: () -> Void

    init(onStart: @escaping (String) -> Void = { _ in }, onConfirm: @escaping (String, String) -> Void = { _, _ in }, onBack: @escaping () -> Void = {}) {
        self.onStart = onStart; self.onConfirm = onConfirm; self.onBack = onBack
    }

    var body: some View {
        DirectAuthShell(kicker: "ACCOUNT / TELEGRAM", title: "Вход через Telegram", subtitle: "Подтвердите Telegram-аккаунт, который хотите связать с VPN Direct.") {
            VStack(alignment: .leading, spacing: 14) {
                statusCard
                if stage == .ready {
                    DirectAuthField(label: "TELEGRAM USERNAME", placeholder: "@username", text: $username, revealed: .constant(false))
                    Text("Укажите username Telegram. Пароль Telegram здесь не нужен.")
                        .font(.system(size: 10)).foregroundStyle(DS.muted)
                    DirectAuthPrimaryButton(title: "ОТПРАВИТЬ ПОДТВЕРЖДЕНИЕ", icon: "paperplane.fill") {
                        stage = .waiting; onStart(username)
                    }
                } else if stage == .waiting {
                    VStack(alignment: .leading, spacing: 11) {
                        Text("ПРОВЕРЬТЕ TELEGRAM").microLabel(color: DS.ink)
                        Text("Откройте Telegram и подтвердите вход для этого аккаунта:")
                            .font(.system(size: 12))
                        Text("@\(username.trimmingCharacters(in: CharacterSet(charactersIn: "@")))")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        Hairline()
                        DirectAuthField(label: "КОД", placeholder: "Введите код из Telegram", text: $code, revealed: .constant(false))
                        DirectAuthPrimaryButton(title: "ПОДТВЕРДИТЬ", icon: "checkmark") { onConfirm(username, code) }
                        Button("Изменить Telegram-аккаунт") { stage = .ready }
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(DS.muted).buttonStyle(.plain)
                    }
                    .padding(14).background(DS.panel.opacity(0.08)).overlay(Rectangle().stroke(DS.line))
                } else {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("ГОТОВО").microLabel(color: DS.green)
                        Text("Telegram подтверждён").font(.system(size: 17, weight: .semibold))
                        Text("@\(username.trimmingCharacters(in: CharacterSet(charactersIn: "@")))")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(DS.muted)
                    }
                    .padding(15).frame(maxWidth: .infinity, alignment: .leading).background(DS.acid.opacity(0.35)).overlay(Rectangle().stroke(DS.ink))
                }
                Button("← Назад", action: onBack)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(DS.muted).buttonStyle(.plain)
            }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: stage == .confirmed ? "checkmark.circle.fill" : "paperplane.fill")
                .font(.system(size: 23)).foregroundStyle(stage == .confirmed ? DS.green : DS.ink)
            VStack(alignment: .leading, spacing: 3) {
                Text(stage == .ready ? "TELEGRAM" : stage == .waiting ? "ОЖИДАЕМ ПОДТВЕРЖДЕНИЕ" : "TELEGRAM ПОДТВЕРЖДЁН")
                    .microLabel(color: DS.ink)
                Text(stage == .ready ? "Сначала укажите username" : stage == .waiting ? "Подтвердите запрос в Telegram" : "Аккаунт связан с VPN Direct")
                    .font(.system(size: 10)).foregroundStyle(DS.muted)
            }
            Spacer()
        }
        .padding(13).background(DS.panel.opacity(0.07)).overlay(Rectangle().stroke(DS.line))
    }
}

// MARK: - Forgot password

struct DirectForgotPasswordView: View {
    @State private var email = ""
    let onReset: (String) -> Void
    let onBack: () -> Void

    init(onReset: @escaping (String) -> Void = { _ in }, onBack: @escaping () -> Void = {}) { self.onReset = onReset; self.onBack = onBack }

    var body: some View {
        DirectAuthShell(kicker: "ACCOUNT / PASSWORD", title: "Восстановление", subtitle: "Отправим ссылку для сброса пароля на вашу почту.") {
            VStack(alignment: .leading, spacing: 14) {
                DirectAuthField(label: "EMAIL", placeholder: "you@example.com", text: $email, revealed: .constant(false))
                DirectAuthPrimaryButton(title: "ОТПРАВИТЬ ССЫЛКУ", icon: "arrow.right") { onReset(email) }
                Text("Если письмо не пришло в течение нескольких минут, проверьте папку «Спам».")
                    .font(.system(size: 9)).foregroundStyle(DS.muted)
                Button("← Вернуться ко входу", action: onBack)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(DS.muted).buttonStyle(.plain)
            }
        }
    }
}

#endif
