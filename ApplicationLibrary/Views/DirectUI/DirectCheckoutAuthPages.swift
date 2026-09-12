import AuthenticationServices
import CryptoKit
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
    var productKind: String?
    var tariffID: Int?
    var addonDays: Int?
    var addonDevices: Int?
    var addonTrafficGB: Int?

    var paymentMethod: PaymentMethod {
        PaymentMethod(rawValue: paymentMethodRaw) ?? .apple
    }

    private static let key = "vpndirect.pending.checkout.v1"
    private static let openPaymentsKey = "vpndirect.open.payment.ids"

    static var current: Self? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    static func save(_ value: Self) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }

    static var openPaymentIDs: [String] {
        UserDefaults.standard.stringArray(forKey: openPaymentsKey) ?? []
    }

    static func rememberPaymentID(_ id: String) {
        var ids = openPaymentIDs
        if !ids.contains(id) { ids.append(id) }
        UserDefaults.standard.set(ids, forKey: openPaymentsKey)
    }

    static func forgetPaymentID(_ id: String) {
        UserDefaults.standard.set(openPaymentIDs.filter { $0 != id }, forKey: openPaymentsKey)
    }
}

// MARK: - Auth pages (each is its own DetailPage — no in-page route swapping)

struct DirectAuthLoginView: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        AuthPageShell(
            kicker: "ACCOUNT / SIGN IN",
            title: "Вход",
            subtitle: PendingCheckout.current == nil
                ? "Email, Apple, Google, телефон и код из бота — независимые аккаунты."
                : "Войдите, чтобы продолжить. Выбранный заказ сохранён."
        ) {
            VStack(spacing: 10) {
                if let checkout = PendingCheckout.current {
                    AuthCheckoutCard(checkout: checkout)
                }
                AuthErrorText(model.checkoutAuthError)
                AuthPrimaryButton(title: "ВОЙТИ ПО EMAIL", icon: "envelope") {
                    model.requestAuthDestination(.authEmail)
                }
                AuthSecondaryButton(title: "Продолжить с Apple", assetIcon: "auth-apple-black") {
                    Task { await model.signInWithAppleForAuth() }
                }
                AuthSecondaryButton(title: "Продолжить с Google", assetIcon: "auth-google") {
                    Task { await model.signInWithGoogleForAuth() }
                }
                AuthSecondaryButton(title: "По номеру телефона", icon: "phone") {
                    model.openDetail(.authPhone)
                }
                AuthSecondaryButton(title: "Код из бота", assetIcon: "auth-telegram") {
                    model.openDetail(.authBot)
                }
                AuthDivider()
                AuthSecondaryButton(title: "Создать аккаунт", icon: "plus") {
                    model.openDetail(.authRegister)
                }
                Button("Не получается войти") {
                    model.openDetail(.authRecovery)
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DS.muted)
                .frame(maxWidth: .infinity, minHeight: 36)
            }
        }
        .disabled(model.checkoutAuthBusy)
        .overlay { if model.checkoutAuthBusy { ProgressView().scaleEffect(1.1) } }
        .alert("Другой аккаунт", isPresented: $model.authAccountSwitchWarning) {
            Button("Продолжить", role: .destructive) { model.confirmAccountSwitchAndContinue() }
            Button("Отмена", role: .cancel) { model.cancelAccountSwitch() }
        } message: {
            Text("Вы уже вошли. Новый способ входа откроет другой независимый аккаунт — текущая подписка останется на прежнем.")
        }
    }
}

