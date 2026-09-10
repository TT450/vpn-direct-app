import LocalAuthentication
import SwiftUI

#if os(iOS)

struct AppLockModifier: ViewModifier {
    @State private var locked = false
    @State private var didUnlock = false
    let enabled: Bool

    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(locked)
                .blur(radius: locked ? 8 : 0)

            if locked {
                VStack(spacing: 16) {
                    Image(systemName: "faceid")
                        .font(.system(size: 44))
                        .foregroundStyle(DS.ink)
                    Text("Разблокируйте приложение")
                        .font(.system(size: 15, weight: .semibold))
                    Button("Face ID / Touch ID") {
                        authenticate()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(DS.ink)
                    .foregroundStyle(DS.acid)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DS.paper.opacity(0.96))
            }
        }
        .onAppear {
            guard enabled, !didUnlock else { return }
            locked = true
            authenticate()
        }
        .onChangeCompat(of: enabled) { isEnabled in
            if isEnabled, !didUnlock {
                locked = true
                authenticate()
            } else if !isEnabled {
                locked = false
                didUnlock = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            guard enabled else { return }
            didUnlock = false
            locked = true
            authenticate()
        }
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            locked = false
            didUnlock = true
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Подтвердите доступ к VPN Direct"
        ) { success, _ in
            Task { @MainActor in
                if success {
                    locked = false
                    didUnlock = true
                }
            }
        }
    }
}

extension View {
    func appLock(enabled: Bool) -> some View {
        modifier(AppLockModifier(enabled: enabled))
    }
}

#endif
