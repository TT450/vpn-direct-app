import SwiftUI
import Library

#if os(iOS)

/// Management — compact mock layout (no stretch, no scroll).
struct DirectManagementPage: View {
    @ObservedObject var model: VPNConnectionModel
    let openAddMenu: () -> Void

    @State private var showDevices = false
    @State private var showPayments = false
    @State private var showSupport = false

    private var trafficMeter: (used: Double, limit: Double, unlimited: Bool) {
        if model.hasPremiumEntitlement {
            if model.premiumTrafficGB > 0,
               model.premiumTrafficGB < VPNConnectionModel.unlimitedTrafficGB
            {
                let limit = Double(model.premiumTrafficGB)
                let used = min(limit, max(0, liveSubscriptionUsedGB(limit: limit)))
                return (used, limit, false)
            }
            return (0, 0, true)
        }
        if let planGB = model.selectedPlan.trafficGB, planGB > 0 {
            return (0, Double(planGB), false)
        }
        return (0, 0, true)
    }

    private func liveSubscriptionUsedGB(limit: Double) -> Double {
        if let exact = model.premiumTrafficUsedExactGB, exact.isFinite, exact >= 0 {
            return exact
        }
        let profileID: Int64? = {
            if let active = model.activeSubscription?.id, active > 0 { return active }
            if model.activeSubscriptionID > 0 { return model.activeSubscriptionID }
            return model.subscriptions.first(where: {
                DirectBuiltinProfile.isDirectOwned($0.profile.remoteURL)
            })?.id
        }()
        if let profileID,
           let meta = SubscriptionMetadataStore.load(profileID: profileID)
        {
            let bytes = meta.trafficUsedBytes
            if bytes > 0 {
                return Double(bytes) / (1024.0 * 1024.0 * 1024.0)
            }
        }
        let locationUsed = model.locationCaps.reduce(0.0) { partial, cap in
            if let used = cap.usedGb, used.isFinite, used > 0 {
                return partial + used
            }
            if let rem = cap.remainingGb, let lim = cap.capGb, lim > rem {
                return partial + max(0, lim - rem)
            }
            return partial
        }
        if locationUsed > 0 { return min(locationUsed, limit) }
        if let remaining = model.premiumTrafficRemainingGB {
            return max(0, limit - Double(max(0, remaining)))
        }
        return Double(model.premiumTrafficUsedGB)
    }

