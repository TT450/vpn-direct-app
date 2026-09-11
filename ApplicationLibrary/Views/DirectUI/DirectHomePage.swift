import SwiftUI

#if os(iOS)

struct DirectHomePage: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)

            Spacer(minLength: 0)

            // The dial remains the unchanged interaction anchor of the home screen.
            DialView(isConnected: model.dialIsConnected, isBusy: model.isBusy) {
                model.toggleConnection()
            }

            Spacer(minLength: 0)

            serverPanel
            accessPanel
            controlsPanel
            telemetryPanel
        }
        .background(DS.paper.ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: 12) {
            Button {
                model.activeSheet = .connectionReport
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(model.isProtected ? DS.green.opacity(0.35) : DS.danger.opacity(0.28), lineWidth: 1)
                            .frame(width: 28, height: 28)
                        Circle()
                            .fill(model.isProtected ? DS.green : DS.danger)
                            .frame(width: 7, height: 7)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.statusTitle)
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(model.statusSubtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DS.muted)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(model.isProtected ? "PROTECTED" : "STANDBY")
                            .microLabel(color: model.isProtected ? DS.green : DS.muted)
                        HStack(spacing: 3) {
                            Text("01")
                                .microLabel()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
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
                HStack(spacing: 9) {
                    Rectangle()
                        .fill(DS.acid)
                        .frame(width: 3, height: 14)

                    Text("РЕЖИМ")
                        .microLabel()
                    Text(model.connectionMode.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.ink)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text("ПРОФИЛЬ")
                        .microLabel(color: DS.green)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DS.green)
                }
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(DS.panel.opacity(0.5))
                .overlay(Rectangle().stroke(DS.line))
            }
            .buttonStyle(HapticButtonStyle())
        }
    }

    private var serverPanel: some View {
        Button {
            model.activeSheet = .serverPicker
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    Text("01")
                        .microLabel(color: DS.muted)
                        .frame(width: 20, alignment: .leading)

                    serverBadge

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(model.usesAutoSelection ? "АВТОВЫБОР" : "СЕРВЕР")
                                .microLabel(color: DS.green)
                            Text("·")
                                .microLabel(color: DS.line)
                            Text((model.activeSubscription?.name ?? "ДОСТУП").uppercased())
                                .microLabel()
                                .lineLimit(1)
                        }

                        Text(serverSubtitle)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 3) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(model.isProtected ? DS.green : DS.muted)
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
                .frame(height: 66)

                HStack(spacing: 0) {
                    Text("VPN DIRECT")
                        .microLabel(color: DS.muted)
                    Spacer()
                    Text(model.usesAutoSelection ? "BEST ROUTE" : "FIXED ROUTE")
                        .microLabel(color: DS.ink)
                }
                .padding(.horizontal, 20)
                .frame(height: 18)
            }
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
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .frame(width: 28, height: 28)
                    .background(DS.ink)
                    .foregroundStyle(DS.acid)
            } else if let server = model.activeServer {
                FlagImage(code: server.countryCode, width: 28, height: 20)
            } else {
                Text("A")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .frame(width: 28, height: 28)
                    .background(DS.ink)
                    .foregroundStyle(DS.acid)
            }
        }
    }

    private var accessPanel: some View {
        Button {
            model.openAccessStripAction()
        } label: {
            HStack(spacing: 8) {
                Text("ACCESS")
                    .microLabel(color: DS.ink)
                Rectangle()
                    .fill(DS.acid)
                    .frame(width: 1, height: 14)
                Text(model.accessStripTitle.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)
                Text("·")
                    .foregroundStyle(DS.muted)
                Text(model.accessStripDetail)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS.green)
            }
            .padding(.horizontal, 20)
            .frame(height: 31)
            .background(DS.acid.opacity(0.15))
        }
        .buttonStyle(HapticButtonStyle())
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var controlsPanel: some View {
        HStack(spacing: 0) {
            ornateControl(
                number: "02",
                icon: "arrow.clockwise",
                title: model.isRefreshingSubscription ? "..." : "ОБНОВИТЬ",
                disabled: !canUpdate || model.isRefreshingSubscription
            ) {
                model.refreshActiveSubscription()
            }

            controlDivider

            ornateControl(icon: "arrow.left.arrow.right", title: "ПОДПИСКА") {
                model.openChangeSubscription()
            }

            controlDivider

            ornateControl(icon: "location.north", title: "СЕРВЕР") {
                model.openChangeServer()
            }

            controlDivider

            ornateControl(icon: "minus", title: "УБРАТЬ", disabled: !canSoftRemove, destructive: true) {
                model.showRemoveImportedConfirmation = true
            }
        }
        .frame(height: 53)
        .background(DS.panel.opacity(0.35))
        .overlay(Rectangle().stroke(DS.line))
        .padding(.top, 1)
        .alert("Убрать подписку из клиента?", isPresented: $model.showRemoveImportedConfirmation) {
            Button("Убрать", role: .destructive) {
                model.removeImportedFromClient()
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Подписка останется в списке внешних, но на главной больше не будет активной.")
        }
    }

    private var controlDivider: some View {
        Rectangle()
            .fill(DS.line)
            .frame(width: 1, height: 31)
    }

    private func ornateControl(
        number: String? = nil,
        icon: String,
        title: String,
        disabled: Bool = false,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    if let number {
                        Text(number).microLabel(color: DS.muted)
                    }
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(disabled ? DS.muted.opacity(0.35) : (destructive ? DS.danger : DS.ink))
                }
                Text(title)
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(disabled ? DS.muted.opacity(0.35) : DS.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .disabled(disabled)
    }

    private var telemetryPanel: some View {
        HStack(spacing: 0) {
            telemetry(
                number: "01",
                value: "\(model.trafficText) \(model.trafficUnit)",
                label: "СЕГОДНЯ"
            )
            telemetryDivider
            telemetry(
                number: "02",
                value: model.isProtected ? model.runtimeText : "00:00:00",
                label: "В СЕТИ"
            )
            telemetryDivider
            telemetry(
                number: "03",
                value: "\(model.subscriptionTrafficText) \(model.subscriptionTrafficUnit)",
                label: "ОСТАЛОСЬ"
            )
        }
        .frame(height: 58)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var telemetryDivider: some View {
        Rectangle()
            .fill(DS.line)
            .frame(width: 1, height: 35)
    }

    private func telemetry(number: String, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text(number).microLabel(color: DS.muted)
                Text(value)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            Text(label)
                .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 3)
    }

    private var serverSubtitle: String {
        guard let server = model.activeServer else { return "Нет серверов" }
        if model.usesAutoSelection {
            return "Сейчас: \(server.locationLabel)"
        }
        return server.locationLabel
    }

    private var canSoftRemove: Bool {
        guard let sub = model.activeSubscription else { return false }
        return !sub.isBuiltin
    }

    private var canUpdate: Bool {
        guard let sub = model.activeSubscription else { return false }
        guard !sub.isBuiltin else { return false }
        guard sub.profileType == .remote else { return false }
        return !sub.remoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#endif
