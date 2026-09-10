import AuthenticationServices
import SwiftUI
import WebKit

#if os(iOS)

struct PendingCheckout: Codable, Equatable {
    let title: String
    let price: Int
    let periodDays: Int
    let paymentMethodRaw: String
    let returnPage: String
    let planName: String?
    let trafficGB: Int?
    let devices: Int
    let whitelistGB: Int
    let createdAt: Date

    var paymentMethod: PaymentMethod {
        PaymentMethod(rawValue: paymentMethodRaw) ?? .apple
    }

    private static let key = "vpndirect.pending.checkout.v1"

    static var current: Self? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    static func save(_ value: Self) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}

// MARK: - Auth pages (each is its own DetailPage — no in-page route swapping)

struct DirectAuthLoginView: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        DirectAuthPageShell(
            kicker: "VPN DIRECT / ОПЛАТА",
            title: "Войти",
            subtitle: "Войдите, чтобы продолжить. Выбранный заказ сохранён."
        ) {
            if let checkout = PendingCheckout.current { DirectAuthCheckoutCard(checkout: checkout) }
            DirectAuthErrorText(model.checkoutAuthError)
            CheckoutSectionHeader(title: "БЕЗ ПАРОЛЯ", meta: "OTP").padding(.top, 22)
            CheckoutAuthRow(mark: "@", title: "Войти по Email", subtitle: "Одноразовый код на почту") {
                model.checkoutAuthError = nil
                model.openDetail(.authEmail)
            }
            CheckoutAuthRow(mark: "", title: "Войти с Apple", subtitle: "Быстрый вход через Apple") {
                Task { await model.signInWithAppleForAuth() }
            }
            CheckoutAuthRow(mark: "TG", title: "Код из Telegram-бота", subtitle: "Привязка существующей подписки") {
                model.checkoutAuthError = nil
                model.openDetail(.authBot)
            }
            CheckoutAction(title: "Создать аккаунт", secondary: true) {
                model.openDetail(.authRegister)
            }
            .padding(.top, 16)
            Button("Не получается войти") { model.openDetail(.authRecovery) }
                .font(.system(size: 10))
                .foregroundStyle(DS.muted)
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .disabled(model.checkoutAuthBusy)
        .overlay {
            if model.checkoutAuthBusy {
                ProgressView().scaleEffect(1.1)
            }
        }
    }
}

struct DirectAuthEmailView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var email = ""

    var body: some View {
        DirectAuthPageShell(
            kicker: "АККАУНТ / EMAIL",
            title: "Ваша почта",
            subtitle: "Отправим одноразовый код. Пароль не нужен."
        ) {
            DirectAuthErrorText(model.checkoutAuthError)
            TextField("name@example.com", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 14)
                .frame(height: 52)
                .overlay(Rectangle().stroke(DS.line))
                .padding(.top, 24)
            CheckoutAction(title: "Получить код") {
                Task { await model.sendEmailCodeForAuth(email: email) }
            }
            .padding(.top, 14)
        }
        .disabled(model.checkoutAuthBusy)
        .overlay {
            if model.checkoutAuthBusy {
                ProgressView().scaleEffect(1.1)
            }
        }
        .onAppear {
            if email.isEmpty, !model.checkoutAuthEmail.isEmpty {
                email = model.checkoutAuthEmail
            }
        }
    }
}

struct DirectAuthCodeView: View {
    @ObservedObject var model: VPNConnectionModel

    private var subtitle: String {
        model.checkoutAuthEmail.isEmpty
            ? "Код отправлен на вашу почту."
            : "Код отправлен на \(model.checkoutAuthEmail)."
    }

