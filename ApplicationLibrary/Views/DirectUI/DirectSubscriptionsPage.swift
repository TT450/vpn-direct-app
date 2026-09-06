import Library
import SwiftUI

#if os(iOS)

struct DirectSubscriptionsPage: View {
    @ObservedObject var model: VPNConnectionModel
    let openAddMenu: () -> Void

    private var imported: [VPNSubscriptionItem] { model.importedSubscriptions }

    private var activeImported: VPNSubscriptionItem? {
        guard case let .imported(id) = model.activeAccess else { return nil }
        return imported.first(where: { $0.id == id })
    }

    private var inactiveImported: [VPNSubscriptionItem] {
        imported.filter { !model.isSubscriptionActive($0.id) }
    }

    private var showFreeInCatalog: Bool { !model.isFreeAccessActive }
    private var showPremiumInCatalog: Bool {
        guard let id = model.premiumProfileID else { return true }
        return !model.isSubscriptionActive(id)
    }

    private var vpndirectCatalogCount: Int {
        (showFreeInCatalog ? 1 : 0) + (showPremiumInCatalog ? 1 : 0)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(
                    kicker: "ИСТОЧНИКИ / \(String(format: "%02d", max(model.subscriptions.count, 1)))",
                    title: "Подписки",
                    subtitle: "Выберите один для подключения"
                )

                Button(action: openAddMenu) {
                    HStack(spacing: 12) {
                        Text("＋").font(.system(size: 23, weight: .light)).foregroundStyle(DS.acid)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Добавить подписку").font(.system(size: 14, weight: .semibold))
                            Text("QR, буфер обмена или URL").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Text("03 СПОСОБА").microLabel(color: .white.opacity(0.45))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 76)
                    .background(DS.panel)
                    .foregroundStyle(.white)
                }
                .buttonStyle(HapticButtonStyle())
                .padding(.top, 28)

                SourceSectionHeader(title: "АКТИВНАЯ", count: 1)
                    .padding(.top, 22)
                activeSectionCard
                    .padding(.top, 10)

                if vpndirectCatalogCount > 0 {
                    SourceSectionHeader(title: "DIRECT ACCESS", count: vpndirectCatalogCount)
                        .padding(.top, 22)
                    if showFreeInCatalog {
                        FreeBalanceCard(model: model)
                            .padding(.top, 10)
                    }
                    if showPremiumInCatalog {
                        PremiumAccessCard(model: model)
                            .padding(.top, showFreeInCatalog ? 12 : 10)
                    }
                }

                if !inactiveImported.isEmpty {
                    SourceSectionHeader(title: "ДОБАВЛЕННЫЕ ИЗВНЕ", count: inactiveImported.count)
                        .padding(.top, 22)
                    ForEach(Array(inactiveImported.enumerated()), id: \.element.id) { index, subscription in
                        ExternalSubscriptionCard(model: model, subscription: subscription)
                            .padding(.top, index == 0 ? 10 : 12)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    @ViewBuilder
    private var activeSectionCard: some View {
        switch model.activeAccess {
        case .free:
            FreeBalanceCard(model: model)
        case .premium:
            PremiumAccessCard(model: model)
        case .imported:
            if let activeImported {
                ExternalSubscriptionCard(model: model, subscription: activeImported)
            } else {
                Text("Нет активной подписки")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            }
        }
    }
}

private struct SourceSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title).microLabel(color: DS.ink)
            Spacer()
            Text(String(format: "%02d", count)).microLabel(color: DS.green)
        }
        .frame(height: 36)
        .overlay(alignment: .top) { Hairline(color: DS.ink) }
    }
}

// MARK: - Direct Free

private struct FreeBalanceCard: View {
    @ObservedObject var model: VPNConnectionModel
    private var isActive: Bool { model.isFreeAccessActive }

    private var balanceLine: String {
        "\(model.freeRemainingDisplayText) · \(model.freeTrafficMB) МБ · 1 устройство"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("БЕСПЛАТНЫЙ БАЛАНС").microLabel(color: DS.muted)
                Spacer()
                Text(isActive ? "АКТИВНА" : "НА ПАУЗЕ")
                    .microLabel(color: isActive ? DS.green : DS.ink)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Hairline()

            HStack(spacing: 12) {
                Text("FREE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .frame(width: 52, height: 52)
                    .background(DS.ink)

                VStack(alignment: .leading, spacing: 4) {
                    Text("VPN Direct Free")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DS.ink)
                    Text(balanceLine)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.muted)
                }

                Spacer(minLength: 8)

                if isActive {
                    Text("СЕЙЧАС")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.green)
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .overlay(Rectangle().stroke(DS.green, lineWidth: 1))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            Hairline()

            HStack(spacing: 0) {
                Button {
                    model.detailPage = .freeAccess
                } label: {
                    Text("Получить ещё")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(HapticButtonStyle())

                Rectangle().fill(DS.line).frame(width: 1, height: 28)

                Button {
                    if !isActive { model.activateFreeAccess() }
                } label: {
                    Text(isActive ? "Подключено" : "Сделать активной")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isActive ? DS.green : DS.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(HapticButtonStyle())
                .disabled(isActive || model.isBusy)
            }
        }
        .background(isActive ? DS.acid.opacity(0.22) : Color.white.opacity(0.72))
        .overlay(alignment: .leading) {
            if isActive {
                Rectangle().fill(DS.green).frame(width: 4)
            }
        }
        .overlay(Rectangle().stroke(DS.line))
    }
}

// MARK: - Direct Premium

private struct PremiumAccessCard: View {
    @ObservedObject var model: VPNConnectionModel

