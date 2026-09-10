import SwiftUI

#if os(iOS)
struct DirectEmailLoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    let onLogin: (String, String) -> Void
    let onForgotPassword: () -> Void
    let onRegister: () -> Void

    var body: some View {
        AuthPageShell(kicker: "ACCOUNT / EMAIL", title: "Вход по email", subtitle: "Введите данные аккаунта VPN Direct.") {
            VStack(alignment: .leading, spacing: 13) {
                AuthField(title: "EMAIL", placeholder: "you@example.com", text: $email)
                AuthPasswordField(title: "ПАРОЛЬ", placeholder: "Введите пароль", text: $password, revealed: $showPassword)
                Button("Забыли пароль?", action: onForgotPassword)
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(DS.ink)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                AuthPrimaryButton(title: "ВОЙТИ", icon: "arrow.right") { onLogin(email, password) }
                Hairline().padding(.vertical, 5)
                Button("Создать аккаунт", action: onRegister)
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(DS.ink)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
#endif
