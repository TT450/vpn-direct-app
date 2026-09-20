import CoreHaptics
import SwiftUI
import UIKit

#if os(iOS)

/// Semantic tactile vocabulary: each event has a distinct physical signature.
public enum HapticEvent: Hashable {
    case touchDown, touchUp, navigation, back, tabChanged, selection
    case serverSelected, favoriteAdded, favoriteRemoved
    case toggleOn, toggleOff, sheetPresented, sheetDismissed, menuOpened, menuClosed
    case expand, collapse, swipeThreshold, scrollTick
    case copied, shared, saved, imported, deleted, deviceRemoved, promoApplied, balanceChanged
    case warning, error, networkError, loading, refreshStarted, refreshCompleted, dataArrived
    case validationSuccess, validationFailure, authStarted, authSuccess
    case vpnConnecting, vpnConnected, vpnDisconnecting, vpnDisconnected, vpnSwitching, vpnSwitched
    case purchaseStarted, paymentWaiting, paymentCancelled, paymentFailed, purchaseCompleted
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

    private init() { prepare() }
    public var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) == nil || UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }
    public func prepare() {
        impactLight.prepare(); impactSoft.prepare(); impactMedium.prepare(); impactRigid.prepare(); selection.prepare(); notification.prepare()
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine(); engine.isAutoShutdownEnabled = true
            engine.stoppedHandler = { _ in }
            engine.resetHandler = { [weak self] in Task { @MainActor in try? self?.engine?.start() } }
            try engine.start(); self.engine = engine
        } catch { engine = nil }
    }
    public func setEnabled(_ enabled: Bool) { if enabled { isEnabled = true; play(.toggleOn) } else { play(.toggleOff); isEnabled = false } }

    public func play(_ event: HapticEvent) {
        guard isEnabled else { return }
        let now = CACurrentMediaTime()
        let perEventWindow: CFTimeInterval = event == .selection || event == .swipeThreshold || event == .scrollTick ? 0.05 : 0.12
        guard now - (lastPlayedAt[event] ?? 0) >= perEventWindow else { return }
        if event != .touchDown && event != .touchUp && event != .scrollTick && now - lastGlobalAt < 0.035 { return }
        lastPlayedAt[event] = now; lastGlobalAt = now
        if UIAccessibility.isReduceMotionEnabled { playReduced(event); prepareFeedbackGenerators(); return }
        switch event {
        case .touchDown: playPattern([(0.00,0.18,0.12),(0.055,0.30,0.28)], fallback:{ impactSoft.impactOccurred(intensity:0.30) })
        case .touchUp: impactLight.impactOccurred(intensity:0.20)
        case .navigation: impactLight.impactOccurred(intensity:0.48)
        case .back: playPattern([(0.00,0.34,0.28),(0.065,0.18,0.18)], fallback:{ impactSoft.impactOccurred(intensity:0.32) })
        case .tabChanged: playPattern([(0.00,0.24,0.22),(0.055,0.38,0.34)], fallback:{ selection.selectionChanged() })
        case .selection: selection.selectionChanged()
        case .serverSelected: playPattern([(0.00,0.28,0.25),(0.065,0.52,0.54),(0.14,0.30,0.28)], fallback:{ impactMedium.impactOccurred(intensity:0.52) })
        case .favoriteAdded: playPattern([(0.00,0.24,0.22),(0.075,0.52,0.50)], fallback:{ impactLight.impactOccurred(intensity:0.54) })
        case .favoriteRemoved: playPattern([(0.00,0.44,0.44),(0.09,0.20,0.18)], fallback:{ impactSoft.impactOccurred(intensity:0.42) })
        case .toggleOn: playPattern([(0.00,0.32,0.30),(0.065,0.58,0.62)], fallback:{ impactLight.impactOccurred(intensity:0.62) })
        case .toggleOff: playPattern([(0.00,0.50,0.55),(0.075,0.24,0.25)], fallback:{ impactSoft.impactOccurred(intensity:0.45) })
        case .sheetPresented, .menuOpened: playPattern([(0.00,0.28,0.22),(0.055,0.42,0.38)], fallback:{ impactLight.impactOccurred(intensity:0.50) })
        case .sheetDismissed, .menuClosed: impactSoft.impactOccurred(intensity:0.42)
        case .expand: playPattern([(0.00,0.20,0.18),(0.06,0.40,0.36)], fallback:{ impactLight.impactOccurred(intensity:0.40) })
        case .collapse: playPattern([(0.00,0.40,0.36),(0.07,0.18,0.16)], fallback:{ impactSoft.impactOccurred(intensity:0.38) })
        case .swipeThreshold: impactRigid.impactOccurred(intensity:0.38)
        case .scrollTick: impactRigid.impactOccurred(intensity:0.72)
        case .copied: playPattern([(0.00,0.28,0.25),(0.07,0.62,0.58)], fallback:{ notification.notificationOccurred(.success) })
        case .shared: playPattern([(0.00,0.22,0.20),(0.08,0.46,0.42),(0.16,0.30,0.28)], fallback:{ notification.notificationOccurred(.success) })
        case .saved: playPattern([(0.00,0.30,0.26),(0.075,0.56,0.54)], fallback:{ notification.notificationOccurred(.success) })
        case .imported: playPattern([(0.00,0.32,0.28),(0.075,0.62,0.58)], fallback:{ notification.notificationOccurred(.success) })
        case .deleted, .deviceRemoved: playPattern([(0.00,0.56,0.70),(0.10,0.30,0.45)], fallback:{ impactMedium.impactOccurred(intensity:0.65) })
        case .promoApplied: playPattern([(0.00,0.22,0.20),(0.075,0.48,0.45),(0.16,0.76,0.70)], fallback:{ notification.notificationOccurred(.success) })
        case .balanceChanged: playPattern([(0.00,0.20,0.18),(0.09,0.40,0.36)], fallback:{ impactLight.impactOccurred(intensity:0.42) })
        case .warning: notification.notificationOccurred(.warning)
        case .error, .networkError: notification.notificationOccurred(.error)
        case .loading: playPattern([(0.00,0.20,0.18),(0.12,0.30,0.24)], fallback:{ impactSoft.impactOccurred(intensity:0.28) })
        case .refreshStarted: playPattern([(0.00,0.24,0.20),(0.10,0.34,0.28)], fallback:{ impactLight.impactOccurred(intensity:0.34) })
        case .refreshCompleted, .dataArrived: playPattern([(0.00,0.28,0.24),(0.075,0.52,0.48)], fallback:{ notification.notificationOccurred(.success) })
        case .validationSuccess: playPattern([(0.00,0.22,0.22),(0.07,0.44,0.42)], fallback:{ impactLight.impactOccurred(intensity:0.42) })
        case .validationFailure: playPattern([(0.00,0.48,0.58),(0.08,0.26,0.32)], fallback:{ notification.notificationOccurred(.error) })
        case .authStarted: playPattern([(0.00,0.28,0.24),(0.11,0.38,0.32)], fallback:{ impactLight.impactOccurred(intensity:0.40) })
        case .authSuccess: playPattern([(0.00,0.30,0.26),(0.075,0.60,0.56),(0.16,0.82,0.76)], fallback:{ notification.notificationOccurred(.success) })
        case .vpnConnecting: playPattern([(0.00,0.30,0.24),(0.11,0.44,0.36),(0.22,0.60,0.48)], fallback:{ impactMedium.impactOccurred(intensity:0.55) })
        case .vpnConnected: playPattern([(0.00,0.42,0.35),(0.08,0.70,0.66),(0.18,0.92,0.82)], fallback:{ notification.notificationOccurred(.success) })
        case .vpnDisconnecting: playPattern([(0.00,0.58,0.58),(0.105,0.36,0.34)], fallback:{ impactMedium.impactOccurred(intensity:0.48) })
        case .vpnDisconnected: playPattern([(0.00,0.66,0.72),(0.12,0.24,0.28)], fallback:{ impactSoft.impactOccurred(intensity:0.58) })
        case .vpnSwitching: playPattern([(0.00,0.38,0.58),(0.09,0.58,0.72),(0.18,0.38,0.58)], fallback:{ selection.selectionChanged() })
        case .vpnSwitched: playPattern([(0.00,0.44,0.38),(0.085,0.76,0.72)], fallback:{ notification.notificationOccurred(.success) })
        case .purchaseStarted: playPattern([(0.00,0.46,0.52),(0.09,0.46,0.52)], fallback:{ impactMedium.impactOccurred(intensity:0.52) })
        case .paymentWaiting: playPattern([(0.00,0.22,0.20),(0.14,0.34,0.30),(0.28,0.22,0.20)], fallback:{ impactSoft.impactOccurred(intensity:0.30) })
        case .paymentCancelled: playPattern([(0.00,0.46,0.48),(0.10,0.22,0.22)], fallback:{ impactSoft.impactOccurred(intensity:0.44) })
        case .paymentFailed: notification.notificationOccurred(.error)
        case .purchaseCompleted: playPattern([(0.00,0.44,0.36),(0.075,0.72,0.68),(0.17,1.00,0.86)], fallback:{ notification.notificationOccurred(.success) })
        }
        prepareFeedbackGenerators()
    }

    private func prepareFeedbackGenerators() { impactLight.prepare(); impactSoft.prepare(); impactMedium.prepare(); impactRigid.prepare(); selection.prepare(); notification.prepare() }
    private func playReduced(_ event: HapticEvent) {
        switch event {
        case .error, .networkError, .validationFailure, .paymentFailed: notification.notificationOccurred(.error)
        case .warning: notification.notificationOccurred(.warning)
        case .vpnConnected, .vpnSwitched, .purchaseCompleted, .authSuccess, .copied, .shared, .saved, .imported, .promoApplied, .refreshCompleted, .dataArrived: notification.notificationOccurred(.success)
        case .selection, .tabChanged, .swipeThreshold, .scrollTick: selection.selectionChanged()
        case .touchDown, .touchUp, .back, .sheetDismissed, .menuClosed, .toggleOff, .vpnDisconnected, .deleted, .deviceRemoved, .favoriteRemoved, .collapse, .paymentCancelled: impactSoft.impactOccurred(intensity:0.35)
        default: impactLight.impactOccurred(intensity:0.45)
        }
    }
    private func playPattern(_ pulses: [(time: TimeInterval, intensity: Float, sharpness: Float)], fallback: () -> Void) {
        guard let engine, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { fallback(); return }
        let events = pulses.map { pulse in CHHapticEvent(eventType:.hapticTransient, parameters:[CHHapticEventParameter(parameterID:.hapticIntensity,value:pulse.intensity),CHHapticEventParameter(parameterID:.hapticSharpness,value:pulse.sharpness)], relativeTime:pulse.time) }
        do { try engine.start(); let player = try engine.makePlayer(with: CHHapticPattern(events:events, parameters:[])); try player.start(atTime:CHHapticTimeImmediate) } catch { fallback() }
    }
}

