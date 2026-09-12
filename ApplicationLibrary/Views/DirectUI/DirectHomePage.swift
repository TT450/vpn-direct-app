import SwiftUI

#if os(iOS)

struct DirectHomePage: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var showRemoveImportedConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            Text("DIRECT / VPN")
                .microLabel()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, DS.pageTop)
                .padding(.bottom, 7)

            header
                .padding(.horizontal, 20)

            Spacer(minLength: 0)

            // Keep the connection dial completely unchanged.
            DialView(isConnected: model.dialIsConnected, isBusy: model.isBusy) {
                model.toggleConnection()
            }

            Spacer(minLength: 0)

            serverRow
            if showsExternalSubscriptionControls {
                controlsRow
            }
            telemetryRow
        }
        .background(DS.paper.ignoresSafeArea())
        .alert("Убрать подписку из клиента?", isPresented: $showRemoveImportedConfirmation) {
            Button("Убрать", role: .destructive) {
                model.removeImportedFromClient()
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Подписка останется в списке внешних, но на главной больше не будет активной.")
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Button {
                model.activeSheet = .connectionReport
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Rectangle()
                        .fill(statusBarColor)
                        .frame(width: 4, height: 32)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.statusTitle)
                            .font(.system(size: 27, weight: .semibold))
                            .foregroundStyle(DS.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Text(model.statusSubtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DS.muted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(model.isProtected ? "ЗАЩИЩЕНО" : "ОЖИДАНИЕ")
                            .microLabel(color: model.isProtected ? DS.green : DS.muted)
                        HStack(spacing: 3) {
                            Text("ОТЧЁТ")
                                .microLabel(color: DS.ink)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(DS.ink)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())

            Button {
                model.activeSheet = .profiles
            } label: {
                HStack(spacing: 8) {
                    Text("01")
                        .microLabel(color: DS.muted)
                        .frame(width: 18, alignment: .leading)

                    Rectangle()
                        .fill(DS.acid)
                        .frame(width: 3, height: 13)

                    Text("РЕЖИМ")
                        .microLabel()

                    Text(model.connectionMode.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 8)

                    Text("ПРОФИЛЬ")
                        .microLabel(color: DS.green)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DS.green)
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .overlay(Rectangle().stroke(DS.line))
            }
            .buttonStyle(HapticButtonStyle())
        }
    }

    private var serverRow: some View {
        Button {
            model.openChangeServer()
        } label: {
            HStack(spacing: 10) {
                Text("02")
                    .microLabel(color: DS.muted)
                    .frame(width: 20, alignment: .leading)

                serverBadge

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(model.usesAutoSelection ? "АВТО" : "СЕРВЕР")
                            .microLabel(color: DS.green)
                        Text("·")
                            .microLabel(color: DS.muted)
                        Text((model.activeSubscription?.name ?? "VPN DIRECT").uppercased())
                            .microLabel()
                            .lineLimit(1)
                    }

                    Text(serverSubtitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 5)

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(model.activeServer == nil ? DS.muted : DS.green)
                            .frame(width: 5, height: 5)
                        Text(model.activeServer?.pingLabel ?? "— MS")
                            .microLabel(color: DS.ink)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DS.muted)
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var serverBadge: some View {
        Group {
            if model.usesAutoSelection {
                Text("A")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .frame(width: 28, height: 28)
                    .background(DS.ink)
                    .foregroundStyle(DS.acid)
            } else if let server = model.activeServer {
                FlagImage(code: server.countryCode, width: 28, height: 20)
            } else {
                Text("A")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .frame(width: 28, height: 28)
                    .background(DS.ink)
                    .foregroundStyle(DS.acid)
            }
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 0) {
            compactControl(
                icon: "arrow.clockwise",
                title: model.isRefreshingSubscription ? "..." : "ОБНОВИТЬ",
                disabled: !canUpdate || model.isRefreshingSubscription
            ) {
                model.refreshActiveSubscription()
            }

            controlDivider

            compactControl(icon: "arrow.left.arrow.right", title: "ПОДПИСКА") {
                model.openChangeSubscription()
            }

            controlDivider

            compactControl(icon: "location.north", title: "СЕРВЕР") {
                model.openChangeServer()
            }

            controlDivider

            compactControl(icon: "minus", title: "УБРАТЬ", disabled: !canSoftRemove, destructive: true) {
                showRemoveImportedConfirmation = true
            }
        }
        .frame(height: 47)
        .background(DS.panel.opacity(0.22))
        .overlay(Rectangle().stroke(DS.line))
    }

    private var controlDivider: some View {
        Rectangle()
            .fill(DS.line)
            .frame(width: 1, height: 27)
    }

    private func compactControl(
        icon: String,
        title: String,
        disabled: Bool = false,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(disabled ? DS.muted.opacity(0.35) : (destructive ? DS.danger : DS.ink))

                Text(title)
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(disabled ? DS.muted.opacity(0.35) : DS.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .disabled(disabled)
    }

    private var telemetryRow: some View {
        HStack(spacing: 0) {
            telemetryCell(value: "\(model.trafficText) \(model.trafficUnit)", label: "СЕГОДНЯ")
            telemetryDivider
            telemetryCell(value: model.isProtected ? model.runtimeText : "00:00:00", label: "В СЕТИ")
            telemetryDivider
            telemetryCell(value: "\(model.subscriptionTrafficText) \(model.subscriptionTrafficUnit)", label: "ОСТАЛОСЬ")
        }
        .frame(height: 50)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var telemetryDivider: some View {
        Rectangle()
            .fill(DS.line)
            .frame(width: 1, height: 28)
    }

    private func telemetryCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(DS.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(label)
                .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 2)
    }

    private var serverSubtitle: String {
        guard model.activeSubscription != nil else { return "Подписка не выбрана" }
        if model.usesAutoSelection {
            if let server = model.activeServer {
                return "Сейчас: \(server.locationLabel)"
            }
            return model.isProtected ? "Сейчас: определяем маршрут…" : "Автовыбор маршрута"
        }
        guard let server = model.activeServer else { return "Нет серверов" }
        return server.locationLabel
    }

    private var statusBarColor: Color {
        switch model.phase {
        case .connecting: Color.orange
        case .disconnecting: Color.orange.opacity(0.85)
        case .switching: DS.acid
        case .idle: model.isProtected ? DS.green : DS.danger
        }
    }

    /// Нижний блок (обновить / подписка / сервер / убрать) — только для внешней подписки.
    private var showsExternalSubscriptionControls: Bool {
        guard let sub = model.activeSubscription else { return false }
        return !DirectBuiltinProfile.isDirectOwned(sub.profile.remoteURL)
    }

    private var canSoftRemove: Bool {
        showsExternalSubscriptionControls
    }

    private var canUpdate: Bool {
        guard showsExternalSubscriptionControls,
              let sub = model.activeSubscription
        else { return false }
        let remote = sub.profile.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return sub.profile.type == .remote && !remote.isEmpty
    }
}

#endif
