import SwiftUI

#if os(iOS)

struct DirectBalanceAccountView: View {
    @ObservedObject var model: VPNConnectionModel
    @ObservedObject private var flow = DirectBalanceFlow.shared
    @State private var showTopUp = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(
                    kicker: "АККАУНТ / БАЛАНС",
                    title: "Баланс",
                    subtitle: "Средства для быстрых покупок VPN Direct"
                )

                balanceHero
                    .padding(.top, 23)

                Button {
                    HapticManager.shared.play(.selection)
                    flow.prepareAccountSheetTopUp()
                    showTopUp = true
                    Task { await flow.loadProducts() }
                } label: {
                    HStack {
                        Text("Пополнить баланс")
                        Spacer()
                        Image(systemName: "plus")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.acid)
                    .padding(.horizontal, 15)
                    .frame(height: 50)
                    .background(DS.ink)
                }
                .buttonStyle(HapticButtonStyle())
                .padding(.top, 12)

                if let error = flow.errorMessage, !showTopUp {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(DS.danger)
                        .padding(.top, 10)
                }

                HStack {
                    Text("ИСТОРИЯ БАЛАНСА").microLabel(color: DS.ink)
                    Spacer()
                    Text(String(format: "%02d", flow.transactions.count)).microLabel(color: DS.green)
                }
                .frame(height: 38)
                .overlay(alignment: .top) { Hairline(color: DS.ink) }
                .padding(.top, 23)

                if flow.isLoadingBalance && flow.transactions.isEmpty {
                    Text("Загружаем историю…")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.muted)
                        .padding(.vertical, 18)
                } else if flow.transactions.isEmpty {
                    Text("Операций пока нет. Пополнение и покупки через баланс появятся здесь.")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.muted)
                        .lineSpacing(3)
                        .padding(.vertical, 18)
                } else {
                    ForEach(flow.transactions) { transaction in
                        transactionRow(transaction)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(DS.paper)
        .task { await flow.refresh() }
        .sheet(isPresented: $showTopUp, onDismiss: {
            flow.resetTopUpUIState()
            Task { await flow.refresh() }
        }) {
            DirectBalanceTopUpView(
                model: model,
                embeddedInSheet: true,
                onFinished: {
                    showTopUp = false
                    Task { await flow.refresh() }
                },
                onCancelled: {
                    showTopUp = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var balanceHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ДОСТУПНО").microLabel(color: .white.opacity(0.42))
            Text(flow.balanceDisplay)
                .font(.system(size: 31, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
            Text("Можно использовать без повторной оплаты при покупке подписки.")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.48))
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.ink)
        .overlay(Rectangle().stroke(DS.acid.opacity(0.7)))
    }

    private func transactionRow(_ item: DirectBalanceTransaction) -> some View {
        let debit = item.isDebit || item.amountUSDCents < 0
        return HStack(spacing: 12) {
            Text(debit ? "−" : "+")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(debit ? DS.danger : DS.green)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(kindLabel(item.kind)).microLabel(color: DS.muted)
                    Text(item.date.formatted(date: .numeric, time: .shortened))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(DS.muted)
                }
            }

            Spacer()

            Text(DirectMoney.displaySigned(usdCents: item.amountUSDCents))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 62)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func kindLabel(_ kind: DirectBalanceTransaction.Kind) -> String {
        switch kind {
        case .topUp: return "ПОПОЛНЕНИЕ"
        case .purchase: return "ПОДПИСКА"
        case .refund: return "ВОЗВРАТ"
        case .adjustment: return "КОРРЕКТИРОВКА"
        }
    }
}

#endif
