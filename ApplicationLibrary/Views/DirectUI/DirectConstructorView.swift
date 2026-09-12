import SwiftUI

#if os(iOS)

/// Sales constructor — live price, single BUY CTA → checkout.
struct DirectConstructorView: View {
    @ObservedObject var model: VPNConnectionModel

    @State private var days = 30
    @State private var devices = 3
    @State private var traffic = 300
    @State private var livePrice: Int?

    private let dayOptions = [7, 30, 90, 180, 365]
    private let deviceOptions = [1, 3, 5, 10, 20]
    private let trafficOptions = [100, 300, 700, 2000, 0] // 0 = unlimited

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {

                PageHeading(
                    kicker: "DIRECT / CUSTOM",
                    title: "Конструктор",
                    subtitle: "Настройте подписку под себя"
                )
                .padding(.top, DS.pageTop)
                .padding(.bottom, 15)

                builderSection("Срок", daysValue) {
                    choices(dayOptions, selected: days) { days = $0 } label: {
                        switch $0 {
                        case 365: return "1 год"
                        case 180: return "6 мес."
                        case 90: return "3 мес."
                        case 30: return "1 мес."
                        default: return "\($0) дней"
                        }
                    }
                }

                builderSection("Устройства", "\(devices)") {
                    choices(deviceOptions, selected: devices) { devices = $0 } label: { "\($0)" }
                }

                builderSection("Трафик", trafficValue) {
                    choices(trafficOptions, selected: traffic) { traffic = $0 } label: {
                        $0 == 0 ? "Безлимит" : ($0 >= 1000 ? "\($0 / 1000) TB" : "\($0) GB")
                    }
                }

                Spacer(minLength: 10)

                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ВАШ ТАРИФ").microLabel(color: DS.muted)
                        Text(planName)
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    }

                    Spacer()

                    Text("\(price) ₽")
                        .font(.system(size: 25, weight: .semibold, design: .monospaced))
                }

                Text("\(daysValue) · \(devices) устройства · \(trafficValue)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(DS.muted)
                    .padding(.top, 5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Button {
                    purchase()
                } label: {
                    HStack {
                        Text("КУПИТЬ")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(DS.ink)
                }
                .buttonStyle(HapticButtonStyle())
                .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .background(DS.paper.ignoresSafeArea())
        .clipped()
        .onAppear {
            model.planBrowseMode = .constructor
            Task { await model.refreshAppCatalog() }
            days = dayOptions.contains(model.selectedPlan.days) ? model.selectedPlan.days : 30
            devices = deviceOptions.contains(model.selectedPlan.devices) ? model.selectedPlan.devices : 3
            if let gb = model.selectedPlan.trafficGB, trafficOptions.contains(gb) {
                traffic = gb
            } else if model.selectedPlan.trafficGB == nil {
                traffic = 0
            } else {
                traffic = 300
            }
            if let c = model.appCatalog?.constructor {
                devices = max(c.minDevices, devices)
                days = max(c.minDays, days)
                if traffic != 0 { traffic = max(c.minTrafficGB, traffic) }
            }
            syncModel()
            Task { await refreshQuote() }
        }
        .onChangeCompat(of: days) { _ in syncModel(); Task { await refreshQuote() } }
        .onChangeCompat(of: devices) { _ in syncModel(); Task { await refreshQuote() } }
        .onChangeCompat(of: traffic) { _ in syncModel(); Task { await refreshQuote() } }
    }

    private func builderSection<Content: View>(
        _ title: String,
        _ value: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Text(value.uppercased()).microLabel(color: DS.muted)
            }
            content()
            Hairline()
        }
        .padding(.vertical, 9)
    }

    private func choices(
        _ values: [Int],
        selected: Int,
        action: @escaping (Int) -> Void,
        label: @escaping (Int) -> String
    ) -> some View {
        HStack(spacing: 6) {
            ForEach(values, id: \.self) { value in
                Button {
                    action(value)
                    HapticManager.shared.play(.selection)
                } label: {
                    Text(label(value))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(selected == value ? DS.paper : DS.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .frame(maxWidth: .infinity)
                        .frame(height: 39)
                        .background(selected == value ? DS.ink : Color.clear)
                        .overlay(Rectangle().stroke(selected == value ? DS.ink : DS.line))
                }
                .buttonStyle(HapticButtonStyle())
            }
        }
    }

    private var daysValue: String {
        switch days {
        case 365: return "1 год"
        case 180: return "6 месяцев"
        case 90: return "3 месяца"
        case 30: return "1 месяц"
        default: return "\(days) дней"
        }
    }

    private var trafficValue: String {
        if traffic == 0 { return "Безлимит" }
        return traffic >= 1000 ? "\(traffic / 1000) TB" : "\(traffic) GB"
    }

    private var planName: String {
        if traffic == 0 || devices >= 20 { return "ULTRA" }
        if traffic >= 2000 || devices >= 10 { return "MAX" }
        if traffic >= 700 || devices >= 5 { return "PRO" }
        if traffic >= 300 || devices >= 3 { return "PLUS" }
        if days <= 7 { return "TRAVEL" }
        return "START"
    }

    private var configuration: PlanConfiguration {
        PlanConfiguration(
            name: planName.capitalized,
            days: days,
            devices: devices,
            trafficGB: traffic == 0 ? nil : traffic,
            whitelistGB: 0
        )
    }

    private var price: Int {
        livePrice ?? VPNDirectPricingEngine.price(for: configuration)
    }

    private func syncModel() {
        model.applySelectedPlan(configuration, playHaptic: false)
    }

    private func refreshQuote() async {
        DirectBackendRuntime.warmUp()
        guard let quote = DirectBackendRuntime.quoteCheckout else { return }
        do {
            let q = try await quote(
                DirectCheckoutQuoteRequest(
                    productKind: "constructor",
                    tariffID: nil,
                    days: days,
                    devices: devices,
                    trafficGB: traffic == 0 ? nil : traffic
                )
            )
            await MainActor.run {
                livePrice = q.amount
                model.checkoutPrice = q.amount
                model.checkoutTitle = q.title
            }
        } catch {
            await MainActor.run { livePrice = nil }
        }
    }

    private func purchase() {
        model.applySelectedPlan(configuration)
        model.checkoutPrice = price
        model.checkoutReturnPage = .planConstructor
        model.pendingCheckoutTariffID = nil
        PendingCheckout.save(
            PendingCheckout(
                title: model.checkoutTitle.isEmpty ? planName : model.checkoutTitle,
                price: price,
                periodDays: days,
                paymentMethodRaw: model.paymentMethod.rawValue,
                returnPage: String(describing: DetailPage.planConstructor),
                planName: planName,
                trafficGB: traffic == 0 ? nil : traffic,
                devices: devices,
                whitelistGB: 0,
                createdAt: Date(),
                productKind: "constructor",
                tariffID: nil,
                addonDays: nil,
                addonDevices: nil,
                addonTrafficGB: nil
            )
        )
        model.openDetail(.payment)
    }
}

#endif
