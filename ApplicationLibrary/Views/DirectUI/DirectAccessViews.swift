import SwiftUI

#if os(iOS)

private struct AccessBackButton: View {
    @ObservedObject var model: VPNConnectionModel
    let title: String
    var destination: DetailPage?

    var body: some View {
        Button {
            model.detailPage = destination
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left")
                Text(title)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(DS.muted)
        }
        .buttonStyle(HapticButtonStyle())
    }
}

private struct AccessSectionHeader: View {
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

private struct AccessButton: View {
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
        .buttonStyle(HapticButtonStyle())
    }
}

struct DirectAccessChoiceView: View {
    @ObservedObject var model: VPNConnectionModel

    private var connectionMethodCount: Int {
        model.importedSubscriptions.isEmpty ? 2 : 4
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                AccessBackButton(model: model, title: "Главная", destination: nil)
                PageHeading(
                    kicker: "ПОДКЛЮЧЕНИЕ / НАЧАЛО",
                    title: "Выберите доступ",
                    subtitle: "Бесплатно, Premium или внешняя подписка"
                )
                .padding(.top, 17)

                if let context = model.accessChoiceContext {
                    Text(context)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.acid.opacity(0.22))
                        .overlay(Rectangle().stroke(DS.line))
                        .padding(.top, 16)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("СЕЙЧАС НЕ ЗАЩИЩЕНО").microLabel(color: .white.opacity(0.42))
                    Text("У вас пока нет активного подключения")
                        .font(.system(size: 21, weight: .semibold))
                    Text("Выберите удобный способ. Позже его можно сменить в разделе «Подписки».")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                }
                .padding(17)
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                .foregroundStyle(.white)
                .background(DS.panel)
                .padding(.top, 24)

                AccessSectionHeader(title: "СПОСОБ ПОДКЛЮЧЕНИЯ", meta: String(format: "%02d", connectionMethodCount))
                    .padding(.top, 22)
                AccessChoiceRow(mark: "FREE", title: "Получить бесплатно", subtitle: "3 рекламы → 1 час и 200 МБ") {
                    model.clearAccessChoiceContext()
                    model.handleAccessChoiceFree()
                }
                AccessChoiceRow(mark: "PLUS", title: "VPN Direct Premium", subtitle: "Без рекламы · от 1 месяца") {
                    model.clearAccessChoiceContext()
                    model.handleAccessChoicePremium()
                }

                if !model.importedSubscriptions.isEmpty {
                    AccessSectionHeader(title: "ВЫБРАТЬ ПОДПИСКУ", meta: "02")
                        .padding(.top, 22)
                    AccessChoiceRow(mark: "SUB", title: "Выбрать из добавленных", subtitle: "Внешние подписки в приложении") {
                        model.clearAccessChoiceContext()
                        model.handleAccessChoicePickSubscription()
                    }
                    AccessChoiceRow(mark: "URL", title: "Добавить URL", subtitle: "Подписка любого провайдера") {
                        model.clearAccessChoiceContext()
                        model.handleAccessChoiceAddURL()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }
}

private struct AccessChoiceRow: View {
    let mark: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(mark).microLabel(color: DS.acid)
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
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .overlay(alignment: .bottom) { Hairline() }
    }
}

