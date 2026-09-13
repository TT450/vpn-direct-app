import SwiftUI

#if os(iOS)

struct DirectApplePurchaseStateView: View {
    @ObservedObject var flow: DirectBalanceFlow
    let retry: () -> Void
    let cancel: () -> Void

    private var isBusy: Bool {
        flow.creditState == .purchasing || flow.creditState == .creditPending || flow.isPurchasing
    }

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

            if isBusy {
                TimelineView(.periodic(from: .now, by: 0.9)) { context in
                    activityStrip(at: context.date)
                }
                .padding(.top, 16)
            }

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

    private func activityStrip(at date: Date) -> some View {
        let phase = Int(date.timeIntervalSinceReferenceDate / 0.9)
        let pulse = (phase % 2) == 0
        return VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(DS.line)
                    Rectangle()
                        .fill(DS.acid)
                        .frame(width: max(28, geo.size.width * (pulse ? 0.78 : 0.32)))
                        .animation(.easeInOut(duration: 0.85), value: pulse)
                }
            }
            .frame(height: 3)

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index == phase % 3 ? DS.acid : DS.line)
                        .frame(width: 7, height: 7)
                }
                Text(busyHint(phase: phase))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.ink)
                    .id(phase)
                    .transition(.opacity)
                Spacer()
            }
        }
    }

    private func busyHint(phase: Int) -> String {
        let hints: [String]
        switch flow.creditState {
        case .purchasing:
            hints = ["ЖДЁМ APPLE…", "ПОДТВЕРДИТЕ ПОКУПКУ", "ОБРАБАТЫВАЕМ…"]
        case .creditPending:
            hints = ["СИНХРОНИЗИРУЕМ…", "ПРОВЕРЯЕМ ТРАНЗАКЦИЮ…", "ОБНОВЛЯЕМ БАЛАНС…"]
        default:
            hints = ["ОБРАБАТЫВАЕМ…"]
        }
        return hints[phase % hints.count]
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
            return "Оплата уже подтверждена Apple. Баланс обновится после подтверждения на сервере."
        case .credited:
            return "Баланс обновлён. Можно продолжить исходную покупку."
        case .failed:
            return "Apple не завершила покупку. С баланса ничего не списано."
        case .idle:
            return "Выберите пакет пополнения."
        }
    }

    private var stateMark: some View {
        TimelineView(.periodic(from: .now, by: 0.9)) { context in
            let pulse = Int(context.date.timeIntervalSinceReferenceDate / 0.9) % 2 == 0
            ZStack {
                Rectangle().fill(DS.ink)
                Group {
                    switch flow.creditState {
                    case .purchasing:
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(DS.acid)
                            .scaleEffect(0.9)
                    case .creditPending:
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(DS.acid)
                            .rotationEffect(.degrees(Double(Int(context.date.timeIntervalSinceReferenceDate * 40) % 360)))
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
            }
            .frame(width: 48, height: 48)
            .scaleEffect(isBusy && pulse ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.85), value: pulse)
        }
    }
}

#endif
