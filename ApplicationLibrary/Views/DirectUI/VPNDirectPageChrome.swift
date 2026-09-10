import SwiftUI
import Library

#if os(iOS)

/// Shared top chrome for the new VPN Direct root pages.
/// It intentionally reuses the project's existing DesignSystem/PageHeading
/// instead of introducing a second visual language.
struct VPNDirectPageAppBar<Trailing: View>: View {
    let kicker: String
    let title: String
    let subtitle: String
    let trailing: Trailing

    init(
        kicker: String,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.kicker = kicker
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PageHeading(
                kicker: kicker,
                title: title,
                subtitle: subtitle
            )

            trailing
        }
        .padding(.top, DS.pageTop)
        .padding(.bottom, 18)
    }
}

extension VPNDirectPageAppBar where Trailing == EmptyView {
    init(
        kicker: String,
        title: String,
        subtitle: String
    ) {
        self.init(
            kicker: kicker,
            title: title,
            subtitle: subtitle
        ) {
            EmptyView()
        }
    }
}

struct VPNDirectSquareButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.ink)
                .frame(width: 38, height: 38)
                .overlay(
                    Rectangle()
                        .stroke(DS.line, lineWidth: 1)
                )
        }
        .buttonStyle(HapticButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

struct VPNDirectSectionLabel: View {
    let number: String
    let title: String
    let meta: String?

    init(number: String = "", title: String, meta: String? = nil) {
        self.number = number
        self.title = title
        self.meta = meta
    }

    var body: some View {
        HStack(spacing: 9) {
            if !number.isEmpty {
                Text(number)
                    .microLabel(color: DS.green)
            }

            Text(title)
                .microLabel(color: DS.ink)

            Spacer(minLength: 8)

            if let meta {
                Text(meta)
                    .microLabel()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(minHeight: 40)
        .overlay(alignment: .top) {
            Hairline(color: DS.ink)
        }
    }
}

struct VPNDirectOutlineButton: View {
    let title: String
    let icon: String?
    let accent: Bool
    let action: () -> Void

    init(
        title: String,
        icon: String? = nil,
        accent: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.accent = accent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.35)

                Spacer(minLength: 5)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(accent ? DS.acid : DS.ink)
            .padding(.horizontal, 13)
            .frame(minHeight: 46)
            .background(accent ? DS.ink : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(accent ? DS.ink : DS.line, lineWidth: 1)
            )
        }
        .buttonStyle(HapticButtonStyle())
    }
}

#endif