    private var expirationText: String {
        guard model.hasPremiumEntitlement, model.premiumRemainingDays > 0 else { return "—" }
        let date = Calendar.current.date(byAdding: .day, value: model.premiumRemainingDays, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return formatter.string(from: date).uppercased()
    }

    private var remainingDaysLabel: String {
        guard model.hasPremiumEntitlement, model.premiumRemainingDays > 0 else { return "—" }
        let n = model.premiumRemainingDays
        let word: String = {
            let mod10 = n % 10
            let mod100 = n % 100
            if mod10 == 1, mod100 != 11 { return "ДЕНЬ" }
            if (2 ... 4).contains(mod10), !(12 ... 14).contains(mod100) { return "ДНЯ" }
            return "ДНЕЙ"
        }()
        return "\(n) \(word)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            subscriptionBlock

            trafficSection
                .padding(.top, 12)

            resourcesSection
                .padding(.top, 12)

            VStack(spacing: 0) {
                Hairline(color: Color.black.opacity(0.12))
                planRow
                Hairline(color: Color.black.opacity(0.12))
                externalRow
                Hairline(color: Color.black.opacity(0.12))
            }
            .padding(.top, 10)

            helpBar
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, DS.pageTop)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DS.paper.ignoresSafeArea())
        .onAppear {
            if model.hasPremiumEntitlement {
                model.syncSelectedPlanFromActiveSubscription()
            }
            Task {
                await model.refreshDirectAccount()
                await DirectBalanceFlow.shared.refresh()
            }
        }
        .sheet(isPresented: $showDevices) {
            DirectDevicesView(model: model)
                .background(DS.paper.ignoresSafeArea())
                .tint(DS.ink)
                .modifier(DirectManagementSheetChrome())
        }
        .sheet(isPresented: $showPayments) {
            DirectPaymentHistoryView(model: model)
                .background(DS.paper.ignoresSafeArea())
                .tint(DS.ink)
                .modifier(DirectManagementSheetChrome())
        }
        .sheet(isPresented: $showSupport) {
            DirectSupportView()
                .background(DS.paper.ignoresSafeArea())
                .tint(DS.ink)
                .modifier(DirectManagementSheetChrome())
        }
    }

    // MARK: - Subscription

    private var planNameLabel: String {
        guard model.hasPremiumEntitlement else { return "БЕЗ ТАРИФА" }
        let name = model.activePlanDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "DIRECT PREMIUM" }
        let upper = name.uppercased()
        if upper.contains("DIRECT") { return upper }
        return "DIRECT \(upper)"
    }

    private var planSummaryLine: String {
        let traffic: String = {
            if model.hasPremiumEntitlement {
                return model.premiumTrafficDisplayLabel
                    .replacingOccurrences(of: "ГБ", with: "GB")
                    .replacingOccurrences(of: "гб", with: "GB")
            }
            return model.selectedPlan.trafficLabel
                .replacingOccurrences(of: "ГБ", with: "GB")
        }()
        let devices = model.hasPremiumEntitlement ? model.premiumDeviceLimit : model.selectedPlan.devices
        let devicesPart = String(format: "%02d УСТРОЙСТВ", max(1, min(devices, 99)))
        return "\(traffic) • \(devicesPart) • DIRECT VPN"
    }

    private var deviceCountLabel: String {
        let used = max(0, min(model.premiumDevicesUsed, 99))
        let limit = model.hasPremiumEntitlement ? model.premiumDeviceLimit : model.selectedPlan.devices
        return String(format: "%02d / %02d", used, max(1, min(limit, 99)))
    }

    private var subscriptionBlock: some View {
        let active = model.hasPremiumEntitlement && model.isPremiumAccessReady
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text("01 / ПОДПИСКА")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.acid)
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(active ? DS.acid : DS.muted)
                            .frame(width: 5, height: 5)
                        Text(active ? "АКТИВНА" : "НЕТ ТАРИФА")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(active ? DS.acid : DS.muted)
                    }
                }

                Text(planNameLabel)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 8)

                Text(planSummaryLine)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.top, 4)

                Rectangle()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 1)
                    .padding(.top, 10)
                    .padding(.bottom, 10)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ДО ОКОНЧАНИЯ")
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.42))
                        Text(remainingDaysLabel)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer(minLength: 10)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("ОКОНЧАНИЕ")
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.42))
                        Text(expirationText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.ink)

            Button { renew() } label: {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SUBSCRIPTION")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.ink.opacity(0.50))
                        Text(model.hasPremiumEntitlement ? "Продлить подписку" : "Выбрать тариф")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.ink)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DS.ink)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 44)
                .background(DS.acid)
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())
        }
    }

    // MARK: - Traffic

    private var trafficSection: some View {
        let meter = trafficMeter
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("ТРАФИК")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(DS.ink)
                Spacer()
                Text("LIVE USAGE")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(DS.muted)
            }

            VStack(alignment: .leading, spacing: 8) {
                if meter.unlimited {
                    Text("∞ БЕЗЛИМИТ")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DS.ink)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Self.formatGb(meter.used))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.ink)
                        Text("/ \(Self.formatGb(meter.limit))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.muted.opacity(0.55))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                    managementTrafficBar(used: meter.used, limit: meter.limit)

                    let pct = meter.limit > 0 ? Int(((meter.used / meter.limit) * 100).rounded()) : 0
                    let remaining = max(0, meter.limit - meter.used)
                    HStack {
                        Text("ИСПОЛЬЗОВАНО \(pct)%")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(DS.muted)
                        Spacer()
                        Text("ОСТАЛОСЬ \(Self.formatGb(remaining))")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DS.green)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .overlay(Rectangle().stroke(DS.ink, lineWidth: 1))
        }
    }

    private func managementTrafficBar(used: Double, limit: Double) -> some View {
        let fraction = limit > 0 ? min(1, max(0, used / limit)) : 0
        let fill = fraction <= 0 ? 0 : max(fraction, 0.035)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.08))
                Rectangle()
                    .fill(DS.green)
                    .frame(width: geo.size.width * CGFloat(fill))
            }
        }
        .frame(height: 4)
    }

    private static func formatGb(_ gb: Double) -> String {
        guard gb.isFinite, gb >= 0 else { return "—" }
        if gb < 0.05 { return "0 GB" }
        if abs(gb - gb.rounded()) < 0.05 {
            return "\(Int(gb.rounded())) GB"
        }
        return String(format: "%.1f GB", gb)
    }

    // MARK: - Resources

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("РЕСУРСЫ")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(DS.ink)
                Spacer()
                Text("DIRECT")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(DS.muted)
            }

            VStack(spacing: 0) {
                resourceRow(
                    badge: "DEV",
                    title: "Устройства",
                    subtitle: "АКТИВНЫЕ СЕАНСЫ • ЛИМИТ ТАРИФА",
                    trailing: deviceCountLabel
                ) { showDevices = true }

                Rectangle()
                    .fill(Color.black.opacity(0.10))
                    .frame(height: 1)

                resourceRow(
                    badge: "PAY",
                    title: "Платежи",
                    subtitle: "ИСТОРИЯ ОПЛАТ И ВОЗВРАТОВ",
                    trailing: nil
                ) { showPayments = true }
            }
            .background(Color.white)
            .overlay(Rectangle().stroke(DS.ink, lineWidth: 1))
        }
    }

    private func resourceRow(
        badge: String,
        title: String,
        subtitle: String,
        trailing: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.play(.selection)
            action()
        } label: {
            HStack(spacing: 10) {
                Text(badge)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .frame(width: 30, height: 30)
                    .background(DS.ink)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.ink)
                    Text(subtitle)
                        .font(.system(size: 8, weight: .medium))
                        .tracking(0.2)
                        .foregroundStyle(DS.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 6)

                if let trailing {
                    Text(trailing)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DS.ink)
                }
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.ink)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
    }

    // MARK: - PLAN / EXT / HELP

    private var planRow: some View {
        Button {
            HapticManager.shared.play(.navigation)
            model.openPremiumPlans(mode: .constructor)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text("PLAN")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.muted)
                    .frame(width: 36, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Собрать свой тариф")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.ink)
                    Text("НАСТРОИТЬ ЛИМИТЫ И РЕСУРСЫ")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(0.3)
                        .foregroundStyle(DS.muted)
                }

                Spacer(minLength: 6)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.ink)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
    }

    private var externalRow: some View {
        Button(action: openAddMenu) {
            HStack(alignment: .center, spacing: 12) {
                Text("EXT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.muted)
                    .frame(width: 36, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Добавить подписку")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.ink)
                    Text("ВНЕШНЯЯ VPN-ПОДПИСКА")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(0.3)
                        .foregroundStyle(DS.muted)
                }

                Spacer(minLength: 6)

                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.ink)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
    }

    private var helpBar: some View {
        Button {
            HapticManager.shared.play(.selection)
            showSupport = true
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text("HELP")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .frame(width: 36, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Нужна помощь?")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("ПОДДЕРЖКА VPN DIRECT")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(0.3)
                        .foregroundStyle(Color.white.opacity(0.42))
                }

                Spacer(minLength: 6)

                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.acid)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.ink)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
    }

    private func renew() {
        if model.hasPremiumEntitlement {
            Task { @MainActor in
                await model.beginRenewCheckout()
            }
        } else {
            model.openPremiumPlans(mode: .presets)
        }
    }
}

private struct DirectManagementSheetChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(0)
                .preferredColorScheme(.light)
        } else {
            content.preferredColorScheme(.light)
        }
    }
}

#endif
