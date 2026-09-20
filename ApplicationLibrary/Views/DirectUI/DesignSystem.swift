import SwiftUI
import UIKit

#if os(iOS)

enum DS {
    /// Soft light gray canvas — near-white, slightly cooler than pure white.
    static let paper = Color(red: 0.965, green: 0.965, blue: 0.968)
    static let ink = Color(red: 0.08, green: 0.09, blue: 0.08)
    static let panel = Color(red: 0.19, green: 0.21, blue: 0.18)
    static let muted = Color(red: 0.48, green: 0.50, blue: 0.46)
    static let line = Color.black.opacity(0.14)
    static let acid = Color(red: 0.66, green: 0.94, blue: 0.41)
    static let green = Color(red: 0.18, green: 0.55, blue: 0.31)
    static let danger = Color(red: 0.82, green: 0.24, blue: 0.20)
    static let pageTop: CGFloat = 24
    static let directEntrance = Animation.easeOut(duration: 0.28)
    static let directSpring = Animation.spring(response: 0.28, dampingFraction: 0.78)
    static let directValue = Animation.easeInOut(duration: 0.22)
}

extension View {
    func microLabel(color: Color = DS.muted) -> some View {
        self
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
    }

    func directRefreshable(enabled: Bool = true, action: @escaping () async -> Void) -> some View {
        modifier(DirectRefreshableModifier(enabled: enabled, action: action))
    }

    /// Subtle one-shot entrance for Direct components.
    func directEntrance(delay: Double = 0) -> some View {
        modifier(DirectEntranceModifier(delay: delay))
    }

    /// Short value/state settling animation for compact Direct UI values.
    func directValueAnimation<Value: Equatable>(_ value: Value) -> some View {
        animation(DS.directValue, value: value)
    }
}

private struct DirectRefreshableModifier: ViewModifier {
    let enabled: Bool
    let action: () async -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.refreshable {
                HapticManager.shared.play(.refreshStarted)
                await action()
                HapticManager.shared.play(.refreshCompleted)
            }
        } else {
            content
        }
    }
}

private struct DirectEntranceModifier: ViewModifier {
    let delay: Double
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 7)
            .onAppear {
                withAnimation(DS.directEntrance.delay(delay)) { visible = true }
            }
    }
}

struct Hairline: View {
    var color: Color = DS.line
    var body: some View { Rectangle().fill(color).frame(height: 1) }
}

/// In-card usage gauge for limited locations (not a row divider).
/// Fill grows with used/cap; solid color green→orange→red as remaining shrinks.
/// Sharp corners — matches Direct location cards (no capsule).
struct DirectLocationQuotaBar: View {
    /// Used fraction in `0…1`.
    let usedFraction: Double
    var height: CGFloat = 3

    private var clamped: Double {
        min(1, max(0, usedFraction.isFinite ? usedFraction : 0))
    }

    private var fillFraction: CGFloat {
        let t = CGFloat(clamped)
        if t <= 0 { return 0 }
        return max(t, 0.04)
    }

    var body: some View {
        GeometryReader { geo in
            let fillW = geo.size.width * fillFraction
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(DS.ink.opacity(0.10))
                Rectangle()
                    .fill(Self.color(usedFraction: clamped))
                    .frame(width: fillW)
            }
        }
        .frame(height: height)
        .accessibilityLabel("Использовано трафика")
        .accessibilityValue("\(Int((clamped * 100).rounded())) процентов")
    }

    /// Less remaining (higher used) → redder.
    static func color(usedFraction used: Double) -> Color {
        let t = CGFloat(min(1, max(0, used)))
        // Ease toward red sooner so mid-usage already reads warm.
        let eased = pow(t, 0.85)
        let green = UIColor(red: 0.18, green: 0.55, blue: 0.31, alpha: 1) // forest — not lime
        let amber = UIColor(red: 0.90, green: 0.55, blue: 0.14, alpha: 1)
        let red = UIColor(red: 0.82, green: 0.24, blue: 0.20, alpha: 1)
        let blended: UIColor
        if eased <= 0.45 {
            blended = Self.lerp(green, amber, eased / 0.45)
        } else {
            blended = Self.lerp(amber, red, (eased - 0.45) / 0.55)
        }
        return Color(blended)
    }

    private static func lerp(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let u = min(1, max(0, t))
        return UIColor(
            red: ar + (br - ar) * u,
            green: ag + (bg - ag) * u,
            blue: ab + (bb - ab) * u,
            alpha: aa + (ba - aa) * u
        )
    }
}