    private var premiumID: Int64? { model.premiumProfileID }
    private var isActive: Bool {
        guard let premiumID else { return false }
        return model.isSubscriptionActive(premiumID)
    }

    private var statusLabel: String {
        if isActive { return "АКТИВНА" }
        return model.hasPremiumEntitlement ? "ЕСТЬ ТАРИФ" : "НЕТ ПОДПИСКИ"
    }

    private var detailLine: String {
        if model.hasPremiumEntitlement {
            return "\(model.premiumRemainingDays) дн · \(model.premiumTrafficGB) ГБ · \(model.premiumDevicesUsed)/\(model.premiumDeviceLimit)"
        }
        return "От 1 месяца · расширяемые лимиты"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ДОСТУП БЕЗ РЕКЛАМЫ").microLabel(color: DS.muted)
                Spacer()
                Text(statusLabel).microLabel(color: isActive ? DS.green : DS.ink)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Hairline()

            Button {
                if let premiumID, !isActive {
                    model.activate(subscriptionID: premiumID)
                } else {
                    model.detailPage = model.hasPremiumEntitlement ? .addOns : .premiumPlans
                }
            } label: {
                HStack(spacing: 12) {
                    Text("PLUS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.acid)
                        .frame(width: 52, height: 52)
                        .background(DS.ink)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("VPN Direct Premium")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DS.ink)
                        Text(detailLine)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.muted)
                    }

                    Spacer(minLength: 8)

                    if isActive {
                        Text("СЕЙЧАС")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.green)
                            .padding(.horizontal, 8)
                            .frame(height: 28)
                            .overlay(Rectangle().stroke(DS.green, lineWidth: 1))
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.ink)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())

            Hairline()

            HStack(spacing: 0) {
                Button {
                    model.detailPage = .premiumPlans
                } label: {
                    Text("Выбрать тариф")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(HapticButtonStyle())

                Rectangle().fill(DS.line).frame(width: 1, height: 28)

                Button {
                    model.detailPage = model.hasPremiumEntitlement ? .addOns : .premiumPlans
                } label: {
                    Text(isActive ? "Подключено" : "Управление")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isActive ? DS.green : DS.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(HapticButtonStyle())
            }
        }
        .background(isActive ? DS.acid.opacity(0.22) : Color.white.opacity(0.72))
        .overlay(alignment: .leading) {
            if isActive {
                Rectangle().fill(DS.green).frame(width: 4)
            }
        }
        .overlay(Rectangle().stroke(DS.line))
    }
}

// MARK: - External URL

private struct ExternalSubscriptionCard: View {
    @ObservedObject var model: VPNConnectionModel
    let subscription: VPNSubscriptionItem

    private var isActive: Bool { model.isSubscriptionActive(subscription.id) }

    private var detailLine: String {
        let meta = SubscriptionMetadataStore.load(profileID: subscription.id)
        let days = subscription.expiry
        let traffic = meta?.trafficQuotaLabel ?? "—"
        let unit = meta?.trafficQuotaUnit ?? ""
        let trafficPart = unit.isEmpty || traffic == "—" ? traffic : "\(traffic) \(unit)"
        let devices = subscription.devices
        return "\(days) · \(trafficPart) · \(devices)"
            .replacingOccurrences(of: " · —", with: "")
    }

    var body: some View {
        Group {
            if isActive {
                activeCard
            } else {
                inactiveCard
            }
        }
    }

    private var inactiveCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ВНЕШНЯЯ ПОДПИСКА").microLabel(color: DS.muted)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Hairline()

            Button {
                model.activate(subscriptionID: subscription.id)
            } label: {
                HStack(spacing: 12) {
                    Text("URL")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.acid)
                        .frame(width: 52, height: 52)
                        .background(DS.ink)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscription.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DS.ink)
                            .lineLimit(1)
                        Text(detailLine)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.muted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.ink)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())
            .disabled(model.isBusy)

            Hairline()

            HStack(spacing: 0) {
                Button {
                    model.openDetail(.subscription(subscription.id))
                } label: {
                    Text("Подробнее")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(HapticButtonStyle())

                Rectangle().fill(DS.line).frame(width: 1, height: 28)

                Button {
                    model.activate(subscriptionID: subscription.id)
                } label: {
                    Text("Сделать активной")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.green)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(HapticButtonStyle())
                .disabled(model.isBusy)
            }
        }
        .background(Color.white.opacity(0.72))
        .overlay(Rectangle().stroke(DS.line))
    }

    private var activeCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ВНЕШНЯЯ ПОДПИСКА").microLabel(color: .white.opacity(0.45))
                Spacer()
                Text("АКТИВНА").microLabel(color: DS.acid)
            }

            HStack(spacing: 12) {
                Text("URL")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .frame(width: 52, height: 52)
                    .overlay(Rectangle().stroke(Color.white.opacity(0.22)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(subscription.name)
                        .font(.system(size: 17, weight: .semibold))
                    Text(detailLine)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text("СЕЙЧАС")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .overlay(Rectangle().stroke(DS.acid.opacity(0.7), lineWidth: 1))
            }
            .padding(.top, 16)

            HStack(spacing: 0) {
                Button {
                    model.openDetail(.subscription(subscription.id))
                } label: {
                    Text("Подробнее")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(HapticButtonStyle())

                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 28)

                Text("Подключено")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.acid)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .foregroundStyle(DS.acid)
            .padding(.top, 8)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .background(DS.ink)
        .foregroundStyle(.white)
        .overlay(Rectangle().stroke(DS.acid.opacity(0.72), lineWidth: 1))
    }
}

#endif
