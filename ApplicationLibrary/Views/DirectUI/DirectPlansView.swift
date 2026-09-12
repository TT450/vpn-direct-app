import SwiftUI

#if os(iOS)

/// Sales-first tariff page: period on page, BUY on every card → checkout.
struct DirectPlansView: View {
    @ObservedObject var model: VPNConnectionModel

    @State private var period: PlanPeriod = .oneMonth
    @State private var quotedPrices: [Int: Int] = [:]

    private var catalogTariffs: [DirectAppTariff] {
        model.appCatalog?.tariffs ?? []
    }

    private var fallbackPlans: [DirectPresetPlan] {
        [
            .init(id: "start", name: "START", trafficGB: 100, whiteListGB: 0, devices: 1, badge: nil, subtitle: "Для одного устройства"),
            .init(id: "plus", name: "PLUS", trafficGB: 300, whiteListGB: 0, devices: 3, badge: "ПОПУЛЯРНЫЙ", subtitle: "Оптимальный вариант"),
            .init(id: "pro", name: "PRO", trafficGB: 700, whiteListGB: 0, devices: 5, badge: nil, subtitle: "Для нескольких устройств"),
            .init(id: "max", name: "MAX", trafficGB: 2000, whiteListGB: 0, devices: 10, badge: nil, subtitle: "Большой запас трафика"),
            .init(id: "ultra", name: "ULTRA", trafficGB: nil, whiteListGB: 0, devices: 20, badge: "UNLIMITED", subtitle: "Без ограничений по трафику"),
        ]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(
                    kicker: "DIRECT / PLANS",
                    title: "Тарифы",
                    subtitle: "Выберите готовый вариант и подключите его сразу"
                )
                .padding(.top, DS.pageTop)
                .padding(.bottom, 18)

                periodPicker

                VStack(spacing: 10) {
                    if !catalogTariffs.isEmpty {
                        ForEach(catalogTariffs) { tariff in
                            catalogCard(tariff)
                        }
                    } else {
                        ForEach(fallbackPlans) { plan in
                            planCard(plan)
                        }
                    }
                }
                .padding(.top, 16)

                constructorButton
                    .padding(.top, 14)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 20)
        }
        .background(DS.paper.ignoresSafeArea())
        .onAppear {
            model.planBrowseMode = .presets
            if let match = PlanPeriod.allCases.first(where: { $0.days == model.selectedPlan.days }) {
                period = match
            }
            Task {
                await model.refreshAppCatalog()
                await refreshQuotes()
            }
        }
        .onChangeCompat(of: period) { _ in
            Task { await refreshQuotes() }
        }
    }

    private var periodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ПЕРИОД").microLabel(color: DS.ink)
            HStack(spacing: 6) {
                ForEach(PlanPeriod.allCases) { item in
                    Button {
                        period = item
                        HapticManager.shared.play(.selection)
                    } label: {
                        Text(item.title)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(period == item ? DS.paper : DS.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(period == item ? DS.ink : Color.clear)
                            .overlay(Rectangle().stroke(period == item ? DS.ink : DS.line))
                    }
                    .buttonStyle(HapticButtonStyle())
                }
            }
        }
    }

    private func catalogCard(_ tariff: DirectAppTariff) -> some View {
        let price = quotedPrices[tariff.id] ?? scaledCatalogPrice(tariff)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tariff.name)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    Text(tariff.description.isEmpty ? "VPN Direct" : tariff.description)
                        .font(.system(size: 9))
                        .foregroundStyle(DS.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(price) ₽")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    Text(period.priceSuffix)
                        .microLabel(color: DS.muted)
                }
            }
            Hairline().padding(.vertical, 11)
            HStack(spacing: 0) {
                fact("ТРАФИК", trafficLabel(tariff.trafficGB))
                fact("УСТРОЙСТВА", "\(tariff.devices)")
                fact("ДНИ", "\(period.days)")
            }
            Button {
                purchaseCatalog(tariff, price: price)
            } label: {
                HStack {
                    Text("КУПИТЬ")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.acid)
                .padding(.horizontal, 13)
                .frame(height: 44)
                .background(DS.ink)
            }
            .buttonStyle(HapticButtonStyle())
            .padding(.top, 12)
        }
        .padding(14)
        .overlay(Rectangle().stroke(DS.line))
    }

    private func planCard(_ plan: DirectPresetPlan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(plan.name)
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        if let badge = plan.badge {
                            Text(badge)
                                .font(.system(size: 6, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .frame(height: 20)
                                .background(DS.acid)
                        }
                    }
                    Text(plan.subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(DS.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(displayPrice(for: plan)) ₽")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    Text(period.priceSuffix)
                        .microLabel(color: DS.muted)
                }
            }
            Hairline().padding(.vertical, 11)
            HStack(spacing: 0) {
                fact("ТРАФИК", plan.trafficDisplay)
                fact("УСТРОЙСТВА", "\(plan.devices)")
                fact("ДНИ", "\(period.days)")
            }
            Button { purchase(plan) } label: {
                HStack {
                    Text("КУПИТЬ")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.acid)
                .padding(.horizontal, 13)
                .frame(height: 44)
                .background(DS.ink)
            }
            .buttonStyle(HapticButtonStyle())
            .padding(.top, 12)
        }
        .padding(14)
        .overlay(Rectangle().stroke(plan.id == "plus" ? DS.ink : DS.line, lineWidth: plan.id == "plus" ? 1.5 : 1))
    }

    private func fact(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).microLabel(color: DS.muted)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var constructorButton: some View {
        Button {
            model.openPremiumPlans(mode: .constructor)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("НЕ НАШЛИ ПОДХОДЯЩИЙ?").microLabel(color: DS.muted)
                    Text("Собрать свой тариф")
                        .font(.system(size: 13, weight: .semibold))
                }
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .foregroundStyle(DS.ink)
            .padding(.horizontal, 13)
            .frame(height: 60)
            .overlay(Rectangle().stroke(DS.line))
        }
        .buttonStyle(HapticButtonStyle())
    }

    private func trafficLabel(_ gb: Int?) -> String {
        guard let gb else { return "∞" }
        return gb >= 1000 ? "\(gb / 1000) TB" : "\(gb) GB"
    }

    private func scaledCatalogPrice(_ tariff: DirectAppTariff) -> Int {
        let months = Double(period.days) / Double(max(tariff.days, 1))
        let mult = model.appCatalog?.monthMultipliers[period.days]
            ?? VPNDirectPricingEngine.durationMultiplier(forDays: period.days)
        return max(49, Int((Double(tariff.price) * months * mult / 10).rounded() * 10))
    }

    private func configuration(for plan: DirectPresetPlan) -> PlanConfiguration {
        PlanConfiguration(
            name: plan.name.capitalized,
            days: period.days,
            devices: plan.devices,
            trafficGB: plan.trafficGB,
            whitelistGB: 0
        )
    }

    private func displayPrice(for plan: DirectPresetPlan) -> Int {
        VPNDirectPricingEngine.price(for: configuration(for: plan))
    }

    private func purchase(_ plan: DirectPresetPlan) {
        model.applySelectedPlan(configuration(for: plan), presetID: plan.id)
        model.pendingCheckoutTariffID = nil
        model.checkoutReturnPage = .premiumPlans
        model.openDetail(.payment)
    }

    private func purchaseCatalog(_ tariff: DirectAppTariff, price: Int) {
        let config = PlanConfiguration(
            name: tariff.name,
            days: period.days,
            devices: tariff.devices,
            trafficGB: tariff.trafficGB,
            whitelistGB: 0
        )
        model.applySelectedPlan(config, presetID: "app-\(tariff.id)")
        model.checkoutPrice = price
        model.checkoutTitle = tariff.name
        model.checkoutReturnPage = .premiumPlans
        model.pendingCheckoutTariffID = tariff.id
        PendingCheckout.save(
            PendingCheckout(
                title: tariff.name,
                price: price,
                periodDays: period.days,
                paymentMethodRaw: model.paymentMethod.rawValue,
                returnPage: String(describing: DetailPage.premiumPlans),
                planName: tariff.name,
                trafficGB: tariff.trafficGB,
                devices: tariff.devices,
                whitelistGB: 0,
                createdAt: Date(),
                productKind: "app_tariff",
                tariffID: tariff.id,
                addonDays: nil,
                addonDevices: nil,
                addonTrafficGB: nil
            )
        )
        model.openDetail(.payment)
    }

    private func refreshQuotes() async {
        DirectBackendRuntime.warmUp()
        guard let quote = DirectBackendRuntime.quoteCheckout else { return }
        var map: [Int: Int] = [:]
        for tariff in catalogTariffs {
            do {
                let q = try await quote(
                    DirectCheckoutQuoteRequest(
                        productKind: "app_tariff",
                        tariffID: tariff.id,
                        days: period.days,
                        devices: tariff.devices,
                        trafficGB: tariff.trafficGB
                    )
                )
                map[tariff.id] = q.amount
            } catch {
                map[tariff.id] = scaledCatalogPrice(tariff)
            }
        }
        await MainActor.run { quotedPrices = map }
    }
}