struct DirectAuthEmailView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var email = ""
    @State private var password = ""
    @State private var revealed = false

    var body: some View {
        AuthPageShell(
            kicker: "ACCOUNT / EMAIL",
            title: "Вход по email",
            subtitle: "Введите данные аккаунта VPN Direct."
        ) {
            VStack(alignment: .leading, spacing: 13) {
                AuthErrorText(model.checkoutAuthError)
                AuthField(title: "EMAIL", placeholder: "you@example.com", text: $email, keyboard: .emailAddress)
                AuthPasswordField(title: "ПАРОЛЬ", placeholder: "Введите пароль", text: $password, revealed: $revealed)
                Button("Забыли пароль?") {
                    model.openDetail(.authRecovery)
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DS.ink)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .buttonStyle(.plain)
                AuthPrimaryButton(title: "ВОЙТИ", icon: "arrow.right") {
                    Task { await model.loginWithPasswordForAuth(email: email, password: password) }
                }
                AuthDivider()
                Button("Войти по одноразовому коду") {
                    Task { await model.sendEmailCodeForAuth(email: email) }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.ink)
                .frame(maxWidth: .infinity)
                Button("Создать аккаунт") {
                    model.openDetail(.authRegister)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.ink)
                .frame(maxWidth: .infinity)
            }
        }
        .disabled(model.checkoutAuthBusy)
        .overlay { if model.checkoutAuthBusy { ProgressView().scaleEffect(1.1) } }
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
        AuthPageShell(kicker: "ACCOUNT / OTP", title: "Введите код", subtitle: subtitle) {
            VStack(alignment: .leading, spacing: 14) {
                AuthErrorText(model.checkoutAuthError)
                TextField("000000", text: $model.checkoutAuthCode)
                    .keyboardType(.numberPad)
                    .font(.system(size: 25, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(height: 64)
                    .background(Color.white.opacity(0.45))
                    .overlay(Rectangle().stroke(DS.line))
                AuthPrimaryButton(title: "ПОДТВЕРДИТЬ", icon: "checkmark") {
                    Task { await model.verifyEmailCodeForAuth() }
                }
                Button("Отправить код снова") {
                    Task { await model.resendEmailCodeForAuth() }
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DS.muted)
                .frame(maxWidth: .infinity, minHeight: 42)
            }
        }
        .disabled(model.checkoutAuthBusy)
        .overlay { if model.checkoutAuthBusy { ProgressView().scaleEffect(1.1) } }
    }
}

struct DirectAuthRegisterView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var revealed = false
    @State private var confirmationRevealed = false

    var body: some View {
        AuthPageShell(
            kicker: "ACCOUNT / NEW",
            title: "Регистрация",
            subtitle: "Создайте аккаунт VPN Direct."
        ) {
            VStack(alignment: .leading, spacing: 11) {
                AuthErrorText(model.checkoutAuthError)
                AuthField(title: "ИМЯ", placeholder: "Как к вам обращаться", text: $name)
                AuthField(title: "EMAIL", placeholder: "you@example.com", text: $email, keyboard: .emailAddress)
                AuthPasswordField(title: "ПАРОЛЬ", placeholder: "Минимум 8 символов", text: $password, revealed: $revealed)
                AuthPasswordField(
                    title: "ПОВТОРИТЕ ПАРОЛЬ",
                    placeholder: "Введите пароль ещё раз",
                    text: $confirmation,
                    revealed: $confirmationRevealed
                )
                Text("Создавая аккаунт, вы соглашаетесь с условиями использования и политикой конфиденциальности.")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.muted)
                    .fixedSize(horizontal: false, vertical: true)
                AuthPrimaryButton(title: "СОЗДАТЬ АККАУНТ", icon: "arrow.right") {
                    Task {
                        await model.registerWithPasswordForAuth(
                            name: name,
                            email: email,
                            password: password,
                            confirmation: confirmation
                        )
                    }
                }
                AuthDivider()
                AuthSecondaryButton(title: "Продолжить с Apple", assetIcon: "auth-apple-black") {
                    Task { await model.signInWithAppleForAuth() }
                }
                AuthSecondaryButton(title: "Продолжить с Google", assetIcon: "auth-google") {
                    Task { await model.signInWithGoogleForAuth() }
                }
                AuthSecondaryButton(title: "По номеру телефона", icon: "phone") {
                    model.openDetail(.authPhone)
                }
                Button("Уже есть аккаунт? Войти") {
                    model.openDetail(.authLogin)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.ink)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
        .disabled(model.checkoutAuthBusy)
        .overlay { if model.checkoutAuthBusy { ProgressView().scaleEffect(1.1) } }
    }
}

struct DirectAuthRecoveryView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var email = ""
    @State private var sent = false

    var body: some View {
        AuthPageShell(
            kicker: "ACCOUNT / PASSWORD",
            title: "Восстановление пароля",
            subtitle: "Отправим ссылку для сброса пароля на вашу почту."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                AuthErrorText(model.checkoutAuthError)
                if sent {
                    Text("Если аккаунт существует, письмо уже отправлено. Проверьте «Спам».")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.ink)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    AuthField(title: "EMAIL", placeholder: "you@example.com", text: $email, keyboard: .emailAddress)
                    AuthPrimaryButton(title: "ОТПРАВИТЬ ССЫЛКУ", icon: "arrow.right") {
                        Task {
                            let ok = await model.requestPasswordResetForAuth(email: email)
                            if ok { sent = true }
                        }
                    }
                }
                Text("Можно также войти через Apple, Google или по номеру.")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.muted)
                AuthSecondaryButton(title: "Войти с Apple", assetIcon: "auth-apple-black") {
                    Task { await model.signInWithAppleForAuth() }
                }
                AuthSecondaryButton(title: "Войти с Google", assetIcon: "auth-google") {
                    Task { await model.signInWithGoogleForAuth() }
                }
                AuthSecondaryButton(title: "По номеру телефона", icon: "phone") {
                    model.openDetail(.authPhone)
                }
            }
        }
        .disabled(model.checkoutAuthBusy)
        .overlay { if model.checkoutAuthBusy { ProgressView().scaleEffect(1.1) } }
        .onAppear {
            if email.isEmpty, !model.checkoutAuthEmail.isEmpty {
                email = model.checkoutAuthEmail
            }
        }
    }
}

