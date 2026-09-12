import SwiftUI

#if os(iOS)

// MARK: - Checkout action

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

// MARK: - Shared payment state

private struct DirectPaymentStateView<Extra: View>: View {
    let mark: String
    let title: String
    let subtitle: String
    let tone: Color
    let extra: Extra

    init(mark: String, title: String, subtitle: String, tone: Color = DS.ink, @ViewBuilder extra: () -> Extra) {
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
                    .padding(.bottom, 24)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Text(mark)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.acid)
                            .frame(width: 64, height: 64)
                            .background(tone)
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
                .background(tone)

                extra
                    .padding(.top, 18)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(DS.paper.ignoresSafeArea())
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
    let subtitle: String
    let onRefresh: () -> Void
    let onCancel: () -> Void

    init(subtitle: String = "Статус обновится, когда банк подтвердит оплату. Можно свернуть приложение.", onRefresh: @escaping () -> Void = {}, onCancel: @escaping () -> Void = {}) {
        self.subtitle = subtitle
        self.onRefresh = onRefresh
        self.onCancel = onCancel
    }

    var body: some View {
        DirectPaymentStateView(mark: "WAIT", title: "Ожидаем подтверждение банка", subtitle: subtitle) {
            VStack(spacing: 9) {
                CheckoutAction(title: "Обновить статус", action: onRefresh)
                CheckoutAction(title: "Отменить оплату", secondary: true, action: onCancel)
            }
        }
    }
}

struct DirectPaymentCancelledView: View {
    let message: String
    let onRetry: () -> Void

    init(message: String = "Операция была отменена. Деньги не должны быть списаны повторно.", onRetry: @escaping () -> Void = {}) {
        self.message = message
        self.onRetry = onRetry
    }

    var body: some View {
        DirectPaymentStateView(mark: "×", title: "Оплата отменена", subtitle: message, tone: DS.ink) {
            VStack(spacing: 9) {
                CheckoutAction(title: "Попробовать снова", action: onRetry)
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
    let onRetry: () -> Void
    let onSupport: () -> Void

    init(message: String, onRetry: @escaping () -> Void = {}, onSupport: @escaping () -> Void = {}) {
        self.message = message
        self.onRetry = onRetry
        self.onSupport = onSupport
    }

    var body: some View {
        DirectPaymentStateView(mark: "!", title: "Не удалось завершить оплату", subtitle: message, tone: DS.danger) {
            VStack(spacing: 9) {
                CheckoutAction(title: "Повторить", action: onRetry)
                CheckoutAction(title: "Открыть поддержку", secondary: true, action: onSupport)
            }
        }
    }
}

struct DirectPaymentSuccessView: View {
    let title: String
    let price: Int
    let activated: Bool
    let onRefresh: () -> Void
    let onContinue: () -> Void

    init(title: String = "Оплата прошла", price: Int = 0, activated: Bool = true, onRefresh: @escaping () -> Void = {}, onContinue: @escaping () -> Void = {}) {
        self.title = title
        self.price = price
        self.activated = activated
        self.onRefresh = onRefresh
        self.onContinue = onContinue
    }

    var body: some View {
        DirectPaymentStateView(mark: "OK", title: title, subtitle: activated ? "Подписка активирована. VPN Direct готов к подключению." : "Платёж принят. Обновите статус, чтобы получить доступ.", tone: DS.ink) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    checkoutFact("СТАТУС", activated ? "АКТИВЕН" : "ОЖИДАЕТ")
                    if price > 0 { checkoutFact("СУММА", "\(price)") }
                }
                if !activated {
                    CheckoutAction(title: "Обновить статус", action: onRefresh)
                        .padding(.top, 14)
                }
                CheckoutAction(title: "Продолжить", secondary: !activated, action: onContinue)
                    .padding(.top, 9)
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

#endif
