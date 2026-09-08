import SwiftUI

#if os(iOS)

private enum HomeBottomBar {
    /// Shared height for server row, subscription actions, and metrics.
    static let rowHeight: CGFloat = 56
    /// Shared leading/trailing inset for inner content of all three bottom rows.
    static let inset: CGFloat = 16
    /// Fixed width of the 01/02/03 index column.
    static let indexWidth: CGFloat = 18
    /// Gap between index and the following content (match row 02).
    static let indexSpacing: CGFloat = 10
}

struct DirectHomePage: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        VStack(spacing: 0) {
            Button {
                model.activeSheet = .connectionReport
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    Text("КЛИЕНТ / VPN").microLabel()
                        .lineLimit(1)
                    HStack(spacing: 9) {
                        Text(model.statusTitle)
                            .font(.system(size: 22, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .allowsTightening(true)
                            .layoutPriority(1)
                        Circle()
                            .fill(statusDotColor)
                            .frame(width: 8, height: 8)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13))
                            .foregroundStyle(model.isProtected ? DS.green : DS.muted)
                    }
                    Text(model.statusSubtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 24)

            Button {
                model.activeSheet = .profiles
            } label: {
                HStack {
                    Text("РЕЖИМ ПОДКЛЮЧЕНИЯ").microLabel()
                    Text(model.connectionMode).font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("Сменить · →").microLabel(color: DS.green)
                }
                .padding(.horizontal, 11)
                .frame(height: 38)
                .background(Color.white.opacity(0.28))
                .overlay(Rectangle().stroke(DS.line))
            }
            .buttonStyle(HapticButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 28)

            Spacer(minLength: 4)

            DialView(isConnected: model.dialIsConnected, isBusy: model.isBusy) {
                model.toggleConnection()
            }

            Spacer(minLength: 4)

            Button {
                model.activeSheet = .serverPicker
            } label: {
                HStack(spacing: HomeBottomBar.indexSpacing) {
                    Text("01")
                        .microLabel()
                        .frame(width: HomeBottomBar.indexWidth, alignment: .leading)
                    Group {
                        if model.usesAutoSelection {
                            Text("A")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .frame(width: 24, height: 24)
                                .background(DS.ink)
                                .foregroundStyle(DS.acid)
                        } else if let server = model.activeServer {
                            FlagImage(code: server.countryCode, width: 24, height: 16)
                        } else {
                            Text("A")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .frame(width: 24, height: 24)
                                .background(DS.ink)
                                .foregroundStyle(DS.acid)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.usesAutoSelection
                            ? "АВТОВЫБОР · \((model.activeSubscription?.name ?? "").uppercased())"
                            : (model.activeSubscription?.name ?? "").uppercased())
                            .lineLimit(1)
                            .microLabel()
                        Text(serverSubtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)
                    HStack(spacing: 5) {
                        Circle().fill(model.isProtected ? DS.green : DS.muted).frame(width: 5, height: 5)
                        Text(model.activeServer?.pingLabel ?? "— MS").microLabel(color: DS.ink)
                    }
                    Image(systemName: "arrow.up.right").font(.system(size: 12))
                }
                .padding(.horizontal, HomeBottomBar.inset)
                .frame(maxWidth: .infinity)
                .frame(height: HomeBottomBar.rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())
            .overlay(alignment: .top) { Hairline() }
            .overlay(alignment: .bottom) { Hairline() }

            HomeSubscriptionActions(model: model)

            HStack(spacing: HomeBottomBar.indexSpacing) {
                Text("03")
                    .microLabel()
                    .frame(width: HomeBottomBar.indexWidth, alignment: .leading)
                HStack(spacing: 0) {
                    MetricCell(label: "ТРАФИК СЕГОДНЯ", value: model.trafficText, unit: model.trafficUnit, compact: true)
                        .frame(maxWidth: .infinity)
                    Hairline().frame(width: 1, height: HomeBottomBar.rowHeight - 16)
                    MetricCell(label: "ВРЕМЯ В СЕТИ", value: model.isProtected ? model.runtimeText : "00:00:00", unit: "", compact: true)
                        .frame(maxWidth: .infinity)
                    Hairline().frame(width: 1, height: HomeBottomBar.rowHeight - 16)
                    MetricCell(
                        label: "ИСПОЛЬЗОВАНО",
                        value: model.subscriptionTrafficText,
                        unit: model.subscriptionTrafficUnit,
                        compact: true
                    )
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.leading, HomeBottomBar.inset)
            .padding(.trailing, HomeBottomBar.inset)
            .frame(maxWidth: .infinity)
            .frame(height: HomeBottomBar.rowHeight)
            .overlay(alignment: .top) { Hairline() }
        }
    }

    private var statusDotColor: Color {
        switch model.phase {
        case .connecting: Color.orange
        case .disconnecting: Color.orange.opacity(0.85)
        case .switching: DS.acid
        case .idle: model.isProtected ? DS.green : DS.danger
        }
    }

    private var serverSubtitle: String {
        guard let server = model.activeServer else { return "Нет серверов" }
        if model.usesAutoSelection {
            return "Сейчас: \(server.locationLabel)"
        }
        return server.locationLabel
    }
}

/// VPN-page actions: soft-remove, update, change subscription, change server.
private struct HomeSubscriptionActions: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var showSoftRemoveConfirm = false

    private var canSoftRemove: Bool {
        guard let sub = model.activeSubscription else { return false }
        return !DirectBuiltinProfile.isBuiltin(sub.profile.remoteURL)
    }

    private var canUpdate: Bool {
        guard let sub = model.activeSubscription else { return false }
        if DirectBuiltinProfile.isBuiltin(sub.profile.remoteURL) { return false }
        let remote = sub.profile.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return sub.profile.type == .remote && !remote.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: HomeBottomBar.indexSpacing) {
                Text("02")
                    .microLabel(color: DS.ink)
                    .frame(width: HomeBottomBar.indexWidth, alignment: .leading)
                HStack(spacing: 2) {
                    actionButton(title: "Сменить", subtitle: "сервер", enabled: !(model.activeSubscription?.servers.isEmpty ?? true)) {
                        model.openChangeServer()
                    }
                    actionButton(
                        title: model.isRefreshingSubscription ? "…" : "Обновить",
                        subtitle: "подписку",
                        enabled: canUpdate && !model.isRefreshingSubscription
                    ) {
                        model.refreshActiveSubscription()
                    }
                    actionButton(title: "Сменить", subtitle: "подписку", enabled: true) {
                        model.openChangeSubscription()
                    }
                    actionButton(title: "Убрать", subtitle: "из клиента", enabled: canSoftRemove) {
                        showSoftRemoveConfirm = true
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.leading, HomeBottomBar.inset)
            .padding(.trailing, HomeBottomBar.inset)
            .frame(maxWidth: .infinity)
            .frame(height: HomeBottomBar.rowHeight)
            .overlay(alignment: .bottom) { Hairline() }
        }
        .alert("Убрать подписку из клиента?", isPresented: $showSoftRemoveConfirm) {
            Button("Убрать", role: .destructive) {
                model.removeImportedFromClient()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Подписка останется в списке внешних. Активным станет Free / Premium или другая.")
        }
    }

    private func actionButton(title: String, subtitle: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(enabled ? Color.white : Color.white.opacity(0.35))
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(enabled ? Color.white.opacity(0.55) : Color.white.opacity(0.28))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background(DS.ink)
        }
        .buttonStyle(HapticButtonStyle())
        .disabled(!enabled)
    }
}

private struct MetricCell: View {
    let label: String
    let value: String
    let unit: String
    var compact = false

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label).microLabel()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: compact ? 13 : 17, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unit.isEmpty {
                    Text(unit).microLabel()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
    }
}

#endif
