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
}

extension View {
    func microLabel(color: Color = DS.muted) -> some View {
        self
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(kicker).microLabel()
            Text(title).font(.system(size: 39, weight: .semibold))
            Text(subtitle).font(.system(size: 13)).foregroundStyle(DS.muted)
        }
    }
}

struct DarkStat: View {
    let label: String
    let value: String
    var compact = false

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
    }
}

/// Country flag from bundled PNG assets — never emoji.
struct FlagImage: View {
    let code: String
    var width: CGFloat = 30
    var height: CGFloat = 20

    var body: some View {
        let normalized = code.uppercased() == "UK" ? "GB" : code.uppercased()
        let name = "flag-\(normalized.lowercased())"
        Group {
            if let image = Self.loadImage(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                Text(normalized)
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

    private static func loadImage(named name: String) -> UIImage? {
        // App target now ships flag assets in Bundle.main (SFI/Assets.xcassets).
        // ApplicationLibrary is a staticlib — Bundle(for:) points at main, and the
        // library's Assets.car is NOT embedded in the app unless we also copy flags.
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
            if let image = UIImage(named: name, in: bundle, compatibleWith: nil), image.size.width > 1 {
                return image
            }
        }
        return UIImage(named: name)
    }
}

private final class FlagImageBundleToken {}

#endif
