import CoreHaptics
import SwiftUI
import UIKit

#if os(iOS)

/// The tactile vocabulary of VPN Direct. Keep calls semantic: the same event
/// must always mean the same thing, regardless of the screen that emitted it.
public enum HapticEvent: Hashable {
    case touchDown
    case navigation
    case selection
    case toggleOn
    case toggleOff
    case sheetPresented
    case sheetDismissed
    case menuOpened
    case menuClosed
    case swipeThreshold
    case copied
    case shared
    case saved
    case imported
    case deleted
    case warning
    case error
    case loading
    case vpnConnecting
    case vpnConnected
    case vpnDisconnecting
    case vpnDisconnected
    case vpnSwitching
    case vpnSwitched
    case purchaseStarted
    case purchaseCompleted
}

@MainActor
public final class HapticManager {
    public static let shared = HapticManager()

    private static let enabledKey = "hapticsEnabled"

    private var engine: CHHapticEngine?
    private var lastPlayedAt: [HapticEvent: CFTimeInterval] = [:]
    private var lastGlobalAt: CFTimeInterval = 0

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    private init() {
        prepare()
    }

    public var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.enabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: Self.enabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    public func prepare() {
        impactLight.prepare()
        impactSoft.prepare()
        impactMedium.prepare()
        impactRigid.prepare()
        selection.prepare()
        notification.prepare()

        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            engine.stoppedHandler = { _ in }
            engine.resetHandler = { [weak self] in
                Task { @MainActor in try? self?.engine?.start() }
            }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    public func setEnabled(_ enabled: Bool) {
        if enabled {
            isEnabled = true
            play(.toggleOn)
        } else {
            play(.toggleOff)
            isEnabled = false
        }
    }

    public func play(_ event: HapticEvent) {
        guard isEnabled else { return }

        let now = CACurrentMediaTime()
        let perEventWindow: CFTimeInterval = event == .selection || event == .swipeThreshold ? 0.07 : 0.12
        guard now - (lastPlayedAt[event] ?? 0) >= perEventWindow else { return }

        if event != .touchDown, now - lastGlobalAt < 0.035 { return }
        lastPlayedAt[event] = now
        lastGlobalAt = now

        if UIAccessibility.isReduceMotionEnabled {
            playReduced(event)
            prepareFeedbackGenerators()
            return
        }

        switch event {
        case .touchDown:
            impactSoft.impactOccurred(intensity: 0.34)
        case .navigation:
            impactLight.impactOccurred(intensity: 0.48)
        case .selection:
            selection.selectionChanged()
        case .toggleOn:
            playPattern([(0.00, 0.32, 0.30), (0.065, 0.58, 0.62)], fallback: { impactLight.impactOccurred(intensity: 0.62) })
        case .toggleOff:
            playPattern([(0.00, 0.50, 0.55), (0.075, 0.24, 0.25)], fallback: { impactSoft.impactOccurred(intensity: 0.45) })
        case .sheetPresented, .menuOpened:
            playPattern([(0.00, 0.28, 0.22), (0.055, 0.42, 0.38)], fallback: { impactLight.impactOccurred(intensity: 0.50) })
        case .sheetDismissed, .menuClosed:
            impactSoft.impactOccurred(intensity: 0.42)
        case .swipeThreshold:
            impactRigid.impactOccurred(intensity: 0.38)
        case .copied, .shared, .saved, .imported:
            playPattern([(0.00, 0.32, 0.28), (0.075, 0.62, 0.58)], fallback: { notification.notificationOccurred(.success) })
        case .deleted:
            playPattern([(0.00, 0.56, 0.70), (0.10, 0.30, 0.45)], fallback: { impactMedium.impactOccurred(intensity: 0.65) })
        case .warning:
            notification.notificationOccurred(.warning)
        case .error:
            notification.notificationOccurred(.error)
        case .loading:
            impactSoft.impactOccurred(intensity: 0.28)
        case .vpnConnecting:
            playPattern([(0.00, 0.30, 0.24), (0.11, 0.44, 0.36), (0.22, 0.60, 0.48)], fallback: { impactMedium.impactOccurred(intensity: 0.55) })
        case .vpnConnected:
            playPattern([(0.00, 0.42, 0.35), (0.08, 0.70, 0.66), (0.18, 0.92, 0.82)], fallback: { notification.notificationOccurred(.success) })
        case .vpnDisconnecting:
            playPattern([(0.00, 0.58, 0.58), (0.105, 0.36, 0.34)], fallback: { impactMedium.impactOccurred(intensity: 0.48) })
        case .vpnDisconnected:
            playPattern([(0.00, 0.66, 0.72), (0.12, 0.24, 0.28)], fallback: { impactSoft.impactOccurred(intensity: 0.58) })
        case .vpnSwitching:
            playPattern([(0.00, 0.38, 0.58), (0.09, 0.58, 0.72), (0.18, 0.38, 0.58)], fallback: { selection.selectionChanged() })
        case .vpnSwitched:
            playPattern([(0.00, 0.44, 0.38), (0.085, 0.76, 0.72)], fallback: { notification.notificationOccurred(.success) })
        case .purchaseStarted:
            playPattern([(0.00, 0.46, 0.52), (0.09, 0.46, 0.52)], fallback: { impactMedium.impactOccurred(intensity: 0.52) })
        case .purchaseCompleted:
            playPattern([(0.00, 0.44, 0.36), (0.075, 0.72, 0.68), (0.17, 1.00, 0.86)], fallback: { notification.notificationOccurred(.success) })
        }

        prepareFeedbackGenerators()
    }

    private func prepareFeedbackGenerators() {
        impactLight.prepare()
        impactSoft.prepare()
        selection.prepare()
        notification.prepare()
    }

    private func playReduced(_ event: HapticEvent) {
        switch event {
        case .error:
            notification.notificationOccurred(.error)
        case .warning:
            notification.notificationOccurred(.warning)
        case .vpnConnected, .vpnSwitched,
             .purchaseCompleted, .copied, .shared, .saved, .imported:
            notification.notificationOccurred(.success)
        case .selection, .swipeThreshold:
            selection.selectionChanged()
        case .touchDown, .sheetDismissed, .menuClosed, .toggleOff,
             .vpnDisconnected, .deleted:
            impactSoft.impactOccurred(intensity: 0.35)
        default:
            impactLight.impactOccurred(intensity: 0.45)
        }
    }

    private func playPattern(
        _ pulses: [(time: TimeInterval, intensity: Float, sharpness: Float)],
        fallback: () -> Void
    ) {
        guard let engine, CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            fallback()
            return
        }

        let events = pulses.map { pulse in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: pulse.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: pulse.sharpness),
                ],
                relativeTime: pulse.time
            )
        }

        do {
            try engine.start()
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback()
        }
    }
}