public struct HapticButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response:0.18,dampingFraction:0.72), value:configuration.isPressed)
            .onChangeCompat(of:configuration.isPressed) { HapticManager.shared.play($0 ? .touchDown : .touchUp) }
    }
}
private struct HapticTouchSurfaceModifier: ViewModifier {
    @State private var didFireForGesture = false
    func body(content: Content) -> some View {
        content.simultaneousGesture(DragGesture(minimumDistance:0).onChanged { _ in
            guard !didFireForGesture else { return }; didFireForGesture = true; HapticManager.shared.play(.touchDown)
        }.onEnded { _ in didFireForGesture = false; HapticManager.shared.play(.touchUp) })
    }
}
private struct HapticScrollThresholdModifier: ViewModifier {
    @State private var crossedFirst = false; @State private var crossedSecond = false
    func body(content: Content) -> some View {
        content.simultaneousGesture(DragGesture(minimumDistance:12).onChanged { value in
            guard abs(value.translation.height) >= abs(value.translation.width) else { return }
            let distance = hypot(value.translation.width,value.translation.height)
            if distance > 44 && !crossedFirst { crossedFirst=true; HapticManager.shared.play(.swipeThreshold) }
            if distance > 128 && !crossedSecond { crossedSecond=true; HapticManager.shared.play(.swipeThreshold) }
        }.onEnded { _ in crossedFirst=false; crossedSecond=false })
    }
}