struct DirectFreeAccessView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var isWatching = false
    @State private var showReward = false

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    AccessBackButton(model: model, title: "Подписки")
                    PageHeading(
                        kicker: "DIRECT / FREE",
                        title: "Бесплатный доступ",
                        subtitle: "Смотрите рекламу и пополняйте VPN-баланс"
                    )
                    .padding(.top, 17)

                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ВАШ БАЛАНС").microLabel(color: .white.opacity(0.42))
                                Text(model.freeRemainingDisplayText)
                                    .font(.system(size: 27, weight: .semibold, design: .monospaced))
                                Text("Время действует по часам, даже без подключения")
                                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.48))
                            }
                            Spacer()
                            Text("FREE").microLabel(color: DS.acid)
                                .frame(width: 58, height: 58)
                                .overlay(Rectangle().stroke(Color.white.opacity(0.23)))
                        }
                        .padding(16)

                        HStack(spacing: 0) {
                            DarkStat(label: "ТРАФИК", value: model.freeTrafficText)
                            DarkStat(label: "УСТРОЙСТВА", value: "1 / 1")
                        }
                    }
                    .foregroundStyle(.white)
                    .background(DS.panel)
                    .padding(.top, 23)

                    AccessSectionHeader(title: "СЛЕДУЮЩИЙ ЧАС", meta: "\(model.watchedAds) ИЗ 3")
                        .padding(.top, 23)
                    Text("После третьей рекламы мы сразу добавим 1 час и 200 МБ.")
                        .font(.system(size: 10)).foregroundStyle(DS.muted)
                        .padding(.bottom, 12)

                    HStack(spacing: 7) {
                        ForEach(0 ..< 3, id: \.self) { index in
                            AdProgressCell(
                                number: index + 1,
                                isComplete: index < model.watchedAds,
                                isCurrent: index == model.watchedAds
                            )
                        }
                    }

                    HStack {
                        Text("НАГРАДА ЗА КОМПЛЕКТ").microLabel()
                        Spacer()
                        Text("+1 Ч · +200 МБ").microLabel(color: DS.green)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .overlay(Rectangle().stroke(DS.line))
                    .padding(.top, 10)

                    Button {
                        watchAd()
                    } label: {
                        HStack {
                            Image(systemName: isWatching ? "hourglass" : "play.fill")
                            Text(isWatching
                                ? "Реклама воспроизводится…"
                                : "Посмотреть рекламу \(min(model.watchedAds + 1, 3)) из 3")
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
                    .disabled(isWatching)
                    .padding(.top, 14)

                    Text("Можно смотреть сколько угодно комплектов. Каждый комплект добавляет ещё 1 час и 200 МБ; устройство остаётся одно.")
                        .font(.system(size: 10)).foregroundStyle(DS.muted).lineSpacing(3)
                        .padding(.top, 14)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }

            if showReward {
                Color.black.opacity(0.38).ignoresSafeArea()
                RewardOverlay(model: model, showReward: $showReward)
                    .padding(14)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    private func watchAd() {
        guard !isWatching else { return }
        isWatching = true
        HapticManager.shared.play(.adStarted)
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            let completed = model.watchNextAd()
            isWatching = false
            if completed {
                showReward = true
            } else {
                HapticManager.shared.play(.adCompleted)
            }
        }
    }
}

private struct AdProgressCell: View {
    let number: Int
    let isComplete: Bool
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 7) {
            Text(isComplete ? "✓" : String(format: "%02d", number))
                .microLabel(color: isComplete ? DS.acid : DS.ink)
                .frame(width: 25, height: 25)
                .background(isComplete ? DS.ink : .clear)
                .overlay(Rectangle().stroke(DS.line))
            Text(isComplete ? "Просмотрена" : (isCurrent ? "Доступна" : "Следующая"))
                .font(.system(size: 9, weight: .medium))
        }
        .frame(maxWidth: .infinity, minHeight: 69)
        .background(isComplete ? DS.acid.opacity(0.11) : .clear)
        .overlay(Rectangle().stroke(DS.line))
    }
}

private struct RewardOverlay: View {
    @ObservedObject var model: VPNConnectionModel
    @Binding var showReward: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "checkmark")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(DS.acid)
                .frame(width: 58, height: 58)
                .background(DS.ink)
            Text("НАГРАДА НАЧИСЛЕНА").microLabel().padding(.top, 17)
            Text("Добавлен 1 час VPN")
                .font(.system(size: 25, weight: .semibold))
                .padding(.top, 6)
            Text("Баланс обновлён. Можно подключиться сейчас или накопить ещё несколько часов.")
                .font(.system(size: 11)).foregroundStyle(DS.muted)
                .padding(.top, 7)

            HStack(spacing: 0) {
                RewardFact(label: "ВРЕМЯ", value: "+1 Ч")
                RewardFact(label: "ТРАФИК", value: "+200 МБ")
                RewardFact(label: "УСТРОЙСТВА", value: "1")
            }
            .padding(.top, 17)

            HStack(spacing: 7) {
                AccessButton(title: "Ещё час", secondary: true) { showReward = false }
                AccessButton(title: "Подключиться") {
                    showReward = false
                    model.clearAccessChoiceContext()
                    model.handleAccessChoiceFree()
                }
            }
            .padding(.top, 15)
        }
        .padding(18)
        .background(DS.paper)
    }
}

