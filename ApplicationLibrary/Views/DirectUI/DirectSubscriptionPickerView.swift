import Library
import SwiftUI

#if os(iOS)

/// Home sheet when no profile is selected — pick an installed subscription (Direct or imported).
struct DirectSubscriptionPickerView: View {
    @ObservedObject var model: VPNConnectionModel
    @Environment(\.dismiss) private var dismiss

    private var items: [VPNSubscriptionItem] { model.selectableSubscriptions }

    var body: some View {
        VStack(spacing: 0) {
            header

            if items.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            subscriptionRow(item, index: index)
                            if index < items.count - 1 {
                                Hairline()
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
                    Text("ACCOUNT / SUBSCRIPTIONS").microLabel()
                }

                Text("Подписки")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Выберите источник для подключения")
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

    private func subscriptionRow(_ item: VPNSubscriptionItem, index: Int) -> some View {
        let isActive = item.id == model.activeSubscriptionID
        let isDirect = DirectBuiltinProfile.isDirectOwned(item.profile.remoteURL)

        return Button {
            model.pickSubscriptionFromSheet(item.id)
        } label: {
            HStack(spacing: 12) {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .frame(width: 42, height: 42)
                    .background(DS.ink)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isDirect ? "VPN DIRECT" : "ВНЕШНЯЯ")
                        .microLabel(color: DS.muted)
                    Text(item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.ink)
                        .lineLimit(1)
                    Text(detailLine(for: item, isDirect: isDirect))
                        .font(.system(size: 10))
                        .foregroundStyle(DS.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if isActive {
                    Text("АКТИВНА")
                        .microLabel(color: DS.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.muted)
                }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
    }

    private func detailLine(for item: VPNSubscriptionItem, isDirect: Bool) -> String {
        if isDirect {
            return model.accessStripDetail
        }
        let servers = item.servers.count
        let expiry = item.expiry
        if servers > 0, !expiry.isEmpty, expiry != "—" {
            return "\(servers) лок. · \(expiry)"
        }
        if servers > 0 {
            return "\(servers) локаций"
        }
        return item.updated
    }
}

#endif