/// Default physical acknowledgement for every SwiftUI Button in the app.
/// Visual styling is unchanged — only touch-down haptics are added.
public struct HapticButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Full label bounds are tappable — not only the text glyphs.
            .contentShape(Rectangle())
            .onChangeCompat(of: configuration.isPressed) { isPressed in
                if isPressed { HapticManager.shared.play(.touchDown) }
            }
    }
}

private struct HapticScrollThresholdModifier: ViewModifier {
    @State private var crossedFirst = false
    @State private var crossedSecond = false

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    // Ignore mostly-horizontal pans so tab pages don't feel like a website.
                    guard abs(value.translation.height) >= abs(value.translation.width) else { return }
                    let distance = hypot(value.translation.width, value.translation.height)
                    if distance > 44, !crossedFirst {
                        crossedFirst = true
                        HapticManager.shared.play(.swipeThreshold)
                    }
                    if distance > 128, !crossedSecond {
                        crossedSecond = true
                        HapticManager.shared.play(.swipeThreshold)
                    }
                }
                .onEnded { _ in
                    crossedFirst = false
                    crossedSecond = false
                }
        )
    }
}

public extension View {
    func hapticScrollThresholds() -> some View {
        modifier(HapticScrollThresholdModifier())
    }

    func hapticToggle(_ value: Bool) -> some View {
        onChangeCompat(of: value) { newValue in
            HapticManager.shared.play(newValue ? .toggleOn : .toggleOff)
        }
    }

    func hapticSelection<Value: Equatable>(_ value: Value) -> some View {
        onChangeCompat(of: value) { _ in
            HapticManager.shared.play(.selection)
        }
    }
}

#endif
