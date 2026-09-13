import SwiftUI

#if os(iOS)

struct DirectApplePurchaseStateView: View {
    @ObservedObject var flow: DirectBalanceFlow
    let retry: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(stateKicker).microLabel(color: DS.green)
                    Text(stateTitle)
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(DS.ink)
                }
                Spacer()
                stateMark
            }

            Text(stateSubtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DS.muted)
                .lineSpacing(3)
                .padding(.top, 10)

            if flow.lastTopUpCents > 0 {
                HStack {
                    Text("СУММА").microLabel()
                    Spacer()
                    Text(DirectMoney.formatUSD(cents: flow.lastTopUpCents))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                }
                .padding(.horizontal, 12)
                .frame(height: 48)
                .overlay(Rectangle().stroke(DS.line))
                .padding(.top, 16)
            }

            if flow.creditState == .creditPending {
                Text("Apple уже подтвердил покупку. Повторное зачисление безопасно: сервер использует идентификатор транзакции и не начислит средства дважды.")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.muted)
                    .lineSpacing(3)
                    .padding(.top, 12)
            }

            VStack(spacing: 7) {
                if flow.creditState == .creditPending {
                    Button(action: retry) {
                        HStack {
                            Text(flow.isPurchasing ? "СИНХРОНИЗИРУЕМ…" : "СИНХРОНИЗИРОВАТЬ СРЕДСТВА")
                            Spacer()
                            Image(systemName: "arrow.clockwise")
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.acid)
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(DS.ink)
                    }
                    .buttonStyle(HapticButtonStyle())
                    .disabled(flow.isPurchasing)
                }

                if flow.creditState != .purchasing {
                    Button(action: cancel) {
                        HStack {
                            Text(flow.creditState == .creditPending ? "ПОЗЖЕ" : "ОТМЕНА")
                            Spacer()
                            Image(systemName: "arrow.left")
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .overlay(Rectangle().stroke(DS.ink))
                    }
                    .buttonStyle(HapticButtonStyle())
                }
            }
            .padding(.top, 16)
        }
        .padding(18)
        .background(DS.paper)
        .overlay(Rectangle().stroke(flow.creditState == .creditPending ? DS.acid : DS.line))
        .padding(.horizontal, 14)
    }

    private var stateKicker: String {
        switch flow.creditState {
        case .purchasing: return "APPLE / IN-APP"
        case .creditPending: return "APPLE / ПОДТВЕРЖДЕНО"
        case .credited: return "APPLE / ЗАЧИСЛЕНО"
        case .failed: return "APPLE / ОШИБКА"
        case .idle: return "APPLE / ПОКУПКА"
        }
    }

    private var stateTitle: String {
        switch flow.creditState {
        case .purchasing: return "Подтверждаем покупку"
        case .creditPending: return "Средства в обработке"
        case .credited: return "Средства зачислены"
        case .failed: return "Покупка не завершена"
        case .idle: return "Пополнение"
        }
    }

    private var stateSubtitle: String {
        switch flow.creditState {
        case .purchasing:
            return "Откройте системное окно Apple и подтвердите покупку. Не закрывайте приложение во время обработки."
        case .creditPending:
            return "Оплата уже подтверждена Apple. Баланс обновится после подтверждения серверного ledger."
        case .credited:
            return "Баланс обновлён. Можно продолжить исходную покупку."
        case .failed:
            return "Apple не завершила покупку. С баланса ничего не списано."
        case .idle:
            return "Выберите пакет пополнения."
        }
    }

    private var stateMark: some View {
        Group {
            switch flow.creditState {
            case .purchasing:
                ProgressView().tint(DS.ink)
            case .creditPending:
                Image(systemName: "clock")
                    .foregroundStyle(DS.acid)
            case .credited:
                Image(systemName: "checkmark")
                    .foregroundStyle(DS.acid)
            case .failed:
                Image(systemName: "exclamationmark")
                    .foregroundStyle(DS.danger)
            case .idle:
                Image(systemName: "plus")
                    .foregroundStyle(DS.acid)
            }
        }
        .font(.system(size: 16, weight: .bold))
        .frame(width: 48, height: 48)
        .background(DS.ink)
    }
}

#endif
