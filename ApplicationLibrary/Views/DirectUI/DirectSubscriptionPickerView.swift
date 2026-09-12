import Library
import SwiftUI

#if os(iOS)

/// Home sheet when no profile is selected — pick an installed subscription (Direct or imported).
struct DirectSubscriptionPickerView: View {
    @ObservedObject var model: VPNConnectionModel
    @Environment(\.dismiss) private var dismiss

    private var imported: [VPNSubscriptionItem] {
        model.importedSubscriptions
    }

    private var hasDirectBlock: Bool {
        model.hasNativeDirectSubscription || model.preferredNativeDirectSubscription != nil
    }

    private var isDirectActive: Bool {
        model.isNativeDirectSubscriptionActive
    }

    private var directDetail: String {
        if let live = model.preferredNativeDirectSubscription {
            let servers = live.servers.count
            if model.hasPremiumEntitlement {
                let traffic = model.premiumTrafficDisplayLabel
                let days = model.premiumRemainingDays
                if servers > 0 {
                    return "\(days) дн · \(traffic) · \(servers) лок."
                }
                return "\(days) дн · \(traffic) · \(model.premiumDevicesUsed)/\(model.premiumDeviceLimit)"
            }
            if servers > 0 {
                return "\(servers) локаций · \(live.expiry)"
            }
            return live.updated
        }
        if model.hasPremiumEntitlement {
            return "\(model.premiumRemainingDays) дн · \(model.premiumTrafficDisplayLabel) · \(model.premiumDevicesUsed)/\(model.premiumDeviceLimit)"
        }
        return "Тариф VPN Direct на аккаунте"
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if !hasDirectBlock, imported.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if hasDirectBlock {
                            nativeDirectBlock
                                .padding(.top, 18)
                        }

                        if !imported.isEmpty {
                            HStack {
                                Text("ДОБАВЛЕННЫЕ ПОДПИСКИ").microLabel(color: DS.ink)
                                Spacer()
                                Text(String(format: "%02d", imported.count)).microLabel(color: DS.green)
                            }
                            .frame(height: 36)
                            .overlay(alignment: .top) { Hairline(color: DS.ink) }
                            .padding(.top, hasDirectBlock ? 22 : 18)

                            ForEach(Array(imported.enumerated()), id: \.element.id) { index, subscription in
                                importedRow(subscription)
                                    .padding(.top, index == 0 ? 0 : 1)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(DS.paper.ignoresSafeArea())
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text("01").microLabel(color: DS.green)
                    Rectangle()
                        .fill(DS.acid)
                        .frame(width: 14, height: 2)
                    Text("ПОДКЛЮЧЕНИЕ / ПОДПИСКИ").microLabel()
                }

                Text("Подписки")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("VPN Direct — первым, добавленные — ниже")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(DS.ink)
                    .foregroundStyle(DS.acid)
            }
            .buttonStyle(HapticButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 15)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Нет доступных подписок")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.ink)
            Text("Оформите тариф VPN Direct или добавьте внешнюю подписку во вкладке Управление.")
                .font(.system(size: 12))
                .foregroundStyle(DS.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                dismiss()
                model.select(tab: .management)
            } label: {
                HStack {
                    Text("ОТКРЫТЬ УПРАВЛЕНИЕ")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.acid)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(DS.ink)
            }
            .buttonStyle(HapticButtonStyle())
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Firm black Direct block — single native access, no Free/Premium split.
    private var nativeDirectBlock: some View {
        Button {
            activateNativeDirect()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VPN DIRECT · ОСНОВНАЯ")
                            .microLabel(color: DS.acid)
                        Text("VPN Direct")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(directDetail)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.52))
                            .lineLimit(2)
                    }

                    Spacer(minLength: 10)

                    VStack(alignment: .trailing, spacing: 8) {
                        Text("ОСНОВНАЯ")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.acid)
                            .padding(.horizontal, 8)
                            .frame(height: 27)
                            .overlay(Rectangle().stroke(DS.acid.opacity(0.72)))

                        if isDirectActive {
                            HStack(spacing: 5) {
                                Text("АКТИВНА").microLabel(color: DS.acid)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(DS.acid)
                            }
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(DS.acid)
                        }
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.ink)
            .overlay {
                if isDirectActive {
                    Color.white.opacity(0.06)
                }
            }
            .overlay(Rectangle().stroke(DS.acid.opacity(0.72), lineWidth: 1))
        }
        .buttonStyle(HapticButtonStyle())
    }

    private func importedRow(_ subscription: VPNSubscriptionItem) -> some View {
        let isActive = model.isSubscriptionActive(subscription.id)

        return Button {
            model.pickSubscriptionFromSheet(subscription.id)
            dismiss()
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
                    Text(importedDetail(subscription))
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

    private func importedDetail(_ subscription: VPNSubscriptionItem) -> String {
        let servers = subscription.servers.count
        let expiry = subscription.expiry
        if servers > 0, !expiry.isEmpty, expiry != "—" {
            return "Внешний провайдер · \(servers) лок. · \(expiry)"
        }
        if servers > 0 {
            return "Внешний провайдер · \(servers) локаций"
        }
        if !expiry.isEmpty, expiry != "—" {
            return "Внешний провайдер · \(expiry)"
        }
        return "Внешний провайдер · \(subscription.updated)"
    }

    private func activateNativeDirect() {
        if let live = model.preferredNativeDirectSubscription {
            model.pickSubscriptionFromSheet(live.id)
        } else {
            model.useNativeDirectSubscription()
        }
        dismiss()
    }
}

#endif