struct DirectAuthBotView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var mode: Mode = .code

    private enum Mode: String, CaseIterable {
        case code = "Код"
        case confirm = "Подтверждение"
    }

    var body: some View {
        AuthPageShell(
            kicker: "ACCOUNT / BOT",
            title: "Аккаунт бота",
            subtitle: mode == .code
                ? "В @vpndirectbot нажмите «Синхронизировать с приложением» и введите 6 цифр."
                : "Укажите @username или Telegram ID — в боте придёт запрос «Согласиться / Запретить»."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                AuthErrorText(model.checkoutAuthError)
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if mode == .code {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("КОД ИЗ БОТА").microLabel(color: DS.ink)
                        Text("Кнопка в боте создаёт одноразовый 6-значный код. Старый формат XXXX-XXXX тоже ещё принимается.")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(DS.panel.opacity(0.08))
                    .overlay(Rectangle().stroke(DS.line))
                    AuthField(
                        title: "КОД",
                        placeholder: "123456",
                        text: $model.checkoutAuthBotCode,
                        keyboard: .numberPad
                    )
                    AuthPrimaryButton(title: "ВОЙТИ", icon: "arrow.right") {
                        Task { await model.linkBotCodeForAuth() }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ПОДТВЕРЖДЕНИЕ В TELEGRAM").microLabel(color: DS.ink)
                        Text("Мы отправим запрос в чат с ботом. Пока ждёте — ничего не означает: подтверждение, отказ и неизвестный аккаунт выглядят одинаково.")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(DS.panel.opacity(0.08))
                    .overlay(Rectangle().stroke(DS.line))
                    AuthField(
                        title: "@USERNAME ИЛИ TG ID",
                        placeholder: "@username или 123456789",
                        text: $model.checkoutAuthBotIdentifier
                    )
                    AuthPrimaryButton(title: "ЗАПРОСИТЬ ВХОД", icon: "paperplane") {
                        Task {
                            await model.requestBotLoginConfirmForAuth(
                                identifier: model.checkoutAuthBotIdentifier
                            )
                        }
                    }
                    if model.checkoutAuthBusy {
                        Text("Ожидаем подтверждение в Telegram…")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.muted)
                    }
                }
            }
        }
        .disabled(model.checkoutAuthBusy)
        .overlay { if model.checkoutAuthBusy { ProgressView().scaleEffect(1.1) } }
    }
}

