import SwiftUI

#if os(iOS)
struct DirectTelegramLoginView: View {
    @State private var username = ""
    let onContinue: (String) -> Void
    let onBack: () -> Void

    var body: some View {
        AuthPageShell(kicker: "ACCOUNT / TELEGRAM", title: "Вход через Telegram", subtitle: "Укажите Telegram-аккаунт, который хотите связать с VPN Direct.") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TELEGRAM").microLabel(color: DS.ink)
                    Text("Укажите username в формате @username. После этого приложение запустит подтверждение входа через ваш Telegram.")
                        .font(.system(size: 11)).foregroundStyle(DS.muted).fixedSize(horizontal: false, vertical: true)
                }
                .padding(14).background(DS.panel.opacity(0.08)).overlay(Rectangle().stroke(DS.line))
                AuthField(title: "TELEGRAM USERNAME", placeholder: "@username", text: $username)
                AuthPrimaryButton(title: "ПРОДОЛЖИТЬ", icon: "paperplane.fill") { onContinue(username) }
                Text("VPN Direct не запрашивает пароль Telegram.")
                    .font(.system(size: 9)).foregroundStyle(DS.muted)
                Button("← Назад", action: onBack)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(DS.muted).padding(.top, 4)
            }
        }
    }
}
#endif