struct DirectPresetPlan: Identifiable, Hashable {
    let id: String
    let name: String
    let trafficGB: Int?
    let whiteListGB: Int
    let devices: Int
    let badge: String?
    let subtitle: String

    var trafficDisplay: String {
        guard let trafficGB else { return "∞" }
        return trafficGB >= 1000 ? "\(trafficGB / 1000) TB" : "\(trafficGB) GB"
    }
}

enum PlanPeriod: String, CaseIterable, Identifiable {
    case oneMonth, threeMonths, sixMonths, nineMonths, oneYear

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .nineMonths: return 270
        case .oneYear: return 365
        }
    }

    var title: String {
        switch self {
        case .oneMonth: return "1 МЕС"
        case .threeMonths: return "3 МЕС"
        case .sixMonths: return "6 МЕС"
        case .nineMonths: return "9 МЕС"
        case .oneYear: return "1 ГОД"
        }
    }

    var priceSuffix: String {
        switch self {
        case .oneMonth: return "ЗА МЕСЯЦ"
        case .threeMonths: return "ЗА 3 МЕС"
        case .sixMonths: return "ЗА 6 МЕС"
        case .nineMonths: return "ЗА 9 МЕС"
        case .oneYear: return "ЗА ГОД"
        }
    }
}

#endif