struct DirectAuthPhoneView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var phone = ""

    var body: some View {
        AuthPageShell(
            kicker: "ACCOUNT / PHONE",
            title: "Вход по номеру",
            subtitle: "Код придёт в Telegram. Новый номер — новый app-аккаунт с триалом; уже зарегистрированный — просто вход."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                AuthErrorText(model.checkoutAuthError)
                AuthField(
                    title: "ТЕЛЕФОН",
                    placeholder: "+79001234567 или 89001234567",
                    text: $phone,
                    keyboard: .phonePad
                )
                AuthPrimaryButton(title: "ОТПРАВИТЬ КОД", icon: "paperplane") {
                    Task { await model.sendPhoneCodeForAuth(phone: phone) }
                }
                Text("Нужен Telegram на этом номере для получения кода. Это не аккаунт бота — для бота используйте «Код из бота».")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .disabled(model.checkoutAuthBusy)
        .overlay { if model.checkoutAuthBusy { ProgressView().scaleEffect(1.1) } }
        .onAppear {
            if phone.isEmpty, !model.checkoutAuthPhone.isEmpty {
                phone = model.checkoutAuthPhone
            }
        }
    }
}

struct DirectAuthPhoneCodeView: View {
    @ObservedObject var model: VPNConnectionModel

    private var subtitle: String {
        model.checkoutAuthPhone.isEmpty
            ? "Введите код из Telegram."
            : "Код отправлен в Telegram на \(model.checkoutAuthPhone)."
    }

    var body: some View {
        AuthPageShell(kicker: "ACCOUNT / PHONE OTP", title: "Код из Telegram", subtitle: subtitle) {
            VStack(alignment: .leading, spacing: 14) {
                AuthErrorText(model.checkoutAuthError)
                TextField("000000", text: $model.checkoutAuthCode)
                    .keyboardType(.numberPad)
                    .font(.system(size: 25, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(height: 64)
                    .background(Color.white.opacity(0.45))
                    .overlay(Rectangle().stroke(DS.line))
                AuthPrimaryButton(title: "ПОДТВЕРДИТЬ", icon: "checkmark") {
                    Task { await model.verifyPhoneCodeForAuth() }
                }
                Button("Отправить код снова") {
                    Task { await model.sendPhoneCodeForAuth(phone: model.checkoutAuthPhone) }
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DS.muted)
                .frame(maxWidth: .infinity, minHeight: 42)
            }
        }
        .disabled(model.checkoutAuthBusy)
        .overlay { if model.checkoutAuthBusy { ProgressView().scaleEffect(1.1) } }
    }
}

struct DirectAuthSuccessView: View {
    @ObservedObject var model: VPNConnectionModel

    private var continueTitle: String {
        if model.authFlowReturnsToAccount {
            return "ВЕРНУТЬСЯ В АККАУНТ"
        }
        return PendingCheckout.current == nil ? "ГОТОВО" : "ПРОДОЛЖИТЬ ОПЛАТУ"
    }

    var body: some View {
        AuthPageShell(
            kicker: "VPN DIRECT / ГОТОВО",
            title: "Аккаунт готов",
            subtitle: model.authFlowReturnsToAccount
                ? "Сессия сохранена. Можно вернуться в аккаунт."
                : "Возвращаем вас к оформлению заказа."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if let checkout = PendingCheckout.current, !model.authFlowReturnsToAccount {
                    AuthCheckoutCard(checkout: checkout)
                }
                AuthPrimaryButton(title: continueTitle, icon: "arrow.right") {
                    model.completeAuthAfterSuccess()
                }
            }
        }
    }
}

// MARK: - Payment states

struct DirectPaymentProcessingView: View {
    let title: String
    let subtitle: String

