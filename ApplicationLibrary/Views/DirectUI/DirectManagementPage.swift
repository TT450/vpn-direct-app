import SwiftUI
import Library

#if os(iOS)

/// Management — Direct subscription first; renew primary; third-party at bottom.
struct DirectManagementPage: View {
    @ObservedObject var model: VPNConnectionModel
    let openAddMenu: () -> Void

    private var imported: [VPNSubscriptionItem] { model.importedSubscriptions }

    private var trafficLimit: Int {
        if model.hasPremiumEntitlement {
            return model.premiumTrafficGB >= VPNConnectionModel.unlimitedTrafficGB
                ? 0
                : max(model.premiumTrafficGB, 1)
        }
        return model.selectedPlan.trafficGB ?? 0
    }

    private var whiteListLimit: Int {
        model.hasPremiumEntitlement ? model.premiumWhitelistGB : model.selectedPlan.whitelistGB
    }

    /// Demo usage until backend reports real counters.
    private var trafficUsed: Int {
        guard trafficLimit > 0 else { return 0 }
        return Int(Double(trafficLimit) * 0.35)
    }

    private var whiteListUsed: Int {
        guard whiteListLimit > 0 else { return 0 }
        return Int(Double(whiteListLimit) * 0.28)
    }

    private var expirationText: String {
        guard model.hasPremiumEntitlement, model.premiumRemainingDays > 0 else {
            return "—"
        }
        let date = Calendar.current.date(byAdding: .day, value: model.premiumRemainingDays, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return formatter.string(from: date)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(
                    kicker: "DIRECT / MANAGEMENT",
                    title: "Управление",
                    subtitle: "Ваша подписка VPN Direct"
                )
                .padding(.top, DS.pageTop)
                .padding(.bottom, 16)

                subscriptionCard

                primaryActions
                    .padding(.top, 20)

                usageSection
                    .padding(.top, 22)

                settingsSection
                    .padding(.top, 22)

                externalSection
                    .padding(.top, 22)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 20)
        }
        .background(DS.paper.ignoresSafeArea())
    }

    private var planNameLabel: String {
        if let name = model.selectedPlan.name, model.hasPremiumEntitlement {
            return name.uppercased()
        }
        return model.hasPremiumEntitlement ? "DIRECT" : "—"
    }

    private var planSummaryLine: String {
        let traffic: String = {
            if model.hasPremiumEntitlement {
                return model.premiumTrafficDisplayLabel
            }
            return model.selectedPlan.trafficLabel
        }()
        let devices = model.hasPremiumEntitlement ? model.premiumDeviceLimit : model.selectedPlan.devices
        let wl = model.hasPremiumEntitlement ? model.premiumWhitelistGB : model.selectedPlan.whitelistGB
        let wlPart = wl > 0 ? " · \(wl) GB White-list" : ""
        return "\(traffic) · \(devices) устройства\(wlPart)"
    }

    private var subscriptionCard: some View {
        let active = model.hasPremiumEntitlement && model.isPremiumAccessReady
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(planNameLabel)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                Spacer()
                Text(active ? "● АКТИВНА" : "○ НЕТ ТАРИФА")
                    .microLabel(color: active ? DS.green : DS.muted)
            }

            Text(planSummaryLine)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(DS.muted)
                .padding(.top, 6)

            Hairline().padding(.vertical, 13)

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ДО ОКОНЧАНИЯ").microLabel(color: DS.muted)
                    Text(model.hasPremiumEntitlement ? "\(model.premiumRemainingDays) дней" : "—")
                        .font(.system(size: 19, weight: .semibold, design: .monospaced))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("ОКОНЧАНИЕ").microLabel(color: DS.muted)
                    Text(expirationText)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }
        }
        .padding(15)
        .background(DS.panel)
        .foregroundStyle(.white)
        .overlay(Rectangle().stroke(DS.ink, lineWidth: 1.5))
    }

    private var primaryActions: some View {
        Button {
            renew()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ПОДПИСКА").microLabel(color: DS.acid.opacity(0.7))
                    Text(model.hasPremiumEntitlement ? "Продлить" : "Купить тариф")
                        .font(.system(size: 16, weight: .semibold))
                }
                Spacer()
                Image(systemName: "arrow.right")
            }
            .foregroundStyle(DS.acid)
            .padding(.horizontal, 15)
            .frame(height: 62)
            .background(DS.ink)
        }
        .buttonStyle(HapticButtonStyle())
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("ИСПОЛЬЗОВАНИЕ")

            if trafficLimit > 0 {
                usageRow(title: "VPN TRAFFIC", used: trafficUsed, limit: trafficLimit, unit: "GB")
            } else {
                usageUnlimitedRow(title: "VPN TRAFFIC", caption: model.hasPremiumEntitlement ? "Unlimited" : "—")
            }
            Hairline()
            if whiteListLimit > 0 {
                usageRow(title: "WHITE-LIST", used: whiteListUsed, limit: whiteListLimit, unit: "GB")
            } else {
                usageUnlimitedRow(title: "WHITE-LIST", caption: "—")
            }
        }
    }

    private func usageRow(title: String, used: Int, limit: Int, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title).microLabel(color: DS.muted)
                Spacer()
                Text("\(used) / \(limit) \(unit)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(DS.line).frame(height: 5)
                    Rectangle()
                        .fill(DS.ink)
                        .frame(
                            width: geo.size.width * min(CGFloat(used) / CGFloat(max(limit, 1)), 1),
                            height: 5
                        )
                }
            }
            .frame(height: 5)
        }
        .padding(.vertical, 11)
    }

    private func usageUnlimitedRow(title: String, caption: String) -> some View {
        HStack {
            Text(title).microLabel(color: DS.muted)
            Spacer()
            Text(caption)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
        .padding(.vertical, 11)
    }

    private var settingsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("НАСТРОЙКА")

            managementRow("Изменить тариф") {
                model.openPremiumPlans(mode: .presets)
            }
            Hairline()
            managementRow("Изменить устройства") {
                model.openPremiumPlans(mode: .constructor)
            }
            Hairline()
            managementRow("Изменить трафик") {
                model.openPremiumPlans(mode: .constructor)
            }
        }
    }

    private func managementRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.muted)
            }
            .foregroundStyle(DS.ink)
            .frame(height: 47)
        }
        .buttonStyle(HapticButtonStyle())
    }

    private var externalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("ДРУГИЕ ПОДПИСКИ")

            if imported.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Нет добавленных подписок")
                        .font(.system(size: 12, weight: .medium))
                    Text("Можно добавить стороннюю подписку и использовать её вместе с VPN Direct.")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.muted)
                }
                .padding(.vertical, 13)
            } else {
                ForEach(imported) { item in
                    Button {
                        model.setImportedAccessAndActivate(item.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(model.isSubscriptionActive(item.id) ? "Добавлена · активна" : "Добавлена извне")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(DS.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8))
                                .foregroundStyle(DS.muted)
                        }
                        .foregroundStyle(DS.ink)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(HapticButtonStyle())
                    Hairline()
                }
            }

            Button(action: openAddMenu) {
                HStack {
                    Image(systemName: "plus")
                    Text("ДОБАВИТЬ ПОДПИСКУ")
                    Spacer()
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.ink)
                .frame(height: 45)
            }
            .buttonStyle(HapticButtonStyle())
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title).microLabel(color: DS.ink)
            Spacer()
        }
        .frame(height: 38)
        .overlay(alignment: .top) { Hairline(color: DS.ink) }
    }

    private func renew() {
        if model.hasPremiumEntitlement {
            var plan = model.selectedPlan
            if plan.devices <= 0 {
                plan = VPNDirectPlanCatalog.defaultConfiguration()
            }
            plan.days = max(plan.days, 30)
            model.applySelectedPlan(plan)
            model.checkoutReturnPage = .premiumPlans
            model.openDetail(.payment)
        } else {
            model.openPremiumPlans(mode: .presets)
        }
    }
}

#endif