struct PageHeading: View {
    let kicker: String
    let title: String
    let subtitle: String
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(kicker).microLabel()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(DS.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .onAppear { withAnimation(DS.directEntrance) { appeared = true } }
    }
}

struct DarkStat: View {
    let label: String
    let value: String
    var compact = false
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).microLabel(color: .white.opacity(0.42))
            Text(value)
                .font(.system(size: compact ? 11 : 15, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.leading, 13)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .overlay(alignment: .leading) { Hairline(color: .white.opacity(0.12)).frame(width: 1) }
        .overlay(alignment: .top) { Hairline(color: .white.opacity(0.12)) }
        .overlay(alignment: .bottom) { Hairline(color: .white.opacity(0.12)) }
        .scaleEffect(appeared ? 1 : 0.985)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(DS.directEntrance.delay(0.04)) { appeared = true } }
    }
}

struct FlagImage: View {
    let code: String
    var width: CGFloat = 30
    var height: CGFloat = 20
    /// Shown in the black fallback square when no flag asset exists (e.g. «5G»).
    var fallbackLabel: String? = nil

    private static let imageCache = NSCache<NSString, UIImage>()
    private static let missToken = UIImage()

    var body: some View {
        let normalized = Self.normalizedCode(code)
        let name = "flag-\(normalized.lowercased())"
        Group {
            if let image = Self.cachedImage(named: name) {
                Image(uiImage: image).resizable().interpolation(.high).scaledToFill()
            } else {
                Text(Self.fallbackText(code: normalized, label: fallbackLabel))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DS.ink)
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .overlay(Rectangle().stroke(Color.black.opacity(0.12), lineWidth: 0.5))
    }

    private static func fallbackText(code: String, label: String?) -> String {
        if let label = label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            if label.uppercased().contains("5G") { return "5G" }
            return String(label.prefix(3)).uppercased()
        }
        return code.isEmpty ? "XX" : code
    }

    private static func normalizedCode(_ code: String) -> String {
        let upper = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if upper.isEmpty { return "XX" }
        return upper == "UK" ? "GB" : upper
    }

    private static func cachedImage(named name: String) -> UIImage? {
        let key = name as NSString
        if let cached = imageCache.object(forKey: key) { return cached === missToken ? nil : cached }
        if let image = loadImage(named: name) { imageCache.setObject(image, forKey: key); return image }
        imageCache.setObject(missToken, forKey: key)
        return nil
    }

    private static func loadImage(named name: String) -> UIImage? {
        let libraryBundle = Bundle(for: FlagImageBundleToken.self)
        var candidates: [Bundle] = [.main, libraryBundle]
        if let frameworks = Bundle.main.privateFrameworksURL {
            let appLib = frameworks.appendingPathComponent("ApplicationLibrary.framework")
            if let bundle = Bundle(url: appLib) { candidates.append(bundle) }
        }
        if let resourceURL = libraryBundle.resourceURL {
            let nested = resourceURL.appendingPathComponent("ApplicationLibrary.bundle")
            if let bundle = Bundle(url: nested) { candidates.insert(bundle, at: 0) }
        }
        for bundle in candidates {
            if let image = UIImage(named: name, in: bundle, compatibleWith: nil), image.size.width > 1 { return image }
        }
        return UIImage(named: name)
    }
}

private final class FlagImageBundleToken {}

#endif
