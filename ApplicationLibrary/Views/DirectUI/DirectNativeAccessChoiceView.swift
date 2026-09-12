import SwiftUI

#if os(iOS)

/// Subscription chooser shown when the Home screen needs an active access source.
/// VPN Direct's built-in access is always presented first and visually separated from imported subscriptions.
struct DirectNativeAccessChoiceView: View {
    @ObservedObject var model: VPNConnectionModel

    private var imported: [VPNSubscriptionItem] { model.importedSubscriptions }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    model.detailPage = nil
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                        Text("Главная")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.muted)
                }
                .buttonStyle(HapticButtonStyle())

                PageHeading(
                    kicker: "ПОДКЛЮЧЕНИЕ / ПОДПИСКИ",
                    title: "Выберите подписку",
                    subtitle: "Сначала доступ VPN Direct, ниже — добавленные вами подписки"
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

                nativeSection
                    .padding(.top, 24)

                if !imported.isEmpty {
                    AccessChooserSectionHeader(title: "ДОБАВЛЕННЫЕ ПОДПИСКИ", count: imported.count)
                        .padding(.top, 24)

                    ForEach(Array(imported.enumerated()), id: \.element.id) { index, subscription in
                        ImportedChoiceRow(model: model, subscription: subscription)
                            .padding(.top, index == 0 ? 0 : 1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(DS.paper)
    }

    private var nativeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("VPN DIRECT").microLabel(color: DS.acid)
                    Text("Родная подписка").font(.system(size: 20, weight: .semibold))
                    Text("Встроена в приложение · без стороннего провайдера")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.52))
                }
                Spacer(minLength: 10)
                Text("ОСНОВНАЯ")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .padding(.horizontal, 8)
                    .frame(height: 27)
                    .overlay(Rectangle().stroke(DS.acid.opacity(0.72)))
            }
            .padding(16)

            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)

            NativeAccessRow(
                mark: "FREE",
                title: "VPN Direct Free",
                subtitle: model.isFreeAccessReady
                    ? "\(model.freeRemainingDisplayText) · \(model.freeTrafficMB) МБ"
                    : "3 рекламы → 1 час и 200 МБ",
                isActive: model.activeAccess == .free
            ) {
                model.clearAccessChoiceContext()
                model.handleAccessChoiceFree()
            }

            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)

            NativeAccessRow(
                mark: "PLUS",
                title: "VPN Direct Premium",
                subtitle: model.isPremiumAccessReady
                    ? "\(model.premiumRemainingDays) дн · \(model.premiumTrafficGB) ГБ · \(model.premiumDevicesUsed)/\(model.premiumDeviceLimit)"
                    : "Без рекламы · от 1 месяца",
                isActive: model.activeAccess == .premium
            ) {
                model.clearAccessChoiceContext()
                model.handleAccessChoicePremium()
            }
        }
        .foregroundStyle(.white)
        .background(DS.ink)
        .overlay(Rectangle().stroke(DS.acid.opacity(0.72), lineWidth: 1))
    }
}

private struct AccessChooserSectionHeader: View {
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

private struct NativeAccessRow: View {
    let mark: String
    let title: String
    let subtitle: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(mark)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.ink)
                    .frame(width: 48, height: 42)
                    .background(DS.acid)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(title).font(.system(size: 13, weight: .semibold))
                        if isActive {
                            Text("АКТИВНА").microLabel(color: DS.acid)
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                Image(systemName: isActive ? "checkmark" : "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.acid)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .background(isActive ? Color.white.opacity(0.07) : Color.clear)
    }
}

private struct ImportedChoiceRow: View {
    @ObservedObject var model: VPNConnectionModel
    let subscription: VPNSubscriptionItem

    private var isActive: Bool { model.isSubscriptionActive(subscription.id) }

    var body: some View {
        Button {
            model.clearAccessChoiceContext()
            model.handleImportedProfileActivated(subscriptionID: subscription.id)
        } label: {
            HStack(spacing: 12) {
                Text("URL")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(isActive ? DS.acid : DS.ink)
                    .frame(width: 48, height: 42)
                    .background(isActive ? DS.ink : Color.white.opacity(0.72))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(subscription.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.ink)
                            .lineLimit(1)
                        if isActive {
                            Text("АКТИВНА").microLabel(color: DS.green)
                        }
                    }
                    Text("Внешний провайдер · \(subscription.expiry)")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                Image(systemName: isActive ? "checkmark" : "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isActive ? DS.green : DS.muted)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .background(isActive ? DS.acid.opacity(0.16) : Color.white.opacity(0.72))
        .overlay(Rectangle().stroke(isActive ? DS.green : DS.line))
    }
}

#endif
