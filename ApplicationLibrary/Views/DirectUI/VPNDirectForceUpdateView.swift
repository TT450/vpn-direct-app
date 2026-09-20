import SwiftUI
import UIKit

#if os(iOS)

/// Blocking force-update gate — no dismiss, no back, CTA opens App Store / update URL.
public struct VPNDirectForceUpdateView: View {
    public let currentVersion: String
    public let requiredVersion: String
    public let updateURL: URL

    public init(currentVersion: String, requiredVersion: String, updateURL: URL) {
        self.currentVersion = currentVersion
        self.requiredVersion = requiredVersion
        self.updateURL = updateURL
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(hex: "#EEEFEb").ignoresSafeArea()
                ForceUpdateGridBackground().ignoresSafeArea()
                ForceUpdateRedField()
                    .frame(width: 275, height: 365)
                    .position(x: geometry.size.width - 40, y: 100)

                VStack(spacing: 0) {
                    header
                    hero
                    visual
                    versionBlock
                    updateButton
                    Text("ОБНОВЛЕНИЕ ОБЯЗАТЕЛЬНО")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .kerning(1)
                        .foregroundColor(Color(hex: "#818681"))
                        .padding(.top, 9)
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.top, 54)
                .padding(.bottom, 21)
            }
        }
        .ignoresSafeArea(.keyboard)
        .interactiveDismissDisabled(true)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 10) {
                    ForceUpdateVPNLogo()
                    VStack(alignment: .leading, spacing: 3) {
                        Text("VPN DIRECT")
                            .font(.system(size: 14, weight: .bold))
                            .kerning(0.3)
                            .foregroundColor(Color(hex: "#111313"))
                        Text("PRIVATE NETWORK")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .kerning(1)
                            .foregroundColor(Color(hex: "#747875"))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("VPN / 01")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#111313"))
                    Text("SYSTEM UPDATE")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#7D817D"))
                }
            }
            Rectangle()
                .fill(Color(hex: "#C7C9C4"))
                .frame(height: 1)
                .padding(.top, 17)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Rectangle()
                    .fill(Color(hex: "#E21D2B"))
                    .frame(width: 5, height: 34)
                Text("ОБНОВЛЕНИЕ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .kerning(1.1)
                    .foregroundColor(Color(hex: "#E21D2B"))
            }
            Text("Обновите\nприложение")
                .font(.system(size: 39, weight: .bold))
                .kerning(-1.9)
                .foregroundColor(Color(hex: "#111313"))
                .lineSpacing(-2)
                .padding(.top, 16)
            Text(
                "Доступна новая версия VPN Direct. " +
                "Установите последнее обновление, чтобы " +
                "продолжить пользоваться приложением."
            )
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(Color(hex: "#707571"))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 28)
    }

    private var visual: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "#111313"), lineWidth: 1)
                .frame(width: 178, height: 178)
            Circle()
                .stroke(Color(hex: "#111313").opacity(0.45), lineWidth: 1)
                .frame(width: 238, height: 238)
            Circle()
                .trim(from: 0.00, to: 0.23)
                .stroke(Color(hex: "#E21D2B"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 238, height: 238)
                .rotationEffect(.degrees(-32))
            Circle()
                .fill(Color(hex: "#111313"))
                .frame(width: 118, height: 118)
            VStack(spacing: 2) {
                Text("↓")
                    .font(.system(size: 27, weight: .medium))
                    .foregroundColor(Color(hex: "#E21D2B"))
                Text("NEW VERSION")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .kerning(0.9)
                    .foregroundColor(Color(hex: "#8B908C"))
            }
            .frame(width: 118, height: 118)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 5)
    }

    private var versionBlock: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("ТЕКУЩАЯ")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .kerning(0.8)
                    .foregroundColor(Color(hex: "#858985"))
                Text(currentVersion)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#111313"))
            }
            Spacer()
            Text("→")
                .font(.system(size: 19, weight: .regular))
                .foregroundColor(Color(hex: "#7B807C"))
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text("ДОСТУПНА")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .kerning(0.8)
                    .foregroundColor(Color(hex: "#E21D2B"))
                Text(requiredVersion)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#E21D2B"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(Color.white.opacity(0.26))
        .overlay(Rectangle().stroke(Color(hex: "#C7C9C4"), lineWidth: 1))
        .padding(.bottom, 13)
    }

    private var updateButton: some View {
        Button {
            UIApplication.shared.open(updateURL)
        } label: {
            HStack {
                Text("ОБНОВИТЬ ПРИЛОЖЕНИЕ")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("↗")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 19)
            .frame(height: 61)
            .background(Color(hex: "#E21D2B"))
            .cornerRadius(2)
            .shadow(color: Color(hex: "#E21D2B").opacity(0.18), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack {
            Text("VPN DIRECT")
                .kerning(0.6)
            Spacer()
            Text("FAST VPN")
                .kerning(0.6)
        }
        .font(.system(size: 8, weight: .medium, design: .monospaced))
        .foregroundColor(Color(hex: "#858984"))
        .padding(.top, 17)
    }
}

private struct ForceUpdateVPNLogo: View {
    var body: some View {
        Group {
            if let image = Self.loadAppIcon() {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                Color(hex: "#111313")
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color(hex: "#C7C9C4"), lineWidth: 1)
        )
        .accessibilityLabel("VPN Direct")
    }

    private static func loadAppIcon() -> UIImage? {
        let libraryBundle = Bundle(for: ForceUpdateLogoBundleToken.self)
        var candidates: [Bundle] = [ApplicationLibrary.bundle, libraryBundle, .main]
        if let frameworks = Bundle.main.privateFrameworksURL {
            let appLib = frameworks.appendingPathComponent("ApplicationLibrary.framework")
            if let bundle = Bundle(url: appLib) { candidates.append(bundle) }
        }
        if let resourceURL = libraryBundle.resourceURL {
            let nested = resourceURL.appendingPathComponent("ApplicationLibrary.bundle")
            if let bundle = Bundle(url: nested) { candidates.insert(bundle, at: 0) }
        }
        for name in ["DirectAppIcon", "AppIcon"] {
            for bundle in candidates {
                if let image = UIImage(named: name, in: bundle, compatibleWith: nil), image.size.width > 1 {
                    return image
                }
            }
            if let image = UIImage(named: name), image.size.width > 1 {
                return image
            }
        }
        // Last resort: primary icon from the host app Info.plist.
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String] {
            for file in files.reversed() {
                if let image = UIImage(named: file), image.size.width > 1 {
                    return image
                }
            }
        }
        return nil
    }
}

