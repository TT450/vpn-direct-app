import SwiftUI

#if os(iOS)

struct AccessBackButton: View {
    @ObservedObject var model: VPNConnectionModel
    let title: String
    var destination: DetailPage? = nil

    var body: some View {
        Button {
            model.goBack()
        } label: {
            Image(systemName: "arrow.left")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.muted)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
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
        model.importedSubscriptions.isEmpty ? 1 : 3
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                PageHeading(
                    kicker: "ПОДКЛЮЧЕНИЕ / НАЧАЛО",
                    title: "Выберите доступ",
                    subtitle: "Сначала VPN Direct, затем другие провайдеры"
                )
                .padding(.top, DS.pageTop)

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
                    Text("Оформите тариф VPN Direct или подключите внешнюю подписку.")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                }
                .padding(17)
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                .foregroundStyle(.white)
                .background(DS.panel)
                .padding(.top, 24)

                AccessSectionHeader(title: "VPN DIRECT", meta: String(format: "%02d", connectionMethodCount))
                    .padding(.top, 22)
                AccessChoiceRow(mark: "PLUS", title: "Тарифы VPN Direct", subtitle: "Пресеты и конструктор · Plus рекомендуем") {
                    model.clearAccessChoiceContext()
                    model.handleAccessChoicePremium()
                }

