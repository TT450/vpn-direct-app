import AppIntents
import SwiftUI
import WidgetKit

struct StatusHomeWidget: Widget {
    private let kind = "\(WidgetAppConfiguration.packageName).widget.Status"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetPalette.paper
                }
        }
        .configurationDisplayName("VPN Direct")
        .description("Статус защиты и быстрое подключение")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

struct StatusEntry: TimelineEntry {
    let date: Date
    let isConnected: Bool
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: .now, isConnected: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        Task {
            completion(await makeEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60))))
        }
    }

    private func makeEntry() async -> StatusEntry {
        let connected = (try? await WidgetTunnelControl.currentIsStarted()) ?? false
        return StatusEntry(date: .now, isConnected: connected)
    }
}

private enum WidgetPalette {
    static let paper = Color(red: 0.93, green: 0.94, blue: 0.91)
    static let ink = Color(red: 0.08, green: 0.09, blue: 0.08)
    static let muted = Color(red: 0.48, green: 0.50, blue: 0.46)
    static let acid = Color(red: 0.66, green: 0.94, blue: 0.41)
    static let green = Color(red: 0.18, green: 0.55, blue: 0.31)
    static let danger = Color(red: 0.82, green: 0.24, blue: 0.20)
    static let panel = Color(red: 0.19, green: 0.21, blue: 0.18)
}

struct StatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatusEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumLayout
        case .accessoryCircular:
            circularLayout
        case .accessoryRectangular:
            rectangularLayout
        case .accessoryInline:
            Text(entry.isConnected ? "VPN Direct · Вкл" : "VPN Direct · Выкл")
        default:
            smallLayout
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VPN DIRECT")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(WidgetPalette.muted)
            HStack(spacing: 6) {
                Circle()
                    .fill(entry.isConnected ? WidgetPalette.green : WidgetPalette.danger)
                    .frame(width: 8, height: 8)
                Text(entry.isConnected ? "Подключено" : "Отключено")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WidgetPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            ToggleVPNButton(isConnected: entry.isConnected)
        }
        .padding(14)
    }

    private var mediumLayout: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("КЛИЕНТ / VPN")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WidgetPalette.muted)
                HStack(spacing: 8) {
                    Text(entry.isConnected ? "Подключено" : "Отключено")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(WidgetPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Circle()
                        .fill(entry.isConnected ? WidgetPalette.green : WidgetPalette.danger)
                        .frame(width: 8, height: 8)
                }
                Text(entry.isConnected ? "Трафик идёт через защищённый канал" : "Соединение не активно")
                    .font(.system(size: 12))
                    .foregroundStyle(WidgetPalette.muted)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            ToggleVPNButton(isConnected: entry.isConnected)
        }
        .padding(16)
    }

    private var circularLayout: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: entry.isConnected ? "lock.fill" : "lock.open")
                    .font(.system(size: 16, weight: .semibold))
                Text(entry.isConnected ? "ON" : "OFF")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(entry.isConnected ? WidgetPalette.green : WidgetPalette.ink)
        }
    }

    private var rectangularLayout: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.isConnected ? "lock.fill" : "lock.open")
            VStack(alignment: .leading, spacing: 2) {
                Text("VPN Direct")
                    .font(.headline)
                Text(entry.isConnected ? "Подключено" : "Отключено")
                    .font(.caption)
            }
        }
    }
}

private struct ToggleVPNButton: View {
    let isConnected: Bool

    var body: some View {
        Button(intent: ToggleServiceControlIntent(value: !isConnected)) {
            Text(isConnected ? "Выкл" : "Вкл")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isConnected ? WidgetPalette.ink : WidgetPalette.acid)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(isConnected ? Color.white.opacity(0.72) : WidgetPalette.panel)
                .overlay(Rectangle().stroke(Color.black.opacity(0.14)))
        }
        .buttonStyle(.plain)
    }
}

extension ToggleServiceControlIntent {
    init(value: Bool) {
        self.init()
        self.value = value
    }
}