    init(title: String = "Оплата", subtitle: String = "Подтверждаем операцию…") {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        DirectPaymentStateView(mark: "…", title: title, subtitle: subtitle) {
            VStack(alignment: .leading, spacing: 13) {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(DS.ink)
                    .frame(height: 4)
                Text("Не закрывайте экран, если банк уже открыл подтверждение. После ответа статус обновится автоматически.")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.muted)
                    .lineSpacing(3)
            }
        }
    }
}

struct DirectPaymentWaitingView: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        DirectPaymentStateView(
            mark: "WAIT",
            title: "Ожидаем подтверждение банка",
            subtitle: model.paymentWaitingSubtitle.isEmpty
                ? "Статус обновится, когда банк подтвердит оплату. Можно свернуть приложение."
                : model.paymentWaitingSubtitle
        ) {
            VStack(spacing: 9) {
                if model.paymentWaitingTimedOut {
                    Text("Ожидаем подтверждения со стороны банка. Зайдите позже или свяжитесь с вашим банком.")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.muted)
                        .lineSpacing(3)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(DS.ink)
                        .frame(height: 4)
                }
                CheckoutAction(title: "Обновить статус") {
                    model.startPaymentStatusPolling()
                }
                CheckoutAction(title: "Отменить ожидание", secondary: true) {
                    model.abandonPaymentFlow(returnToPaymentMethod: true)
                }
            }
        }
        .onAppear { model.startPaymentStatusPolling() }
        .onDisappear { model.stopPaymentStatusPolling() }
    }
}

struct DirectPaymentCancelledView: View {
    let retry: () -> Void
    let changeMethod: () -> Void

    var body: some View {
        DirectPaymentStateView(
            mark: "×",
            title: "Оплата отменена",
            subtitle: "Операция была отменена. Деньги не должны быть списаны повторно."
        ) {
            VStack(spacing: 9) {
                CheckoutAction(title: "Попробовать снова", action: retry)
                CheckoutAction(title: "Сменить способ", secondary: true, action: changeMethod)
                Text("Если банк показывает списание, не повторяйте платёж — сначала дождитесь возврата статуса.")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.muted)
                    .lineSpacing(3)
                    .padding(.top, 5)
            }
        }
    }
}

struct DirectPaymentErrorView: View {
    let message: String
    let retry: () -> Void
    var onSupport: (() -> Void)? = nil

    var body: some View {
        DirectPaymentStateView(
            mark: "!",
            title: "Не удалось завершить оплату",
            subtitle: message,
            tone: DS.danger
        ) {
            VStack(spacing: 9) {
                CheckoutAction(title: "Повторить", action: retry)
                if let onSupport {
                    CheckoutAction(title: "Открыть поддержку", secondary: true, action: onSupport)
                }
            }
        }
    }
}

struct DirectPaymentSuccessView: View {
    let title: String
    let price: Int
    let period: String
    let activationPending: Bool
    let openLocations: () -> Void
    let openHome: () -> Void
    var refreshActivation: (() -> Void)? = nil

    var body: some View {
        DirectPaymentStateView(
            mark: "OK",
            title: title,
            subtitle: activationPending
                ? "Платёж принят. Обновите статус, чтобы получить доступ."
                : "Подписка активирована. VPN Direct готов к подключению."
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    checkoutFact("СТАТУС", activationPending ? "ОЖИДАЕТ" : "АКТИВЕН")
                    checkoutFact("ПЛАН", period)
                    if price > 0 { checkoutFact("СУММА", "\(price)") }
                }
                if activationPending {
                    CheckoutAction(title: "Обновить статус") {
                        refreshActivation?()
                    }
                    .padding(.top, 14)
                }
                CheckoutAction(
                    title: activationPending ? "На главную" : "К локациям",
                    secondary: activationPending,
                    action: activationPending ? openHome : openLocations
                )
                .padding(.top, 9)
                if !activationPending {
                    CheckoutAction(title: "На главную", secondary: true, action: openHome)
                        .padding(.top, 9)
                }
            }
        }
    }

    private func checkoutFact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).microLabel(color: DS.muted)
            Text(value).font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 13)
        .overlay(alignment: .leading) { Hairline().frame(width: 1) }
    }
}

