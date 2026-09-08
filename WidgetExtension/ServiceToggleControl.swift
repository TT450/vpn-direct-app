import AppIntents
import SwiftUI
import WidgetKit

struct ServiceToggleControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: WidgetAppConfiguration.widgetControlKind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "VPN Direct",
                isOn: value,
                action: ToggleServiceControlIntent()
            ) { isOn in
                Label(isOn ? "Подключено" : "Отключено", systemImage: isOn ? "lock.fill" : "lock.open")
                    .controlWidgetActionHint(isOn ? "Отключить" : "Подключить")
            }
            .tint(Color(red: 0.66, green: 0.94, blue: 0.41))
        }
        .displayName("VPN Direct")
        .description("Включить или выключить VPN Direct")
    }
}

extension ServiceToggleControl {
    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }

        func currentValue() async throws -> Bool {
            try await WidgetTunnelControl.currentIsStarted()
        }
    }
}

struct ToggleServiceControlIntent: SetValueIntent {
    static var title: LocalizedStringResource = "VPN Direct"
    static var description = IntentDescription("Включить или выключить VPN Direct")

    @Parameter(title: "Подключено")
    var value: Bool

    func perform() async throws -> some IntentResult {
        try await WidgetTunnelControl.setStarted(value)
        WidgetTunnelControl.reloadWidgets()
        return .result()
    }
}
