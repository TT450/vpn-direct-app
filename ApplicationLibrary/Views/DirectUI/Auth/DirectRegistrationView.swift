import SwiftUI

#if os(iOS)
struct DirectRegistrationView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var showPassword = false
    @State private var showConfirmation = false
    let onRegister: (String, String, String, String) -> Void
    let onApple: () -> Void
    let onGoogle: () -> Void
    let onTelegram: () -> Void
    let onLogin: () -> Void

    var body: some View {
        AuthPageShell(kicker: "ACCOUNT / NEW", title: "Регистрация", subtitle: "Создайте аккаунт VPN Direct.") {
            VStack(alignment: .leading, spacing: 11) {
                AuthField(title: "ИМЯ", placeholder: "Как к вам обращаться", text: $name)
                AuthField(title: "EMAIL", placeholder: "you@example.com", text: $email)
                AuthPasswordField(title: "ПАРОЛЬ", placeholder: "Минимум 8 символов", text: $password, revealed: $showPassword)
                AuthPasswordField(title: "ПОВТОРИТЕ ПАРОЛЬ", placeholder: "Введите пароль ещё раз", text: $confirmation, revealed: $showConfirmation)
                Text("Создавая аккаунт, вы соглашаетесь с условиями использования и политикой конфиденциальности.")
                    .font(.system(size: 9)).foregroundStyle(DS.muted).fixedSize(horizontal: false, vertical: true)
                AuthPrimaryButton(title: "СОЗДАТЬ АККАУНТ", icon: "arrow.right") { onRegister(name, email, password, confirmation) }
                Hairline().padding(.vertical, 4)
                AuthSecondaryButton(title: "Продолжить с Apple", icon: "apple.logo", action: onApple)
                AuthSecondaryButton(title: "Продолжить с Google", icon: "g.circle", action: onGoogle)
                AuthSecondaryButton(title: "Продолжить с Telegram", icon: "paperplane.fill", action: onTelegram)
                Button("Уже есть аккаунт? Войти", action: onLogin)
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(DS.ink)
                    .frame(maxWidth: .infinity).padding(.top, 4)
            }
        }
    }
}
#endif
