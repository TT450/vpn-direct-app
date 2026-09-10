import SwiftUI

#if os(iOS)
struct DirectAuthWelcomeView: View {
    let onContinue: () -> Void
    let onRegister: () -> Void

    var body: some View {
        AuthPageShell(kicker: "VPN DIRECT / ACCOUNT", title: "Добро пожаловать", subtitle: "Войдите в VPN Direct или создайте новый аккаунт.") {
            VStack(spacing: 12) {
                AuthPrimaryButton(title: "ВОЙТИ", icon: "arrow.right", action: onContinue)
                AuthSecondaryButton(title: "Создать аккаунт", icon: "plus", action: onRegister)
            }
        }
    }
}
#endif
