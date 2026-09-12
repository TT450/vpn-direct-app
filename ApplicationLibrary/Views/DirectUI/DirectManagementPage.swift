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

    /// Real usage from backend: limit − remaining (0 until /me reports remaining).
    private var trafficUsed: Int {
        guard trafficLimit > 0 else { return 0 }
        if model.hasPremiumEntitlement {
            return min(model.premiumTrafficUsedGB, trafficLimit)
        }
        return 0
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
                    subtitle: "Подписка, лимиты и настройки VPN Direct"
                )
                .padding(.top, DS.pageTop)
                .padding(.bottom, 16)

                subscriptionCard

                primaryActions
                    .padding(.top, 12)

                usageSection
                    .padding(.top, 24)

                settingsSection
                    .padding(.top, 24)

                externalSection
                    .padding(.top, 24)
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
        return model.hasPremiumEntitlement ? "DIRECT" : "БЕЗ ТАРИФА"
    }

    private var planSummaryLine: String {
        let traffic: String = {
            if model.hasPremiumEntitlement {
                return model.premiumTrafficDisplayLabel
            }
            return model.selectedPlan.trafficLabel
        }()
        let devices = model.hasPremiumEntitlement ? model.premiumDeviceLimit : model.selectedPlan.devices
        return "\(traffic) · \(devices) устройства"
    }

    @ViewBuilder
    private var subscriptionCard: some View {
        if model.hasNativeDirectSubscription {
            nativeDirectSubscriptionCard
        }
    }

    private var nativeDirectSubscriptionCard: some View {
        let active = model.hasPremiumEntitlement && model.isPremiumAccessReady
        let inUse = model.isNativeDirectSubscriptionActive

        // Card + CTA flush (no gap) so they read as one block.
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("01 / ПОДПИСКА")
                            .microLabel(color: DS.acid.opacity(0.75))
                        Text(planNameLabel)
                            .font(.system(size: 24, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }

                    Spacer(minLength: 12)

                    Text(active ? "● АКТИВНА" : "○ НЕТ ТАРИФА")
                        .microLabel(color: active ? DS.acid : DS.muted)
                        .padding(.top, 3)
                }

                Text(planSummaryLine)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(DS.paper.opacity(0.58))
                    .lineLimit(2)
                    .padding(.top, 8)

                Rectangle()
                    .fill(DS.paper.opacity(0.16))
                    .frame(height: 1)
                    .padding(.vertical, 14)

                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ДО ОКОНЧАНИЯ")
                            .microLabel(color: DS.paper.opacity(0.55))
                        Text(model.hasPremiumEntitlement ? "\(model.premiumRemainingDays) дней" : "—")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("ОКОНЧАНИЕ")
                            .microLabel(color: DS.paper.opacity(0.55))
                        Text(expirationText)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.ink)

            Button {
                guard !inUse else { return }
                model.useNativeDirectSubscription()
            } label: {
                Text(inUse ? "Используется" : "Использовать")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(DS.acid)
            }
            .buttonStyle(HapticButtonStyle())
            // Do not `.disabled` — iOS greys the label; keep full acid + black always.
        }
        .overlay(Rectangle().stroke(DS.ink, lineWidth: 1.5))
    }

    private var primaryActions: some View {
        Button {
            renew()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.hasPremiumEntitlement ? "ПОДПИСКА" : "VPN DIRECT")
                        .microLabel(color: DS.acid.opacity(0.72))
                    Text(model.hasPremiumEntitlement ? "Продлить подписку" : "Выбрать тариф")
                        .font(.system(size: 16, weight: .semibold))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(DS.acid)
            .padding(.horizontal, 15)
            .frame(height: 62)
            .background(DS.ink)
            .overlay(Rectangle().stroke(DS.ink))
        }
        .buttonStyle(HapticButtonStyle())
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("02 / ИСПОЛЬЗОВАНИЕ")

            if trafficLimit > 0 {
                usageRow(title: "VPN TRAFFIC", used: trafficUsed, limit: trafficLimit, unit: "GB")
            } else {
                usageUnlimitedRow(title: "VPN TRAFFIC", caption: model.hasPremiumEntitlement ? "UNLIMITED" : "—")
            }
        }
    }

    private func usageRow(title: String, used: Int, limit: Int, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).microLabel(color: DS.muted)
                Spacer()
                Text("\(used) / \(limit) \(unit)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.ink)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(DS.line)
                        .frame(height: 5)
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
        .padding(.vertical, 12)
    }

    private func usageUnlimitedRow(title: String, caption: String) -> some View {
        HStack {
            Text(title).microLabel(color: DS.muted)
            Spacer()
            Text(caption)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(DS.ink)
        }
        .padding(.vertical, 13)
    }

    private var settingsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("03 / НАСТРОЙКА")

            managementRow("Изменить тариф", detail: "ГОТОВЫЕ ПЛАНЫ") {
                model.openPremiumPlans(mode: .presets)
            }
            Hairline()
            managementRow("Изменить устройства", detail: "КОНСТРУКТОР") {
                model.openPremiumPlans(mode: .constructor)
            }
            Hairline()
            managementRow("Изменить трафик", detail: "КОНСТРУКТОР") {
                model.openPremiumPlans(mode: .constructor)
            }
        }
    }

    private func managementRow(_ title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.ink)
                    Text(detail)
                        .microLabel(color: DS.muted)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS.ink)
            }
            .frame(minHeight: 52)
        }
        .buttonStyle(HapticButtonStyle())
    }

    private var externalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("04 / ДРУГИЕ ПОДПИСКИ")

            if imported.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Нет добавленных подписок")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.ink)
                    Text("Добавьте стороннюю подписку, если хотите использовать её вместе с VPN Direct.")
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
                                    .foregroundStyle(DS.ink)
                                Text(model.isSubscriptionActive(item.id) ? "Добавлена · активна" : "Добавлена извне")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(DS.muted)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(DS.ink)
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(HapticButtonStyle())
                    Hairline()
                }
            }

            Button(action: openAddMenu) {
                HStack(spacing: 9) {
                    Image(systemName: "plus")
                    Text("ДОБАВИТЬ ПОДПИСКУ")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.acid)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(DS.ink)
            }
            .buttonStyle(HapticButtonStyle())
            .padding(.top, 4)
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