    var body: some View {
        DirectAuthPageShell(kicker: "АККАУНТ / OTP", title: "Введите код", subtitle: subtitle) {
            DirectAuthErrorText(model.checkoutAuthError)
            TextField("000000", text: $model.checkoutAuthCode)
                .keyboardType(.numberPad)
                .font(.system(size: 25, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(height: 64)
                .overlay(Rectangle().stroke(DS.line))
                .padding(.top, 28)
            CheckoutAction(title: "Подтвердить") {
                Task { await model.verifyEmailCodeForAuth() }
            }
            .padding(.top, 14)
            Button("Отправить код снова") {
                Task { await model.resendEmailCodeForAuth() }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(DS.muted)
            .frame(maxWidth: .infinity, minHeight: 42)
        }
        .disabled(model.checkoutAuthBusy)
        .overlay {
            if model.checkoutAuthBusy {
                ProgressView().scaleEffect(1.1)
            }
        }
    }
}

struct DirectAuthRegisterView: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        DirectAuthPageShell(
            kicker: "АККАУНТ / РЕГИСТРАЦИЯ",
            title: "Создать аккаунт",
            subtitle: "Регистрация проходит по Email-коду — пароль не нужен."
        ) {
            Text(
                "Аккаунт нужен только для управления Direct-подпиской и восстановления доступа. "
                    + "Просмотр тарифов и импорт внешних подписок остаются доступны без регистрации."
            )
            .font(.system(size: 11))
            .foregroundStyle(DS.muted)
            .lineSpacing(4)
            .padding(.top, 24)
            CheckoutAction(title: "Продолжить с Email") { model.openDetail(.authEmail) }
                .padding(.top, 20)
            CheckoutAction(title: "Войти с Apple", secondary: true) {
                Task { await model.signInWithAppleForAuth() }
            }
            .padding(.top, 8)
        }
        .disabled(model.checkoutAuthBusy)
        .overlay {
            if model.checkoutAuthBusy {
                ProgressView().scaleEffect(1.1)
            }
        }
    }
}

struct DirectAuthRecoveryView: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        DirectAuthPageShell(
            kicker: "АККАУНТ / ВОССТАНОВЛЕНИЕ",
            title: "Не получается войти",
            subtitle: "Восстановление — это повторный вход без пароля."
        ) {
            CheckoutAuthRow(mark: "@", title: "Получить новый код", subtitle: "Повторить вход по Email") {
                model.openDetail(.authEmail)
            }
            CheckoutAuthRow(mark: "", title: "Войти с Apple", subtitle: "Если аккаунт связан с Apple") {
                Task { await model.signInWithAppleForAuth() }
            }
            CheckoutAuthRow(mark: "TG", title: "Код из бота", subtitle: "Если подписка уже в Telegram") {
                model.openDetail(.authBot)
            }
        }
        .disabled(model.checkoutAuthBusy)
        .overlay {
            if model.checkoutAuthBusy {
                ProgressView().scaleEffect(1.1)
            }
        }
    }
}

struct DirectAuthBotView: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        DirectAuthPageShell(
            kicker: "VPN DIRECT / BOT",
            title: "Привязать подписку",
            subtitle: "Перенесите существующую подписку из VPN Direct бота."
        ) {
            DirectAuthErrorText(model.checkoutAuthError)
            TextField("XXXX-XXXX", text: $model.checkoutAuthBotCode)
                .textInputAutocapitalization(.characters)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 14)
                .frame(height: 54)
                .overlay(Rectangle().stroke(DS.line))
                .padding(.top, 24)
            CheckoutAction(title: "Привязать") {
                Task { await model.linkBotCodeForAuth() }
            }
            .padding(.top, 14)
            Text("В боте @vpndirectbot откройте «Привязать приложение» и введите код сюда.")
                .font(.system(size: 10))
                .foregroundStyle(DS.muted)
                .padding(.top, 12)
        }
        .disabled(model.checkoutAuthBusy)
        .overlay {
            if model.checkoutAuthBusy {
                ProgressView().scaleEffect(1.1)
            }
        }
    }
}

struct DirectAuthSuccessView: View {
    @ObservedObject var model: VPNConnectionModel

    private var continueTitle: String {
        if model.authFlowReturnsToAccount {
            return "Вернуться в аккаунт"
        }
        return PendingCheckout.current == nil ? "Готово" : "Продолжить оплату"
    }

    var body: some View {
        DirectAuthPageShell(
            kicker: "VPN DIRECT / ГОТОВО",
            title: "Аккаунт готов",
            subtitle: model.authFlowReturnsToAccount
                ? "Сессия сохранена. Можно вернуться в аккаунт."
                : "Возвращаем вас к оформлению заказа."
        ) {
            if let checkout = PendingCheckout.current, !model.authFlowReturnsToAccount {
                DirectAuthCheckoutCard(checkout: checkout).padding(.top, 24)
            }
            CheckoutAction(title: continueTitle) {
                model.completeAuthAfterSuccess()
            }
            .padding(.top, 16)
        }
    }
}

// MARK: - Shared auth chrome

private struct DirectAuthPageShell<Content: View>: View {
    let kicker: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(kicker: kicker, title: title, subtitle: subtitle)
                    .padding(.top, DS.pageTop)
                content()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
        }
        .background(DS.paper.ignoresSafeArea())
        .preferredColorScheme(.light)
        .buttonStyle(HapticButtonStyle())
    }
}

private struct DirectAuthErrorText: View {
    let message: String?
    init(_ message: String?) { self.message = message }
    var body: some View {
        if let message {
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .padding(.top, 12)
        }
    }
}

private struct DirectAuthCheckoutCard: View {
    let checkout: PendingCheckout
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("ЗАКАЗ СОХРАНЁН").microLabel(color: DS.acid)
            Text(checkout.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            HStack {
                Text("\(checkout.periodDays) дней")
                Spacer()
                Text("\(checkout.price) ₽").fontWeight(.semibold)
            }
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.55))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.panel)
    }
}

// MARK: - Payment states

