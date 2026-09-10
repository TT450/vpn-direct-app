import SwiftUI

#if os(iOS)
struct DirectAuthMethodSelectionView: View {
    let onEmail: () -> Void
    let onApple: () -> Void
    let onGoogle: () -> Void
    let onTelegram: () -> Void

    var body: some View {
        AuthPageShell(kicker: "ACCOUNT / SIGN IN", title: "Вход", subtitle: "Выберите удобный способ входа в VPN Direct.") {
            VStack(spacing: 10) {
                AuthPrimaryButton(title: "ВОЙТИ ПО EMAIL", icon: "envelope", action: onEmail)
                AuthSecondaryButton(title: "Продолжить с Apple", icon: "apple.logo", action: onApple)
                AuthSecondaryButton(title: "Продолжить с Google", icon: "g.circle", action: onGoogle)
                AuthSecondaryButton(title: "Продолжить с Telegram", icon: "paperplane.fill", action: onTelegram)
            }
        }
    }
}
#endif