private struct RewardFact: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).microLabel()
            Text(value).font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(.horizontal, 8)
        .overlay(alignment: .leading) { Rectangle().fill(DS.line).frame(width: 1) }
        .overlay(alignment: .top) { Hairline(color: DS.ink) }
        .overlay(alignment: .bottom) { Hairline() }
    }
}

struct DirectPremiumPlansView: View {
    @ObservedObject var model: VPNConnectionModel

    private let plans = [(1, 249), (2, 449), (3, 599), (6, 999), (12, 1799)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                AccessBackButton(model: model, title: "Подписки")
                PageHeading(
                    kicker: "DIRECT / PREMIUM",
                    title: "Выберите срок",
                    subtitle: "VPN без рекламы с расширяемыми лимитами"
                )
                .padding(.top, 17)

                AccessSectionHeader(title: "ДЛИТЕЛЬНОСТЬ", meta: "ДЕМО-ЦЕНЫ")
                    .padding(.top, 25)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                    ForEach(plans, id: \.0) { months, price in
                        Button {
                            model.selectPlan(months: months, price: price)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(planTitle(months))
                                    .font(.system(size: 12, weight: .semibold))
                                Text("\(price) ₽").font(.system(size: 9)).opacity(0.58)
                            }
                            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                            .padding(.horizontal, 10)
                            .foregroundStyle(model.selectedPlanMonths == months ? DS.acid : DS.ink)
                            .background(model.selectedPlanMonths == months ? DS.ink : .clear)
                            .overlay(Rectangle().stroke(model.selectedPlanMonths == months ? DS.ink : DS.line))
                        }
                        .buttonStyle(HapticButtonStyle())
                    }
                }

                PlanSummaryView(model: model)
                    .padding(.top, 16)

                AccessButton(title: "Продолжить") {
                    model.checkoutReturnPage = .premiumPlans
                    model.detailPage = .payment
                }
                .padding(.top, 14)

                Text("Точные цены и доступные способы оплаты подставляются для страны App Store пользователя.")
                    .font(.system(size: 10)).foregroundStyle(DS.muted).lineSpacing(3)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    private func planTitle(_ months: Int) -> String {
        switch months {
        case 1: return "1 месяц"
        case 2, 3: return "\(months) месяца"
        default: return "\(months) месяцев"
        }
    }
}

private struct PlanSummaryView: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("DIRECT PREMIUM").microLabel(color: .white.opacity(0.42))
                    Text(model.selectedPlanMonths == 1
                        ? "1 месяц"
                        : (model.selectedPlanMonths == 2 || model.selectedPlanMonths == 3
                            ? "\(model.selectedPlanMonths) месяца"
                            : "\(model.selectedPlanMonths) месяцев"))
                        .font(.system(size: 20, weight: .semibold))
                    Text("Срок начнётся после активации")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.48))
                }
                Spacer()
                Text("\(model.selectedPlanPrice) ₽")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.acid)
            }
            .padding(16)

            HStack(spacing: 0) {
                DarkStat(label: "ТРАФИК", value: "300 ГБ")
                DarkStat(label: "УСТРОЙСТВА", value: "5")
                DarkStat(label: "ЛОКАЦИИ", value: "18")
            }
        }
        .foregroundStyle(.white)
        .background(DS.panel)
    }
}

