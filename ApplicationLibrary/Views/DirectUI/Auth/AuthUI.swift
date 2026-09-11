import SwiftUI
import UIKit

#if os(iOS)

struct AuthPageShell<Content: View>: View {
    let kicker: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(kicker: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.kicker = kicker
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(kicker: kicker, title: title, subtitle: subtitle)
                    .padding(.top, DS.pageTop)
                    .padding(.bottom, 24)
                content
                Spacer(minLength: 28)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
        }
        .background(DS.paper.ignoresSafeArea())
        .preferredColorScheme(.light)
        .buttonStyle(HapticButtonStyle())
    }
}

struct AuthField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).microLabel(color: DS.ink)
            TextField(placeholder, text: $text)
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
                .padding(.horizontal, 13)
                .frame(height: 50)
                .background(Color.white.opacity(0.45))
                .overlay(Rectangle().stroke(DS.line))
        }
    }
}

struct AuthPasswordField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @Binding var revealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).microLabel(color: DS.ink)
            HStack(spacing: 10) {
                Group {
                    if revealed {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button {
                    revealed.toggle()
                } label: {
                    Image(systemName: revealed ? "eye.slash" : "eye")
                        .foregroundStyle(DS.muted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 13)
            .frame(height: 50)
            .background(Color.white.opacity(0.45))
            .overlay(Rectangle().stroke(DS.line))
        }
    }
}

struct AuthPrimaryButton: View {
    let title: String
    var icon: String? = "arrow.right"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if let icon {
                    Image(systemName: icon)
                }
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(DS.acid)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(DS.ink)
        }
        .buttonStyle(HapticButtonStyle())
    }
}

struct AuthSecondaryButton: View {
    let title: String
    var icon: String? = nil
    /// Asset catalog image name (preferred for brand logos).
    var assetIcon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                authLeadingIcon
                    .frame(width: 24, height: 24)
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.muted)
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(DS.ink)
            .padding(.horizontal, 13)
            .frame(height: 48)
            .background(Color.white.opacity(0.45))
            .overlay(Rectangle().stroke(DS.line))
        }
        .buttonStyle(HapticButtonStyle())
    }

    @ViewBuilder
    private var authLeadingIcon: some View {
        if let assetIcon, let uiImage = AuthBrandImage.uiImage(named: assetIcon) {
            Image(uiImage: uiImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                // Optical match: Apple silhouette reads smaller than Google/Telegram discs.
                .scaleEffect(assetIcon.contains("apple") ? 1.12 : 1.0)
        } else if let icon {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
        }
    }
}

enum AuthBrandImage {
    static func uiImage(named name: String) -> UIImage? {
        let libraryBundle = Bundle(for: AuthBrandImageBundleToken.self)
        var candidates: [Bundle] = [.main, libraryBundle, ApplicationLibrary.bundle]
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

private final class AuthBrandImageBundleToken {}

struct AuthDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            Hairline()
            Text("ИЛИ").microLabel(color: DS.muted)
            Hairline()
        }
        .padding(.vertical, 12)
    }
}

struct AuthErrorText: View {
    let message: String?
    init(_ message: String?) { self.message = message }
    var body: some View {
        if let message, !message.isEmpty {
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AuthCheckoutCard: View {
    let checkout: PendingCheckout
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("ЗАКАЗ СОХРАНЁН").microLabel(color: DS.acid)
            Text(checkout.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            HStack {
                Text("\(checkout.periodDays) дней")
                Spacer()
                Text("\(checkout.price) ₽").fontWeight(.semibold)
            }
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.55))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.panel)
        .padding(.bottom, 8)
    }
}

#endif
