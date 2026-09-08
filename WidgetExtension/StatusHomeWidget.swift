import AppIntents
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Widget

struct StatusHomeWidget: Widget {
    let kind = WidgetAppConfiguration.statusWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    AladdinWidgetTheme.background()
                }
        }
        .configurationDisplayName("VPN Direct")
        .description("Нажмите, чтобы включить или выключить VPN")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

// MARK: - Entry / Provider

struct StatusEntry: TimelineEntry {
    let date: Date
    let isConnected: Bool
    let serverName: String
    let countryCode: String
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: .now, isConnected: false, serverName: "VPN Direct", countryCode: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        Task { completion(await makeEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15))))
        }
    }

    private func makeEntry() async -> StatusEntry {
        let connected = await WidgetTunnelControl.currentIsStarted()
        if let snap = WidgetStatusStore.readSnapshot() {
            return StatusEntry(
                date: .now,
                isConnected: connected,
                serverName: snap.serverName.isEmpty ? "VPN Direct" : snap.serverName,
                countryCode: snap.countryCode
            )
        }
        return StatusEntry(date: .now, isConnected: connected, serverName: "VPN Direct", countryCode: "")
    }
}

// MARK: - Root

struct StatusWidgetView: View {
    let entry: StatusEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall: SmallWidget(entry: entry)
        case .systemMedium: MediumWidget(entry: entry)
        case .systemLarge: LargeWidget(entry: entry)
        case .accessoryCircular: AccessoryCircular(entry: entry)
        case .accessoryRectangular: AccessoryRectangular(entry: entry)
        case .accessoryInline: AccessoryInline(entry: entry)
        @unknown default: SmallWidget(entry: entry)
        }
    }
}

// MARK: - SMALL

private struct SmallWidget: View {
    let entry: StatusEntry

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("VPN DIRECT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer(minLength: 0)
                Circle()
                    .fill(entry.isConnected ? Color.green : Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)
            }

            Spacer(minLength: 2)

            Button(intent: ToggleVPNWidgetIntent()) {
                AladdinPowerMedallion(connected: entry.isConnected, connecting: false, size: 78)
            }
            .buttonStyle(.plain)

            Text(entry.isConnected ? "Включен" : "Включить")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AladdinWidgetTheme.goldBright)

            Spacer(minLength: 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.isConnected ? "Выключить VPN Direct" : "Включить VPN Direct")
        .accessibilityAddTraits(.isButton)
    }
}

private struct MediumWidget: View {
    let entry: StatusEntry

    var body: some View {
        HStack(spacing: 14) {
            Button(intent: ToggleVPNWidgetIntent()) {
                AladdinPowerMedallion(connected: entry.isConnected, connecting: false, size: 64)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text("VPN DIRECT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.65))
                Text(entry.isConnected ? "Включен" : "Включить")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text(entry.serverName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AladdinWidgetTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LargeWidget: View {
    let entry: StatusEntry

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("VPN DIRECT")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                AladdinStatusDot(connected: entry.isConnected)
            }
            Spacer(minLength: 0)
            Button(intent: ToggleVPNWidgetIntent()) {
                AladdinPowerMedallion(connected: entry.isConnected, connecting: false, size: 96)
            }
            .buttonStyle(.plain)
            Text(entry.isConnected ? "Включен" : "Включить")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AladdinWidgetTheme.goldBright)
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AccessoryCircular: View {
    let entry: StatusEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: entry.isConnected ? "lock.fill" : "lock.open")
                .font(.system(size: 18, weight: .bold))
        }
    }
}

private struct AccessoryRectangular: View {
    let entry: StatusEntry
    var body: some View {
        HStack {
            Image(systemName: entry.isConnected ? "lock.fill" : "lock.open")
            Text(entry.isConnected ? "VPN ON" : "VPN OFF")
                .font(.headline)
        }
    }
}

private struct AccessoryInline: View {
    let entry: StatusEntry
    var body: some View {
        Text(entry.isConnected ? "VPN Direct · ON" : "VPN Direct · OFF")
    }
}