private final class ForceUpdateLogoBundleToken {}

private struct ForceUpdateRedField: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(hex: "#E21D2B")
                Color(hex: "#FF3341")
                    .frame(width: 135, height: 165)
                    .position(x: proxy.size.width - 67, y: 82)
                    .opacity(0.7)
            }
            .mask(
                Path { path in
                    path.move(to: CGPoint(x: 110, y: 0))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: 0))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
                    path.addLine(to: CGPoint(x: proxy.size.width * 0.62, y: proxy.size.height * 0.82))
                    path.addLine(to: CGPoint(x: 0, y: proxy.size.height * 0.55))
                    path.closeSubpath()
                }
            )
        }
    }
}

private struct ForceUpdateGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 44
            var vertical = Path()
            var x: CGFloat = 0
            while x <= size.width {
                vertical.move(to: CGPoint(x: x, y: 0))
                vertical.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            context.stroke(vertical, with: .color(Color(hex: "#111313").opacity(0.045)), lineWidth: 1)
            var horizontal = Path()
            var y: CGFloat = 0
            while y <= size.height {
                horizontal.move(to: CGPoint(x: 0, y: y))
                horizontal.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(horizontal, with: .color(Color(hex: "#111313").opacity(0.045)), lineWidth: 1)
        }
    }
}

#endif
