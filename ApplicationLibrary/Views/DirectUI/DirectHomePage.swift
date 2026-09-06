import SwiftUI

#if os(iOS)

struct DirectHomePage: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        VStack(spacing: 0) {
            Button {
                model.activeSheet = .connectionReport
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 9) {
                        Circle()
                            .fill(model.isProtected ? DS.green : DS.danger)
                            .frame(width: 8, height: 8)
                        Text(model.statusTitle)
                            .font(.system(size: 37, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13))
                            .foregroundStyle(model.isProtected ? DS.green : DS.muted)
                    }
                    Text(model.statusSubtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.muted)
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
                    Text("ПРОФИЛЬ · →").microLabel(color: DS.green)
                }
                .padding(.horizontal, 11)
                .frame(height: 38)
                .background(Color.white.opacity(0.28))
                .overlay(Rectangle().stroke(DS.line))
            }
            .buttonStyle(HapticButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer(minLength: 4)

            DialView(isConnected: model.dialIsConnected, isBusy: model.isBusy) {
                model.toggleConnection()
            }

            Spacer(minLength: 4)

            Button {
                model.activeSheet = .serverPicker
            } label: {
                HStack(spacing: 11) {
                    Text("01").microLabel()
                    Group {
                        if model.usesAutoSelection {
                            Text("A")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .frame(width: 28, height: 28)
                                .background(DS.ink)
                                .foregroundStyle(DS.acid)
                        } else if let server = model.activeServer {
                            FlagImage(code: server.countryCode, width: 28, height: 20)
                        } else {
                            Text("A")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .frame(width: 28, height: 28)
                                .background(DS.ink)
                                .foregroundStyle(DS.acid)
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
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
                .padding(.horizontal, 20)
                .frame(height: 76)
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())
            .overlay(alignment: .top) { Hairline() }
            .overlay(alignment: .bottom) { Hairline() }

            AccessStrip(model: model)

            HStack(spacing: 0) {
                MetricCell(label: "ТРАФИК СЕГОДНЯ", value: model.trafficText, unit: model.trafficUnit, compact: true)
                Hairline().frame(width: 1, height: 64)
                MetricCell(label: "ВРЕМЯ В СЕТИ", value: model.isProtected ? model.runtimeText : "00:00:00", unit: "", compact: true)
                Hairline().frame(width: 1, height: 64)
                MetricCell(
                    label: "ДОСТУПНЫЙ ТРАФИК",
                    value: model.subscriptionTrafficText,
                    unit: model.subscriptionTrafficUnit,
                    compact: true
                )
            }
            .frame(height: 70)
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

/// Compact active-subscription strip under the server row.
private struct AccessStrip: View {
    @ObservedObject var model: VPNConnectionModel

    private var detailLine: String {
        "\(model.accessStripTitle) · \(model.accessStripDetail)"
    }

    var body: some View {
        Button {
            model.openAccessStripAction()
        } label: {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Text("ДОСТУП").microLabel()
                Text(detailLine)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(DS.acid.opacity(0.18))
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .overlay(alignment: .bottom) { Hairline() }
    }
}

private struct MetricCell: View {
    let label: String
    let value: String
    let unit: String
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).microLabel()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: compact ? 14 : 17, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unit.isEmpty {
                    Text(unit).microLabel()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 12 : 20)
    }
}

#endif
