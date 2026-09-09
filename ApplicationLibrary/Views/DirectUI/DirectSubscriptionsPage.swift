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

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    PageHeading(
                        kicker: "ИСТОЧНИКИ / \(String(format: "%02d", max(model.subscriptions.count, 1)))",
                        title: "Подписки",
                        subtitle: "VPN Direct — основной доступ; внешние — по желанию"
                    )

                    Button(action: openAddMenu) {
                        HStack(spacing: 12) {
                            Text("＋").font(.system(size: 23, weight: .light)).foregroundStyle(DS.acid)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Добавить внешнюю подписку").font(.system(size: 14, weight: .semibold))
                                    .lineLimit(1)
                                Text("QR, буфер, ссылка, файл или конфиг").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text("05 СПОСОБОВ")
                                .microLabel(color: .white.opacity(0.45))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
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

                    SourceSectionHeader(title: "VPN DIRECT", count: 1)
                        .padding(.top, 22)
                    if model.activeAccess != .premium {
                        PremiumAccessCard(model: model)
                            .padding(.top, 10)
                    } else {
                        Text("Тариф Direct уже активен выше. Можно сменить пакет или докупить ресурсы.")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.muted)
                            .padding(.top, 10)
                        HStack(spacing: 8) {
                            Button {
                                model.openDetail(.premiumPlans)
                            } label: {
                                Text("Сменить тариф")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(DS.ink)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .overlay(Rectangle().stroke(DS.line))
                            }
                            .buttonStyle(HapticButtonStyle())
                            Button {
                                model.openDetail(.addOns)
                            } label: {
                                Text("Управление")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(DS.acid)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(DS.ink)
                            }
                            .buttonStyle(HapticButtonStyle())
                        }
                        .padding(.top, 10)
                    }

                    SourceSectionHeader(title: "ДРУГИЕ ПРОВАЙДЕРЫ", count: max(inactiveImported.count, 0))
                        .padding(.top, 22)
                    if inactiveImported.isEmpty {
                        Text("Пока нет внешних подписок. Добавьте URL или файл, если нужен другой провайдер.")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.muted)
                            .padding(.top, 10)
                    } else {
                        ForEach(Array(inactiveImported.enumerated()), id: \.element.id) { index, subscription in
                            ExternalSubscriptionCard(model: model, subscription: subscription)
                                .padding(.top, index == 0 ? 10 : 12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DS.pageTop)
                .frame(width: geo.size.width, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private var activeSectionCard: some View {
        switch model.activeAccess {
        case .free:
            DirectNeedsPlanCard(model: model)
        case .premium:
            PremiumAccessCard(model: model)
        case .imported:
            if let activeImported {
                ExternalSubscriptionCard(model: model, subscription: activeImported)
            } else {
                DirectNeedsPlanCard(model: model)
            }
        }
    }
}

private struct DirectNeedsPlanCard: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("НЕТ АКТИВНОГО DIRECT").microLabel(color: DS.muted)
            Text("Выберите тариф VPN Direct")
                .font(.system(size: 17, weight: .semibold))
            Text("Пресеты Start–Ultra или конструктор под ваши лимиты.")
                .font(.system(size: 12))
                .foregroundStyle(DS.muted)
            Button {
                model.openDetail(.premiumPlans)
            } label: {
                HStack {
                    Text("Открыть тарифы")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.acid)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(DS.ink)
            }
            .buttonStyle(HapticButtonStyle())
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.72))
        .overlay(Rectangle().stroke(DS.line))
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
            let wl = model.premiumWhitelistGB > 0 ? " · \(model.premiumWhitelistGB) GB WL" : ""
            return "\(model.premiumRemainingDays) дн · \(model.premiumTrafficDisplayLabel) · \(model.premiumDevicesUsed)/\(model.premiumDeviceLimit)\(wl)"
        }
        return "Пресеты и конструктор · Plus рекомендуем"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("VPN DIRECT").microLabel(color: DS.muted)
                Spacer()
                Text(statusLabel).microLabel(color: isActive ? DS.green : DS.ink)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Hairline()

            Button {
                if let premiumID, !isActive, model.hasPremiumEntitlement {
                    model.activate(subscriptionID: premiumID)
                } else {
                    model.openDetail(model.hasPremiumEntitlement ? .addOns : .premiumPlans)
                }
            } label: {
                HStack(spacing: 12) {
                    Text("PLUS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.acid)
                        .frame(width: 52, height: 52)
                        .background(DS.ink)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("VPN Direct")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DS.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(detailLine)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.muted)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())

            Hairline()

            HStack(spacing: 0) {
                Button {
                    model.openDetail(.premiumPlans)
                } label: {
                    Text("Выбрать тариф")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(HapticButtonStyle())

                Rectangle().fill(DS.line).frame(width: 1, height: 28)

                Button {
                    model.openDetail(model.hasPremiumEntitlement ? .addOns : .premiumPlans)
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
    @State private var showDeleteConfirm = false

    private var isActive: Bool { model.isSubscriptionActive(subscription.id) }

    private var meta: SubscriptionMetadata {
        SubscriptionMetadataStore.load(profileID: subscription.id) ?? SubscriptionMetadata()
    }

    private var detailLine: String {
        var parts: [String] = []
        let expiry = subscription.expiry
        if !expiry.isEmpty, expiry != "—" { parts.append(expiry) }
        let traffic = meta.trafficQuotaFullLabel.trimmingCharacters(in: .whitespaces)
        if !traffic.isEmpty, traffic != "— —", !traffic.hasPrefix("—") {
            parts.append(traffic)
        } else if meta.totalBytes == nil, (meta.uploadBytes ?? 0) + (meta.downloadBytes ?? 0) > 0 {
            parts.append(meta.trafficQuotaLabel)
        }
        let devices = subscription.devices
        if !devices.isEmpty, devices != "—" { parts.append(devices) }
        let locations = subscription.servers.count
        if locations > 0 { parts.append("\(locations) лок.") }
        if let panel = meta.compatibilityProfileID, panel != "generic", !panel.isEmpty {
            parts.append(panel.uppercased())
        }
        return parts.isEmpty ? "Нет данных панели · обновите подписку" : parts.joined(separator: " · ")
    }

    var body: some View {
        Group {
            if isActive {
                activeCard
            } else {
                inactiveCard
            }
        }
        .alert("Удалить подписку?", isPresented: $showDeleteConfirm) {
            Button("Удалить", role: .destructive) {
                model.deleteSubscription(subscriptionID: subscription.id)
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Конфигурация будет полностью удалена с устройства.")
        }
    }

    private var inactiveCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ВНЕШНЯЯ ПОДПИСКА").microLabel(color: DS.muted)
                Spacer()
                Text("\(subscription.servers.count) СЕРВ.").microLabel(color: DS.muted)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Hairline()

            Button {
                model.openDetail(.subscription(subscription.id))
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
                            .minimumScaleFactor(0.85)
                        Text(detailLine)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.muted)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(subscription.updated)
                            .font(.system(size: 10))
                            .foregroundStyle(DS.muted.opacity(0.85))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.ink)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())

            Hairline()

            HStack(spacing: 0) {
                Button {
                    model.activate(subscriptionID: subscription.id)
                } label: {
                    Text("Активировать")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(HapticButtonStyle())
                .disabled(model.isBusy)

                Rectangle().fill(DS.line).frame(width: 1, height: 28)

                Button {
                    model.refreshSubscription(subscriptionID: subscription.id)
                } label: {
                    Text("Обновить")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(HapticButtonStyle())
                .disabled(model.isBusy || subscription.profile.type != .remote)

                Rectangle().fill(DS.line).frame(width: 1, height: 28)

                Button {
                    showDeleteConfirm = true
                } label: {
                    Text("Удалить")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.danger)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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

            Button {
                model.openDetail(.subscription(subscription.id))
            } label: {
                HStack(spacing: 12) {
                    Text("URL")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.acid)
                        .frame(width: 52, height: 52)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.22)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscription.name)
                            .font(.system(size: 17, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(detailLine)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(subscription.updated)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("СЕЙЧАС")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.acid)
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .overlay(Rectangle().stroke(DS.acid.opacity(0.7), lineWidth: 1))
                }
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())

            HStack(spacing: 0) {
                Button {
                    model.refreshSubscription(subscriptionID: subscription.id)
                } label: {
                    Text("Обновить")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(HapticButtonStyle())
                .disabled(model.isBusy || subscription.profile.type != .remote)

                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 28)

                Button {
                    showDeleteConfirm = true
                } label: {
                    Text("Удалить")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(HapticButtonStyle())
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