struct DirectExternalPayWebView: View {
    let url: URL
    let onClose: () -> Void
    /// Called when the hub navigates to a success page (payment confirmed in browser).
    var onSuccess: (() -> Void)? = nil

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

            DirectWKWebView(url: url, onSuccess: onSuccess)
        }
        .background(DS.paper.ignoresSafeArea())
    }
}

private struct DirectWKWebView: UIViewRepresentable {
    let url: URL
    var onSuccess: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onSuccess: onSuccess)
    }

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onSuccess = onSuccess
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onSuccess: (() -> Void)?
        private var didFireSuccess = false

        init(onSuccess: (() -> Void)?) {
            self.onSuccess = onSuccess
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let navURL = navigationAction.request.url {
                maybeSucceed(navURL)
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let navURL = webView.url {
                maybeSucceed(navURL)
            }
        }

        private func maybeSucceed(_ navURL: URL) {
            guard !didFireSuccess else { return }
            let host = (navURL.host ?? "").lowercased()
            let path = navURL.path.lowercased()
            let suffixes = DirectBackendRuntime.checkoutSuccessHostSuffixes
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            guard !suffixes.isEmpty else { return }
            let isAllowedHost = suffixes.contains { suffix in
                host == suffix || host.hasSuffix(".\(suffix)") || host.hasSuffix(suffix)
            }
            let isSuccess = path == "/success" || path.hasPrefix("/success/")
            guard isAllowedHost, isSuccess else { return }
            didFireSuccess = true
            DispatchQueue.main.async { self.onSuccess?() }
        }
    }
}

private struct DirectPaymentStateView<Extra: View>: View {
    let mark: String
    let title: String
    let subtitle: String
    let tone: Color
    let extra: Extra

    init(
        mark: String,
        title: String,
        subtitle: String,
        tone: Color = DS.ink,
        @ViewBuilder extra: () -> Extra
    ) {
        self.mark = mark
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.extra = extra()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(kicker: "DIRECT / CHECKOUT", title: title, subtitle: subtitle)
                    .padding(.top, DS.pageTop)
                    .padding(.bottom, 24)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Text(mark)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.acid)
                            .frame(width: 64, height: 64)
                            .background(tone == DS.danger ? DS.danger : DS.ink)
                        Spacer()
                    }
                    Text(title.uppercased())
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.top, 19)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineSpacing(3)
                        .padding(.top, 7)
                }
                .padding(18)
                .background(tone == DS.danger ? DS.danger : DS.ink)

                extra
                    .padding(.top, 18)
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
                Image(systemName: secondary ? "arrow.left" : "arrow.right")
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(secondary ? DS.ink : DS.acid)
            .padding(.horizontal, 15)
            .frame(height: 52)
            .background(secondary ? Color.clear : DS.ink)
            .overlay(Rectangle().stroke(DS.ink))
        }
        .buttonStyle(HapticButtonStyle())
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
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .unknown:
                continuation?.resume(throwing: NSError(
                    domain: "DirectAuth",
                    code: 1000,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Sign in with Apple не настроен для приложения. В Apple Developer включите capability «Sign In with Apple» для App ID com.vpndirect.vpndirectapp и переустановите профиль."]
                ))
            case .canceled:
                continuation?.resume(throwing: NSError(
                    domain: "DirectAuth",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "Вход через Apple отменён"]
                ))
            default:
                continuation?.resume(throwing: error)
            }
        } else {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }
}

// MARK: - Google Sign In (OAuth code + PKCE via ASWebAuthenticationSession)