struct DirectPaymentMethodView: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                AccessBackButton(model: model, title: "Назад", destination: model.checkoutReturnPage)
                PageHeading(kicker: "ОФОРМЛЕНИЕ / ОПЛАТА", title: "Способ оплаты", subtitle: "Выберите доступный вариант")
                    .padding(.top, 17)

                AccessSectionHeader(title: "ОПЛАТА", meta: "02 СПОСОБА")
                    .padding(.top, 25)
                PaymentOption(model: model, method: .apple, mark: "APPLE", subtitle: "Системная оплата · активация автоматически")
                PaymentOption(model: model, method: .external, mark: "WEB", subtitle: "Защищённая страница платёжного партнёра")
                    .padding(.top, 8)

                Text(model.paymentMethod == .apple
                    ? "Покупка будет подтверждена через Apple ID. После оплаты подписка появится автоматически."
                    : "Внешний вариант показывается только в тех storefront, где он разрешён правилами Apple и настроен для приложения.")
                    .font(.system(size: 10)).foregroundStyle(DS.muted).lineSpacing(3)
                    .padding(12)
                    .overlay(alignment: .leading) { Rectangle().fill(DS.green).frame(width: 3) }
                    .background(Color.white.opacity(0.28))
                    .padding(.top, 12)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("ВАШ ЗАКАЗ").microLabel(color: .white.opacity(0.42))
                        Text(model.checkoutTitle).font(.system(size: 18, weight: .semibold))
                    }
                    Spacer()
                    Text("\(model.checkoutPrice) ₽")
                        .font(.system(size: 19, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DS.acid)
                }
                .padding(16)
                .frame(minHeight: 86)
                .foregroundStyle(.white)
                .background(DS.panel)
                .padding(.top, 16)

                AccessButton(title: model.paymentMethod == .apple ? "Продолжить с Apple" : "Открыть защищённую страницу") {
                    HapticManager.shared.play(.purchaseStarted)
                    model.completeCheckout()
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }
}

private struct PaymentOption: View {
    @ObservedObject var model: VPNConnectionModel
    let method: PaymentMethod
    let mark: String
    let subtitle: String

    var body: some View {
        Button {
            model.paymentMethod = method
            HapticManager.shared.play(.selection)
        } label: {
            HStack(spacing: 12) {
                Text(mark).microLabel(color: DS.acid)
                    .frame(width: 44, height: 42).background(DS.ink)
                VStack(alignment: .leading, spacing: 4) {
                    Text(method.rawValue).font(.system(size: 13, weight: .semibold))
                    Text(subtitle).font(.system(size: 9)).foregroundStyle(DS.muted)
                }
                Spacer()
                Image(systemName: model.paymentMethod == method ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(model.paymentMethod == method ? DS.green : DS.muted)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 74)
            .background(model.paymentMethod == method ? DS.acid.opacity(0.09) : .clear)
            .overlay(Rectangle().stroke(model.paymentMethod == method ? DS.green : DS.line))
        }
        .buttonStyle(HapticButtonStyle())
    }
}

struct DirectAddOnsView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var traffic = 0
    @State private var device = false
    @State private var day = false

