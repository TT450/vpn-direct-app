import SwiftUI
import Library

#if os(iOS)

/// Management — Direct subscription first; renew primary; no scroll chrome.
struct DirectManagementPage: View {
    @ObservedObject var model: VPNConnectionModel
    let openAddMenu: () -> Void

    @State private var showDevices = false
    @State private var showPayments = false

    /// Subscription-wide pool from `/me` limit + live used (subscription-userinfo / remaining).
    /// Never sum limited-location caps — those are per-squad soft caps.
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

    /// Prefer live used from /me (Remna period total), then subscription-userinfo,
    /// then sum of limited-location used (lower bound), then grant math.
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
        if locationUsed > 0 {
            return min(locationUsed, limit)
        }

        if let remaining = model.premiumTrafficRemainingGB {
            return max(0, limit - Double(max(0, remaining)))
        }
        return Double(model.premiumTrafficUsedGB)
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
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                subscriptionCard
                primaryActions
            }
            .padding(.bottom, 12)

            // Equal-height action cards fill the rest of the page (subscription block stays intrinsic).
            VStack(spacing: 10) {
                usageSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                devicesCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                paymentsCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                constructorButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                addSubscriptionButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, DS.pageTop)
        .padding(.bottom, 16)
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
    }

    private var planNameLabel: String {
        guard model.hasPremiumEntitlement else { return "БЕЗ ТАРИФА" }
        let name = model.activePlanDisplayName
        return name.isEmpty ? "DIRECT" : name.uppercased()
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

    private var deviceCountLabel: String {
        let used = max(1, min(model.premiumDevicesUsed, 99))
        let limit = model.hasPremiumEntitlement ? model.premiumDeviceLimit : model.selectedPlan.devices
        return String(format: "%02d / %02d", used, max(1, min(limit, 99)))
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
        let meter = trafficMeter
        return VStack(alignment: .leading, spacing: 4) {
            Text("Израсходовано трафика")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black)

            if meter.unlimited {
                Text("Без лимита")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.black)
                Spacer(minLength: 0)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(VPNConnectionModel.formatTrafficUsedGb(meter.used, cap: meter.limit))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.black)
                    Text("/")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.black)
                    Text(VPNConnectionModel.formatTrafficCapGb(meter.limit))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.black)
                }

                Spacer(minLength: 8)

                usageProgressBar(used: meter.used, limit: meter.limit)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(DS.acid)
        .overlay(Rectangle().stroke(DS.ink, lineWidth: 1.5))
    }

    private func usageProgressBar(used: Double, limit: Double) -> some View {
        let fraction = limit > 0 ? min(1, max(0, used / limit)) : 0
        let fillFraction = fraction <= 0 ? 0 : max(fraction, 0.04)
        return GeometryReader { geo in
            let fillW = geo.size.width * CGFloat(fillFraction)
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.12))
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.78))
                    .frame(width: fillW)
            }
        }
        .frame(height: 6)
        .clipShape(Capsule(style: .continuous))
        .accessibilityLabel("Использовано трафика")
        .accessibilityValue("\(Int((fraction * 100).rounded())) процентов")
    }

    private var devicesCard: some View {
        Button {
            HapticManager.shared.play(.selection)
            showDevices = true
        } label: {
            HStack(spacing: 12) {
                Text("DEV")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .frame(width: 42, height: 42)
                    .background(DS.ink)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Устройства")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.ink)
                    Text("Активные сеансы и лимит тарифа")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.muted)
                }
                Spacer(minLength: 8)
                Text(deviceCountLabel)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.ink)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.ink)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(DS.paper)
            .overlay(Rectangle().stroke(DS.ink, lineWidth: 1.5))
        }
        .buttonStyle(HapticButtonStyle())
    }

    private var paymentsCard: some View {
        Button {
            HapticManager.shared.play(.selection)
            showPayments = true
        } label: {
            HStack(spacing: 12) {
                Text("PAY")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .frame(width: 42, height: 42)
                    .background(DS.ink)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Платежи")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.ink)
                    Text("История оплат и возвратов")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.muted)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.ink)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(DS.paper)
            .overlay(Rectangle().stroke(DS.ink, lineWidth: 1.5))
        }
        .buttonStyle(HapticButtonStyle())
    }

    private var constructorButton: some View {
        Button {
            HapticManager.shared.play(.navigation)
            model.openPremiumPlans(mode: .constructor)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("НЕ НАШЛИ ПОДХОДЯЩИЙ?").microLabel(color: DS.paper.opacity(0.55))
                    Text("Собрать свой тариф")
                        .font(.system(size: 13, weight: .semibold))
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(DS.paper)
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(DS.ink)
        }
        .buttonStyle(HapticButtonStyle())
    }

    private var addSubscriptionButton: some View {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(DS.ink)
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