@MainActor
final class GoogleSignInCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    struct Result {
        let idToken: String
        let userId: String?
        let email: String?
    }

    private var session: ASWebAuthenticationSession?

    func signIn() async throws -> Result {
        let clientId = DirectBackendRuntime.googleClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientId.isEmpty else {
            throw NSError(
                domain: "DirectAuth",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Google Sign In не настроен (client id)"]
            )
        }
        let configuredRedirect = DirectBackendRuntime.googleRedirectURI.trimmingCharacters(in: .whitespacesAndNewlines)
        let redirect: String
        if !configuredRedirect.isEmpty {
            redirect = configuredRedirect
        } else if let reversed = Self.reversedClientID(from: clientId) {
            // Google iOS clients expect reversed-client-id:/oauth2redirect or :/
            redirect = "\(reversed):/oauth2redirect/google"
        } else {
            redirect = "vpndirect:/oauth2redirect/google"
        }

        let verifier = Self.makeCodeVerifier()
        let challenge = Self.makeCodeChallenge(verifier: verifier)
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        guard let authURL = components.url else {
            throw NSError(domain: "DirectAuth", code: 3, userInfo: [NSLocalizedDescriptionKey: "Некорректный Google OAuth URL"])
        }
        let callbackScheme = URL(string: redirect)?.scheme ?? "vpndirect"

        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let error {
                    let ns = error as NSError
                    if ns.domain == ASWebAuthenticationSessionError.errorDomain,
                       ns.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        cont.resume(throwing: NSError(
                            domain: "DirectAuth",
                            code: 1001,
                            userInfo: [NSLocalizedDescriptionKey: "Вход через Google отменён"]
                        ))
                    } else {
                        cont.resume(throwing: error)
                    }
                    return
                }
                guard let callbackURL else {
                    cont.resume(throwing: NSError(
                        domain: "DirectAuth",
                        code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "Google не вернул код авторизации"]
                    ))
                    return
                }
                cont.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.session = session
            if !session.start() {
                cont.resume(throwing: NSError(
                    domain: "DirectAuth",
                    code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "Не удалось открыть Google Sign In"]
                ))
            }
        }

        let values = Self.queryValues(from: callbackURL)
        if let err = values["error"] {
            throw NSError(
                domain: "DirectAuth",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: values["error_description"] ?? err]
            )
        }
        guard let code = values["code"], !code.isEmpty else {
            throw NSError(
                domain: "DirectAuth",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Google не вернул authorization code"]
            )
        }

        let tokens = try await Self.exchangeCode(
            code: code,
            redirectURI: redirect,
            clientId: clientId,
            codeVerifier: verifier
        )
        let claims = Self.decodeJWTClaims(tokens.idToken)
        return Result(
            idToken: tokens.idToken,
            userId: tokens.sub ?? claims["sub"],
            email: tokens.email ?? claims["email"]
        )
    }

    private static func exchangeCode(
        code: String,
        redirectURI: String,
        clientId: String,
        codeVerifier: String
    ) async throws -> (idToken: String, email: String?, sub: String?) {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code_verifier", value: codeVerifier),
        ]
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard status == 200, let idToken = json["id_token"] as? String, !idToken.isEmpty else {
            let description = (json["error_description"] as? String)
                ?? (json["error"] as? String)
                ?? String(data: data, encoding: .utf8)
                ?? "token exchange failed"
            throw NSError(
                domain: "DirectAuth",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "Google token exchange: \(description)"]
            )
        }
        return (idToken, json["email"] as? String, json["sub"] as? String)
    }

    private static func queryValues(from url: URL) -> [String: String] {
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var values: [String: String] = [:]
        let raw = comps?.query ?? comps?.fragment ?? ""
        for pair in raw.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                values[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
            }
        }
        for item in comps?.queryItems ?? [] {
            values[item.name] = item.value ?? values[item.name]
        }
        return values
    }

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func makeCodeChallenge(verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func reversedClientID(from clientId: String) -> String? {
        let suffix = ".apps.googleusercontent.com"
        guard clientId.hasSuffix(suffix) else { return nil }
        let prefix = String(clientId.dropLast(suffix.count))
        guard !prefix.isEmpty else { return nil }
        return "com.googleusercontent.apps.\(prefix)"
    }

    private static func decodeJWTClaims(_ jwt: String) -> [String: String] {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return [:] }
        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64.append("=") }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        var out: [String: String] = [:]
        if let sub = json["sub"] as? String { out["sub"] = sub }
        if let email = json["email"] as? String { out["email"] = email }
        return out
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

#endif
