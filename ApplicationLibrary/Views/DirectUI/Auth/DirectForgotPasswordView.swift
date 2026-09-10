import SwiftUI

#if os(iOS)
struct DirectForgotPasswordView: View {
    @State private var email = ""
    let onReset: (String) -> Void
    let onBack: () -> Void

    var body: some View {
        AuthPageShell(kicker: "ACCOUNT / PASSWORD", title: "Восстановление пароля", subtitle: "Отправим ссылку для сброса пароля на вашу почту.") {
            VStack(alignment: .leading, spacing: 14) {
                AuthField(title: "EMAIL", placeholder: "you@example.com", text: $email)
                AuthPrimaryButton(title: "ОТПРАВИТЬ ССЫЛКУ", icon: "arrow.right") { onReset(email) }
                Text("Если письмо не пришло, проверьте папку «Спам».")
                    .font(.system(size: 9)).foregroundStyle(DS.muted)
                Button("← Вернуться ко входу", action: onBack)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(DS.muted)
            }
        }
    }
}
#endif
