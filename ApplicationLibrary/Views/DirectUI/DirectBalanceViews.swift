import SwiftUI

#if os(iOS)
import RevenueCat

private struct BalanceSectionHeader: View {
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

struct DirectBalanceTopUpView: View {
    @ObservedObject var model: VPNConnectionModel
    @ObservedObject private var flow = DirectBalanceFlow.shared
    /// When true, success/cancel call callbacks instead of pushing DetailPage.
    var embeddedInSheet: Bool = false
    var onFinished: (() -> Void)? = nil
    var onCancelled: (() -> Void)? = nil

    private var shortageRubles: Int {
        if flow.topUpSource == .account {
            return max(0, flow.topUpRequiredRubles)
        }
        return flow.shortageRubles(checkoutPriceRubles: model.checkoutPrice)
    }

    private var isStandalone: Bool {
        flow.topUpSource == .account || embeddedInSheet
    }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        cancel()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                            Text(isStandalone ? "Баланс" : "Способ оплаты")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.muted)
                    }
                    .buttonStyle(HapticButtonStyle())

                    PageHeading(
                        kicker: "DIRECT / БАЛАНС",
                        title: "Пополнить баланс",
                        subtitle: isStandalone
                            ? "Пополнение через Apple — средства сразу на балансе"
                            : "Одно пополнение — несколько будущих покупок"
                    )
                    .padding(.top, 17)

                    balanceHero.padding(.top, 23)

                    if !isStandalone || shortageRubles > 0 {
                        shortageBlock.padding(.top, 14)
                    }

                    BalanceSectionHeader(title: "ПОПОЛНЕНИЕ · APPLE", meta: "IN-APP")
                        .padding(.top, 23)

                    if flow.products.isEmpty && !flow.isPurchasing {
                        Text("Загружаем доступные покупки…")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 18)
                    } else {
                        ForEach(sortedProducts, id: \.productIdentifier) { product in
                            topUpRow(product)
                        }
                    }

                    if let error = flow.errorMessage {
                        Text(error)
                            .font(.system(size: 10))
                            .foregroundStyle(DS.danger)
                            .lineSpacing(3)
                            .padding(.top, 14)
                    }

                    Text(isStandalone
                         ? "Покупка проходит через Apple. После подтверждения сумма зачисляется на баланс."
                         : "Покупка проходит через Apple. После подтверждения сумма зачисляется на баланс, и вы возвращаетесь к выбранному тарифу.")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.muted)
                        .lineSpacing(3)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(DS.paper)

            if flow.showTopUpSuccess {
                Color.black.opacity(0.38).ignoresSafeArea()
                successOverlay
                    .padding(14)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .task {
            await flow.refresh()
            await flow.loadProducts()
        }
    }

    private var sortedProducts: [StoreProduct] {
        guard shortageRubles > 0 else {
            return flow.products.sorted { $0.price < $1.price }
        }
        let neededUSD = Decimal(shortageRubles) * DirectMoney.usdPerRub
        let covering = flow.products.filter { $0.price >= neededUSD }.sorted { $0.price < $1.price }
        let rest = flow.products.filter { $0.price < neededUSD }.sorted { $0.price < $1.price }
        if covering.isEmpty { return flow.products.sorted { $0.price < $1.price } }
        return covering + rest
    }

    private var balanceHero: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ТЕКУЩИЙ БАЛАНС").microLabel(color: .white.opacity(0.42))
                Text(flow.balanceDisplay)
                    .font(.system(size: 26, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
            }
            Spacer()
            Text("USD")
                .microLabel(color: DS.acid)
                .frame(width: 52, height: 52)
                .overlay(Rectangle().stroke(DS.acid.opacity(0.5)))
        }
        .padding(16)
        .background(DS.ink)
        .overlay(Rectangle().stroke(DS.acid.opacity(0.7)))
    }

    private var shortageBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle().fill(DS.acid).frame(width: 3)
            VStack(alignment: .leading, spacing: 5) {
                Text("НЕ ХВАТАЕТ").microLabel(color: DS.muted)
                Text(DirectMoney.display(rubles: shortageRubles))
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                Text(isStandalone
                     ? "Выберите пакет, чтобы пополнить баланс."
                     : "После пополнения вы вернётесь прямо к выбранному тарифу.")
                    .font(.system(size: 10)).foregroundStyle(DS.muted)
            }
        }
        .padding(12)
        .overlay(Rectangle().stroke(DS.line))
    }

    private func topUpRow(_ product: StoreProduct) -> some View {
        let neededUSD = Decimal(max(shortageRubles, 0)) * DirectMoney.usdPerRub
        let coveringPrices = shortageRubles > 0
            ? flow.products.filter { $0.price >= neededUSD }.map(\.price)
            : []
        let recommendedPrice = coveringPrices.min()
        let recommended = shortageRubles > 0
            && recommendedPrice == product.price
            && product.price >= neededUSD
        let credit = DirectMoney.creditCents(forProductID: product.productIdentifier)

        return Button {
            HapticManager.shared.play(.purchaseStarted)
            flow.purchase(product: product)
        } label: {
            HStack(spacing: 12) {
                Text("+")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .frame(width: 45, height: 45)
                    .background(DS.ink)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text("Пополнить").font(.system(size: 13, weight: .semibold))
                        if recommended { Text("РЕКОМЕНДУЕМ").microLabel(color: DS.green) }
                    }
                    Text(product.localizedPriceString)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DS.ink)
                    if let credit {
                        Text("На баланс \(DirectMoney.formatUSD(cents: credit))")
                            .font(.system(size: 9)).foregroundStyle(DS.muted)
                    } else {
                        Text("Apple In-App Purchase · direct.credits.*")
                            .font(.system(size: 9)).foregroundStyle(DS.muted)
                    }
                }
                Spacer()
                Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 70)
            .background(recommended ? DS.acid.opacity(0.10) : .clear)
            .overlay(Rectangle().stroke(recommended ? DS.green : DS.line))
        }
        .buttonStyle(HapticButtonStyle())
        .disabled(flow.isPurchasing)
        .padding(.top, 7)
    }

    private var successOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("OK")
                .font(.system(size: 19, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.acid)
                .frame(width: 58, height: 58)
                .background(DS.ink)
            Text("БАЛАНС ПОПОЛНЕН").microLabel(color: DS.green).padding(.top, 17)
            Text("Средства зачислены")
                .font(.system(size: 25, weight: .semibold))
                .padding(.top, 6)
            if flow.lastTopUpCents > 0 {
                Text(DirectMoney.displaySigned(usdCents: flow.lastTopUpCents))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .padding(.top, 4)
            }
            Text("Баланс обновлён. Возвращаем вас к месту, где началась покупка.")
                .font(.system(size: 11)).foregroundStyle(DS.muted).lineSpacing(3).padding(.top, 7)

            VStack(alignment: .leading, spacing: 5) {
                Text("НОВЫЙ БАЛАНС").microLabel()
                Text(flow.balanceDisplay)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .padding(.horizontal, 8)
            .overlay(Rectangle().stroke(DS.line))
            .padding(.top, 16)

            Button {
                finish()
            } label: {
                HStack {
                    Text("Продолжить")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.acid)
                .padding(.horizontal, 15)
                .frame(height: 50)
                .background(DS.ink)
            }
            .buttonStyle(HapticButtonStyle())
            .padding(.top, 14)
        }
        .padding(18)
        .background(DS.paper)
        .task {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard flow.showTopUpSuccess else { return }
            finish()
        }
    }

    private func finish() {
        if let onFinished {
            flow.resetTopUpUIState()
            onFinished()
            return
        }
        flow.finishTopUp(model: model)
    }

    private func cancel() {
        if let onCancelled {
            flow.resetTopUpUIState()
            onCancelled()
            return
        }
        flow.cancelTopUp(model: model)
    }
}

#endif
