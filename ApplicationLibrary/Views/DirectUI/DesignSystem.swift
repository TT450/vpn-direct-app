import SwiftUI
import UIKit

#if os(iOS)

enum DS {
    static let paper = Color(red: 0.93, green: 0.94, blue: 0.91)
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

    private static let imageCache = NSCache<NSString, UIImage>()
    private static let missToken = UIImage()

    var body: some View {
        let normalized = Self.normalizedCode(code)
        let name = "flag-\(normalized.lowercased())"
        Group {
            if let image = Self.cachedImage(named: name) {
                Image(uiImage: image).resizable().interpolation(.high).scaledToFill()
            } else {
                Text(normalized.isEmpty ? "XX" : normalized)
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