struct DirectPaymentProcessingView: View {
    let title: String
    let subtitle: String
    var body: some View {
        DirectPaymentStateView(mark: "...", title: title, subtitle: subtitle)
    }
}

struct DirectPaymentCancelledView: View {
    let retry: () -> Void
    let changeMethod: () -> Void
    var body: some View {
        DirectPaymentStateView(
            mark: "—",
            title: "Оплата отменена",
            subtitle: "Заказ никуда не исчез. Повторите оплату или выберите другой способ.",
            actionTitle: "Повторить",
            action: retry,
            secondaryTitle: "Сменить способ",
            secondaryAction: changeMethod
        )
    }
}

struct DirectPaymentErrorView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        DirectPaymentStateView(
            mark: "!",
            title: "Не удалось оплатить",
            subtitle: message,
            actionTitle: "Повторить",
            action: retry
        )
    }
}

struct DirectPaymentSuccessView: View {
    let title: String
    let price: Int
    let period: String
    let activationPending: Bool
    let openLocations: () -> Void
    let openHome: () -> Void

    var body: some View {
        DirectPaymentStateView(
            mark: "✓",
            title: title,
            subtitle: activationPending
                ? "Платёж получен. Активируем вашу Direct-подписку…"
                : "Подписка активна. Можно подключаться.",
            actionTitle: activationPending ? nil : "К локациям",
            action: openLocations,
            secondaryTitle: activationPending ? nil : "На главную",
            secondaryAction: openHome
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ПЛАН").microLabel(color: DS.muted)
                Text("\(period) · \(price) ₽").font(.system(size: 13, weight: .semibold))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().stroke(DS.line))
        }
    }
}

struct DirectExternalPayWebView: View {
    let url: URL
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ОПЛАТА").microLabel(color: DS.muted)
                Spacer()
                Button("Закрыть") { onClose() }
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .overlay(alignment: .bottom) { Hairline() }

            DirectWKWebView(url: url)
        }
        .background(DS.paper.ignoresSafeArea())
    }
}

private struct DirectWKWebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.load(URLRequest(url: url))
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

private struct DirectPaymentStateView<Extra: View>: View {
    let mark: String
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: () -> Void
    let secondaryTitle: String?
    let secondaryAction: () -> Void
    let extra: () -> Extra

    init(
        mark: String,
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        action: @escaping () -> Void = {},
        secondaryTitle: String? = nil,
        secondaryAction: @escaping () -> Void = {},
        @ViewBuilder extra: @escaping () -> Extra = { EmptyView() }
    ) {
        self.mark = mark
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
        self.extra = extra
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(kicker: "VPN DIRECT / ОПЛАТА", title: title, subtitle: subtitle)
                    .padding(.top, DS.pageTop)
                Text(mark)
                    .font(.system(size: 30, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .frame(width: 74, height: 74)
                    .background(DS.ink)
                    .padding(.top, 28)
                extra().padding(.top, 22)
                if let actionTitle {
                    CheckoutAction(title: actionTitle, action: action).padding(.top, 18)
                }
                if let secondaryTitle {
                    CheckoutAction(title: secondaryTitle, secondary: true, action: secondaryAction).padding(.top, 7)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
        }
        .background(DS.paper.ignoresSafeArea())
    }
}

private struct CheckoutSectionHeader: View {
    let title: String
    let meta: String
    var body: some View {
        HStack {
            Text(title).microLabel(color: DS.ink)
            Spacer()
            Text(meta).microLabel(color: DS.green)
        }
        .frame(height: 38)
        .overlay(alignment: .top) { Hairline(color: DS.ink) }
    }
}

private struct CheckoutAuthRow: View {
    let mark: String
    let title: String
    let subtitle: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(mark)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.acid)
                    .frame(width: 45, height: 42)
                    .background(DS.ink)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(DS.muted)
                }
                Spacer()
                Image(systemName: "arrow.right").font(.system(size: 11))
            }
            .frame(minHeight: 70)
        }
        .overlay(alignment: .bottom) { Hairline() }
    }
}

private struct CheckoutAction: View {
    let title: String
    var secondary = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.right")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(secondary ? DS.ink : DS.acid)
            .padding(.horizontal, 15)
            .frame(height: 50)
            .background(secondary ? Color.clear : DS.ink)
            .overlay(Rectangle().stroke(secondary ? DS.ink : Color.clear))
        }
    }
}

// MARK: - Apple Sign In

@MainActor
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    struct Result {
        let identityToken: String
        let userId: String
        let email: String?
    }

    private var continuation: CheckedContinuation<Result, Error>?

    func signIn() async throws -> Result {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8)
        else {
            continuation?.resume(throwing: NSError(
                domain: "DirectAuth",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Apple не вернул токен"]
            ))
            continuation = nil
            return
        }
        continuation?.resume(returning: Result(
            identityToken: token,
            userId: credential.user,
            email: credential.email
        ))
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

#endif