/// Dense rigid ticks while dragging a vertical list — feels like heavy scroll.
private struct HapticHeavyScrollModifier: ViewModifier {
    var step: CGFloat = 42
    @State private var lastTickDistance: CGFloat = 0

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    guard abs(value.translation.height) >= abs(value.translation.width) * 0.65 else { return }
                    let distance = abs(value.translation.height)
                    if distance - lastTickDistance >= step {
                        lastTickDistance = distance
                        HapticManager.shared.play(.scrollTick)
                    }
                }
                .onEnded { _ in
                    lastTickDistance = 0
                }
        )
    }
}

public extension View {
    func hapticTouchSurface() -> some View { modifier(HapticTouchSurfaceModifier()) }
    func hapticScrollThresholds() -> some View { modifier(HapticScrollThresholdModifier()) }
    func hapticHeavyScroll(step: CGFloat = 42) -> some View { modifier(HapticHeavyScrollModifier(step: step)) }
    func hapticToggle(_ value: Bool) -> some View { onChangeCompat(of:value) { HapticManager.shared.play($0 ? .toggleOn : .toggleOff) } }
    func hapticSelection<Value:Equatable>(_ value: Value) -> some View { onChangeCompat(of:value) { _ in HapticManager.shared.play(.selection) } }
}

#endif