    private var total: Int {
        let trafficPrice = traffic == 10 ? 79 : traffic == 50 ? 249 : traffic == 100 ? 399 : 0
        return trafficPrice + (device ? 149 : 0) + (day ? 29 : 0)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                AccessBackButton(model: model, title: "Подписки")
                PageHeading(
                    kicker: "DIRECT PREMIUM / УПРАВЛЕНИЕ",
                    title: "Добавить ресурсы",
                    subtitle: "Увеличьте лимиты действующей подписки"
                )
                .padding(.top, 17)

                CurrentPremiumSummary(model: model)
                    .padding(.top, 23)

                AccessSectionHeader(title: "УВЕЛИЧИТЬ ВОЗМОЖНОСТИ", meta: "ВЫБЕРИТЕ")
                    .padding(.top, 23)
                AddOnRow(title: "Добавить трафик", subtitle: "Одноразовое пополнение") {
                    ForEach([10, 50, 100], id: \.self) { value in
                        AddOnChip(title: "+\(value)", isSelected: traffic == value) {
                            let next = traffic == value ? 0 : value
                            traffic = next
                            HapticManager.shared.play(.selection)
                        }
                    }
                }
                AddOnRow(title: "Добавить устройство", subtitle: "До конца текущего срока") {
                    AddOnChip(title: "+1", isSelected: device) {
                        device.toggle()
                        HapticManager.shared.play(device ? .toggleOn : .toggleOff)
                    }
                }
                AddOnRow(title: "Продлить подписку", subtitle: "Ещё один день доступа") {
                    AddOnChip(title: "+1 день", isSelected: day) {
                        day.toggle()
                        HapticManager.shared.play(day ? .toggleOn : .toggleOff)
                    }
                }

                HStack(spacing: 0) {
                    AddOnResultColumn(
                        label: "СЕЙЧАС",
                        days: model.premiumRemainingDays,
                        traffic: model.premiumTrafficGB,
                        devices: model.premiumDevicesUsed,
                        dark: false
                    )
                    AddOnResultColumn(
                        label: "ПОСЛЕ ПОКУПКИ",
                        days: model.premiumRemainingDays + (day ? 1 : 0),
                        traffic: model.premiumTrafficGB + traffic,
                        devices: model.premiumDevicesUsed + (device ? 1 : 0),
                        dark: true
                    )
                }
                .overlay(Rectangle().stroke(DS.line))
                .padding(.top, 15)

                HStack {
                    Text("Итого").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(total) ₽").font(.system(size: 14, weight: .semibold, design: .monospaced))
                }
                .padding(.horizontal, 12)
                .frame(height: 48)
                .overlay(Rectangle().stroke(DS.line))

                AccessButton(title: "Продолжить к оплате") {
                    guard total > 0 else { return }
                    model.prepareAddOnsCheckout(trafficGB: traffic, device: device, day: day, price: total)
                    model.detailPage = .payment
                }
                .opacity(total == 0 ? 0.42 : 1)
                .padding(.top, 12)

                Text("Докупка доступна только для подписок VPN Direct. Лимиты внешних URL управляются их провайдером.")
                    .font(.system(size: 10)).foregroundStyle(DS.muted).lineSpacing(3)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }
}

private struct CurrentPremiumSummary: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("СЕЙЧАС").microLabel(color: .white.opacity(0.42))
                Spacer()
                Text(model.hasPremiumEntitlement ? "АКТИВНА" : "НЕТ ТАРИФА").microLabel(color: DS.acid)
            }
            .padding(.horizontal, 15)
            .frame(height: 38)
            HStack(spacing: 0) {
                DarkStat(label: "СРОК", value: model.hasPremiumEntitlement ? "\(model.premiumRemainingDays) ДНЯ" : "—")
                DarkStat(label: "ТРАФИК", value: "\(model.premiumTrafficGB) ГБ")
                DarkStat(label: "УСТРОЙСТВА", value: "\(model.premiumDevicesUsed)")
            }
        }
        .foregroundStyle(.white)
        .background(DS.panel)
    }
}

private struct AddOnRow<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(subtitle).font(.system(size: 10)).foregroundStyle(DS.muted)
            }
            Spacer()
            HStack(spacing: 4) { content }
        }
        .frame(minHeight: 67)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

private struct AddOnChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isSelected ? DS.acid : DS.ink)
                .padding(.horizontal, 8)
                .frame(height: 31)
                .background(isSelected ? DS.ink : .clear)
                .overlay(Rectangle().stroke(isSelected ? DS.ink : DS.line))
        }
        .buttonStyle(HapticButtonStyle())
    }
}

private struct AddOnResultColumn: View {
    let label: String
    let days: Int
    let traffic: Int
    let devices: Int
    let dark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).microLabel(color: dark ? .white.opacity(0.4) : DS.muted)
            Text("\(days) дня\n\(traffic) ГБ\n\(devices) устройства")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .lineSpacing(4)
        }
        .foregroundStyle(dark ? Color.white : DS.ink)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 105, alignment: .leading)
        .background(dark ? DS.panel : Color.clear)
    }
}

#endif
