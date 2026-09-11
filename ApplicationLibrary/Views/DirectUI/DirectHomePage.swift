import SwiftUI

#if os(iOS)

struct DirectHomePage: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        VStack(spacing: 0) {
            homeHeader
                .padding(.horizontal, 20)
                .padding(.top, 18)

            Spacer(minLength: 2)

            // The dial is deliberately left as-is. It remains the visual and interaction anchor.
            DialView(isConnected: model.dialIsConnected, isBusy: model.isBusy) {
                model.toggleConnection()
            }

            Spacer(minLength: 2)

            serverRow
            accessRow
            actionRail
            metricsRail
        }
        .background {
            DS.paper.ignoresSafeArea()
        }
    }

    private var homeHeader: some View {
        VStack(spacing: 10) {
            Button {
                model.activeSheet = .connectionReport
            } label: {
                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(model.isProtected ? DS.green : DS.danger)
                                .frame(width: 7, height: 7)

                            Text(model.statusTitle)
                                .font(.system(size: 31, weight: .semibold, design: .rounded))
                                .foregroundStyle(DS.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }

                        Text(model.statusSubtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(model.isProtected ? "SECURE" : "READY")
                            .microLabel(color: model.isProtected ? DS.green : DS.muted)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DS.muted)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())

            Button {
                model.activeSheet = .profiles
            } label: {
                HStack(spacing: 9) {
                    Text("MODE").microLabel()
                    Text(model.connectionMode)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.ink)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text("PROFILE")
                        .microLabel(color: DS.green)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DS.green)
                }
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(DS.panel.opacity(0.55))
                .overlay(Rectangle().stroke(DS.line))
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())
        }
    }

    private var serverRow: some View {
        Button {
            model.activeSheet = .serverPicker
        } label: {
            HStack(spacing: 10) {
                Text("01")
                    .microLabel(color: DS.muted)
                    .frame(width: 20, alignment: .leading)

                serverBadge

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.usesAutoSelection
                        ? "АВТО · \((model.activeSubscription?.name ?? "").uppercased())"
                        : (model.activeSubscription?.name ?? "").uppercased())
                        .microLabel()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(serverSubtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 4)

                HStack(spacing: 5) {
                    Circle()
                        .fill(model.isProtected ? DS.green : DS.muted)
                        .frame(width: 5, height: 5)
                    Text(model.activeServer?.pingLabel ?? "— MS")
                        .microLabel(color: DS.ink)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS.muted)
            }
            .padding(.horizontal, 20)
            .frame(height: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .overlay(alignment: .top) { Hairline() }
    }

    private var serverBadge: some View {
        Group {
            if model.usesAutoSelection {
                Text("A")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .frame(width: 27, height: 27)
                    .background(DS.ink)
                    .foregroundStyle(DS.acid)
            } else if let server = model.activeServer {
                FlagImage(code: server.countryCode, width: 27, height: 19)
            } else {
                Text("A")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .frame(width: 27, height: 27)
                    .background(DS.ink)
                    .foregroundStyle(DS.acid)
            }
        }
    }

    private var accessRow: some View {
        Button {
            model.openAccessStripAction()
        } label: {
            HStack(spacing: 7) {
                Rectangle()
                    .fill(DS.acid)
                    .frame(width: 3, height: 15)

                Text("ACCESS")
                    .microLabel(color: DS.ink)

                Text("\(model.accessStripTitle) · \(model.accessStripDetail)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Spacer(minLength: 3)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS.muted)
            }
            .padding(.horizontal, 20)
            .frame(height: 31)
            .background(DS.acid.opacity(0.12))
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var actionRail: some View {
        HStack(spacing: 0) {
            HomeActionButton(
                index: "02",
                icon: "arrow.clockwise",
                title: model.isRefreshingSubscription ? "..." : "ОБНОВИТЬ",
                disabled: !canUpdate || model.isRefreshingSubscription
            ) {
                model.refreshActiveSubscription()
            }

            Hairline().frame(width: 1, height: 48)

            HomeActionButton(
                icon: "arrow.left.arrow.right",
                title: "ПОДПИСКА"
            ) {
                model.openChangeSubscription()
            }

            Hairline().frame(width: 1, height: 48)

            HomeActionButton(
                icon: "location.north",
                title: "СЕРВЕР"
            ) {
                model.openChangeServer()
            }

            Hairline().frame(width: 1, height: 48)

            HomeActionButton(
                icon: "minus",
                title: "УБРАТЬ",
                disabled: !canSoftRemove,
                destructive: true
            ) {
                model.showRemoveImportedConfirmation = true
            }
        }
        .frame(height: 50)
        .overlay(alignment: .bottom) { Hairline() }
        .alert("Убрать подписку из клиента?", isPresented: $model.showRemoveImportedConfirmation) {
            Button("Убрать", role: .destructive) {
                model.removeImportedFromClient()
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Подписка останется в списке внешних, но на главной больше не будет активной.")
        }
    }

    private var metricsRail: some View {
        HStack(spacing: 0) {
            HomeMetric(
                value: "\(model.trafficText) \(model.trafficUnit)",
                label: "СЕГОДНЯ"
            )

            Hairline().frame(width: 1, height: 54)

            HomeMetric(
                value: model.isProtected ? model.runtimeText : "00:00:00",
                label: "В СЕТИ"
            )

            Hairline().frame(width: 1, height: 54)

            HomeMetric(
                value: "\(model.subscriptionTrafficText) \(model.subscriptionTrafficUnit)",
                label: "ОСТАЛОСЬ"
            )
        }
        .frame(height: 58)
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

private struct HomeActionButton: View {
    let index: String?
    let icon: String
    let title: String
    var disabled = false
    var destructive = false
    let action: () -> Void

    init(
        index: String? = nil,
        icon: String,
        title: String,
        disabled: Bool = false,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.index = index
        self.icon = icon
        self.title = title
        self.disabled = disabled
        self.destructive = destructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    if let index {
                        Text(index).microLabel(color: DS.muted)
                    }
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(disabled ? DS.muted.opacity(0.45) : (destructive ? DS.danger : DS.ink))
                }

                Text(title)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(disabled ? DS.muted.opacity(0.45) : DS.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .disabled(disabled)
    }
}

private struct HomeMetric: View {
    let value: String
    let label: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(DS.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 6)
    }
}

#endif