                if !model.importedSubscriptions.isEmpty {
                    AccessSectionHeader(title: "ДРУГИЕ ПРОВАЙДЕРЫ", meta: "02")
                        .padding(.top, 22)
                    AccessChoiceRow(mark: "SUB", title: "Выбрать из добавленных", subtitle: "Внешние подписки в приложении") {
                        model.clearAccessChoiceContext()
                        model.handleAccessChoicePickSubscription()
                    }
                    AccessChoiceRow(mark: "URL", title: "Добавить URL", subtitle: "Подписка любого провайдера") {
                        model.clearAccessChoiceContext()
                        model.handleAccessChoiceAddURL()
                    }
                } else {
                    AccessSectionHeader(title: "ДРУГИЕ ПРОВАЙДЕРЫ", meta: "01")
                        .padding(.top, 22)
                    AccessChoiceRow(mark: "URL", title: "Добавить внешнюю подписку", subtitle: "QR, ссылка, файл или конфиг") {
                        model.clearAccessChoiceContext()
                        model.handleAccessChoiceAddURL()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
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

// TEMPORARILY HIDDEN — duplicate of DirectPlansView; will return in later versions.
// Kept under `#if false` so we can revive without rewrite.
#if false
struct DirectPremiumPlansView: View {
    @ObservedObject var model: VPNConnectionModel

    private var periodOptions: [Int] {
        if model.planBrowseMode == .constructor {
            return VPNDirectPlanCatalog.constructorDays
        }
        if model.selectedPresetID == "travel" {
            return [7] + VPNDirectPlanCatalog.presetPeriodDays
        }
        return VPNDirectPlanCatalog.presetPeriodDays
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                PageHeading(
                    kicker: "DIRECT / ТАРИФЫ",
                    title: "VPN Direct",
                    subtitle: "Готовые пресеты или свой набор лимитов"
                )
                .padding(.top, DS.pageTop)

                planModePicker
                    .padding(.top, 22)

                if model.planBrowseMode == .presets {
                    presetsSection
                } else {
                    constructorSection
                }

                AccessSectionHeader(
                    title: "СРОК",
                    meta: VPNDirectPlanCatalog.periodLabel(days: model.selectedPlan.days).uppercased()
                )
                .padding(.top, 22)
                periodGrid

                PlanCheckoutSummary(plan: model.selectedPlan, price: model.selectedPlanPrice)
                    .padding(.top, 16)

                AccessButton(title: "Продолжить") {
                    model.applySelectedPlan(model.selectedPlan, presetID: model.selectedPresetID)
                    model.checkoutReturnPage = .premiumPlans
                    model.openDetail(.payment)
                }
                .padding(.top, 14)

                Text("Демо-цены для интерфейса. Финальная сумма зависит от способа оплаты и storefront.")
                    .font(.system(size: 10)).foregroundStyle(DS.muted).lineSpacing(3)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear {
            if model.selectedPlan.name == nil, model.planBrowseMode == .presets {
                let featured = VPNDirectPlanCatalog.featured
                model.applySelectedPlan(featured.configuration(days: featured.defaultDays), presetID: featured.id)
            }
        }
    }

    private var planModePicker: some View {
        HStack(spacing: 0) {
            ForEach(VPNDirectPlanMode.allCases) { mode in
                Button {
                    model.planBrowseMode = mode
                    if mode == .presets,
                       let preset = VPNDirectPlanCatalog.preset(id: model.selectedPresetID)
                    {
                        let days = VPNDirectPlanCatalog.presetPeriodDays.contains(model.selectedPlan.days)
                            ? model.selectedPlan.days
                            : preset.defaultDays
                        model.applySelectedPlan(preset.configuration(days: days), presetID: preset.id)
                    } else if mode == .constructor {
                        var custom = model.selectedPlan
                        custom.name = nil
                        model.applySelectedPlan(custom)
                    }
                } label: {
                    Text(mode.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(model.planBrowseMode == mode ? DS.acid : DS.ink)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(model.planBrowseMode == mode ? DS.ink : Color.clear)
                }
                .buttonStyle(HapticButtonStyle())
            }
        }
        .overlay(Rectangle().stroke(DS.line))
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            AccessSectionHeader(title: "ГОТОВЫЕ ТАРИФЫ", meta: String(format: "%02d", VPNDirectPlanCatalog.presets.count))
                .padding(.top, 18)
            ForEach(VPNDirectPlanCatalog.presets) { preset in
                let daysForPrice = periodOptions.contains(model.selectedPlan.days)
                    ? model.selectedPlan.days
                    : preset.defaultDays
                PresetPlanCard(
                    preset: preset,
                    isSelected: model.selectedPresetID == preset.id,
                    price: VPNDirectPricingEngine.price(for: preset.configuration(days: daysForPrice))
                ) {
                    let days = periodOptions.contains(model.selectedPlan.days)
                        ? model.selectedPlan.days
                        : preset.defaultDays
                    model.applySelectedPlan(preset.configuration(days: days), presetID: preset.id)
                }
            }
        }
    }

    private var constructorSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            AccessSectionHeader(title: "КОНСТРУКТОР", meta: "СВОЙ НАБОР")
                .padding(.top, 18)

            optionHeader("УСТРОЙСТВА")
            intChipRow(values: VPNDirectPlanCatalog.constructorDevices, selected: model.selectedPlan.devices) { value in
                var plan = model.selectedPlan
                plan.name = nil
                plan.devices = value
                model.applySelectedPlan(plan)
            }

            optionHeader("ТРАФИК")
            trafficChipRow
        }
    }

    private var trafficChipRow: some View {
        let columns = [GridItem(.adaptive(minimum: 72), spacing: 6)]
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(VPNDirectPlanCatalog.constructorTrafficGB.enumerated()), id: \.offset) { _, gb in
                let isOn = model.selectedPlan.trafficGB == gb
                Button {
                    var plan = model.selectedPlan
                    plan.name = nil
                    plan.trafficGB = gb
                    model.applySelectedPlan(plan)
                } label: {
                    Text(VPNDirectPlanCatalog.trafficOptionLabel(gb))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isOn ? DS.acid : DS.ink)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(isOn ? DS.ink : Color.clear)
                        .overlay(Rectangle().stroke(isOn ? DS.ink : DS.line))
                }
                .buttonStyle(HapticButtonStyle())
            }
        }
    }

    private var periodGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
            ForEach(periodOptions, id: \.self) { days in
                let sample: PlanConfiguration = {
                    var plan = model.selectedPlan
                    plan.days = days
                    return plan
                }()
                let price = VPNDirectPricingEngine.price(for: sample)
                Button {
                    var plan = model.selectedPlan
                    plan.days = days
                    model.applySelectedPlan(plan, presetID: model.selectedPresetID)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(VPNDirectPlanCatalog.periodLabel(days: days))
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(price) ₽").font(.system(size: 9)).opacity(0.58)
                    }
                    .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                    .padding(.horizontal, 10)
                    .foregroundStyle(model.selectedPlan.days == days ? DS.acid : DS.ink)
                    .background(model.selectedPlan.days == days ? DS.ink : .clear)
                    .overlay(Rectangle().stroke(model.selectedPlan.days == days ? DS.ink : DS.line))
                }
                .buttonStyle(HapticButtonStyle())
            }
        }
    }

    private func optionHeader(_ title: String) -> some View {
        Text(title)
            .microLabel(color: DS.muted)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    private func intChipRow(
        values: [Int],
        selected: Int,
        label: ((Int) -> String)? = nil,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        let columns = [GridItem(.adaptive(minimum: 72), spacing: 6)]
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(values, id: \.self) { value in
                let isOn = selected == value
                Button {
                    onSelect(value)
                } label: {
                    Text(label?(value) ?? "\(value)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isOn ? DS.acid : DS.ink)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(isOn ? DS.ink : Color.clear)
                        .overlay(Rectangle().stroke(isOn ? DS.ink : DS.line))
                }
                .buttonStyle(HapticButtonStyle())
            }
        }
    }
}


