import AppIntents
import SwiftUI
import WidgetKit

struct ServiceToggleControl: ControlWidget {
    static let kind = WidgetAppConfiguration.widgetControlKind

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "VPN Direct",
                isOn: value,
                action: ToggleServiceControlIntent()
            ) { isOn in
                Label(isOn ? "Включен" : "Включить", systemImage: isOn ? "lock.fill" : "lock.open")
                    .controlWidgetActionHint(isOn ? "Выключить" : "Включить")
            }
            .tint(Color(red: 0.85, green: 0.68, blue: 0.28))
        }
        .displayName("VPN Direct")
        .description("Включить или выключить VPN Direct")
    }
}

extension ServiceToggleControl {
    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }

        /// Must never throw — a throwing provider can prevent adding the control
        /// (SpringBoard fails while customizing Control Center).
        func currentValue() async throws -> Bool {
            await WidgetTunnelControl.currentIsStarted()
        }
    }
}