private struct PresetPlanCard: View {
    let preset: VPNDirectPlanPreset
    let isSelected: Bool
    let price: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(preset.name.uppercased())
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    if preset.isFeatured {
                        Text("★ ПОПУЛЯРНЫЙ")
                            .microLabel(color: DS.acid)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(DS.ink)
                    }
                }
                Text(preset.tagline)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.55) : DS.muted)
                    .padding(.top, 6)

                HStack(spacing: 0) {
                    presetStat(label: "ТРАФИК", value: VPNDirectPlanCatalog.trafficOptionLabel(preset.trafficGB), dark: isSelected)
                    presetStat(label: "УСТР.", value: "\(preset.devices)", dark: isSelected)
                    presetStat(label: "ДНИ", value: "\(preset.defaultDays)", dark: isSelected)
                }
                .padding(.top, 12)

                HStack {
                    Text("от \(price) ₽")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    Spacer()
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                }
                .padding(.top, 10)
            }
            .padding(14)
            .foregroundStyle(isSelected ? Color.white : DS.ink)
            .background(isSelected ? DS.panel : Color.white.opacity(0.72))
            .overlay(Rectangle().stroke(isSelected ? DS.green : DS.line))
        }
        .buttonStyle(HapticButtonStyle())
    }

    private func presetStat(label: String, value: String, dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).microLabel(color: dark ? .white.opacity(0.42) : DS.muted)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PlanCheckoutSummary: View {
    let plan: PlanConfiguration
    let price: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("VPN DIRECT").microLabel(color: .white.opacity(0.42))
                    Text(plan.displayTitle)
                        .font(.system(size: 20, weight: .semibold))
                    Text(plan.summaryLine)
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.48))
                }
                Spacer()
                Text("\(price) ₽")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.acid)
            }
            .padding(16)

            HStack(spacing: 0) {
                DarkStat(label: "ТРАФИК", value: plan.trafficLabel)
                DarkStat(label: "СРОК", value: "\(plan.days) дн.")
                DarkStat(label: "УСТРОЙСТВА", value: "\(plan.devices)")
            }
        }
        .foregroundStyle(.white)
        .background(DS.panel)
    }
}
#endif

struct DirectPaymentMethodView: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                PageHeading(kicker: "ОФОРМЛЕНИЕ / ОПЛАТА", title: "Способ оплаты", subtitle: "Выберите доступный вариант")
                    .padding(.top, DS.pageTop)

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
                    model.requestCheckoutPayment()
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
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
    @State private var liveTotal: Int?

    private var total: Int {
        if let liveTotal { return liveTotal }
        let trafficPrice = traffic == 10 ? 79 : traffic == 50 ? 249 : traffic == 100 ? 399 : 0
        return trafficPrice + (device ? 149 : 0) + (day ? 29 : 0)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                PageHeading(
                    kicker: "DIRECT PREMIUM / УПРАВЛЕНИЕ",
                    title: "Добавить ресурсы",
                    subtitle: "Увеличьте лимиты действующей подписки"
                )
                .padding(.top, DS.pageTop)

                CurrentPremiumSummary(model: model)
                    .padding(.top, 23)

                AccessSectionHeader(title: "УВЕЛИЧИТЬ ВОЗМОЖНОСТИ", meta: "ВЫБЕРИТЕ")
                    .padding(.top, 23)
                AddOnRow(title: "Добавить трафик", subtitle: "К остатку периода") {
                    ForEach([10, 50, 100], id: \.self) { value in
                        AddOnChip(title: "+\(value)", isSelected: traffic == value) {
                            let next = traffic == value ? 0 : value
                            traffic = next
                            HapticManager.shared.play(.selection)
                            Task { await refreshQuote() }
                        }
                    }
                }
                AddOnRow(title: "Добавить устройство", subtitle: "До конца текущего срока") {
                    AddOnChip(title: "+1", isSelected: device) {
                        device.toggle()
                        HapticManager.shared.play(device ? .toggleOn : .toggleOff)
                        Task { await refreshQuote() }
                    }
                }
                AddOnRow(title: "Продлить подписку", subtitle: "Ещё один день доступа") {
                    AddOnChip(title: "+1 день", isSelected: day) {
                        day.toggle()
                        HapticManager.shared.play(day ? .toggleOn : .toggleOff)
                        Task { await refreshQuote() }
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
                    model.openDetail(.payment)
                }
                .opacity(total == 0 ? 0.42 : 1)
                .padding(.top, 12)

                Text("Докупка доступна только для подписок VPN Direct. Лимиты внешних URL управляются их провайдером.")
                    .font(.system(size: 10)).foregroundStyle(DS.muted).lineSpacing(3)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear {
            Task {
                await model.refreshAppCatalog()
                await refreshQuote()
            }
        }
    }

    private func refreshQuote() async {
        DirectBackendRuntime.warmUp()
        guard traffic > 0 || device || day else {
            await MainActor.run { liveTotal = nil }
            return
        }
        guard let quote = DirectBackendRuntime.quoteCheckout else { return }
        do {
            let q = try await quote(
                DirectCheckoutQuoteRequest(
                    productKind: "addon",
                    tariffID: nil,
                    days: day ? 1 : nil,
                    devices: device ? 1 : nil,
                    trafficGB: traffic > 0 ? traffic : nil
                )
            )
            await MainActor.run { liveTotal = q.amount }
        } catch {
            await MainActor.run { liveTotal = nil }
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
                DarkStat(label: "ТРАФИК", value: model.hasPremiumEntitlement ? model.premiumTrafficDisplayLabel : "—")
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
