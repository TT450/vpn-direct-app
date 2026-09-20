import SwiftUI

// MARK: - Direct widget palette (matches DesignSystem: paper / ink / acid)

enum DirectWidgetTheme {
    static let paper = Color(red: 0.93, green: 0.94, blue: 0.91)
    static let ink = Color(red: 0.08, green: 0.09, blue: 0.08)
    static let acid = Color(red: 0.66, green: 0.94, blue: 0.41)
    static let muted = Color(red: 0.08, green: 0.09, blue: 0.08).opacity(0.45)

    static let white = Color.white
    static let secondaryText = Color.white.opacity(0.58)
    static let tertiaryText = Color.white.opacity(0.36)

    @ViewBuilder
    static func background() -> some View {
        ZStack {
            ink
            LinearGradient(
                stops: [
                    .init(color: ink, location: 0),
                    .init(color: Color(red: 0.12, green: 0.14, blue: 0.12), location: 0.55),
                    .init(color: ink, location: 1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(acid.opacity(0.12))
                .frame(width: 130, height: 130)
                .blur(radius: 38)
                .offset(x: 62, y: -58)
            Circle()
                .fill(paper.opacity(0.06))
                .frame(width: 110, height: 110)
                .blur(radius: 32)
                .offset(x: -55, y: 60)
        }
        .clipped()
    }
}

struct DirectPowerMedallion: View {
    let connected: Bool
    let connecting: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(connected ? DirectWidgetTheme.acid.opacity(0.18) : DirectWidgetTheme.paper.opacity(0.08))
                .frame(width: size, height: size)
                .blur(radius: size * 0.18)

            Circle()
                .stroke(
                    DirectWidgetTheme.acid.opacity(connected ? 0.90 : 0.42),
                    lineWidth: max(1, size * 0.025)
                )
                .frame(width: size * 0.84, height: size * 0.84)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            DirectWidgetTheme.ink.opacity(0.2),
                            DirectWidgetTheme.ink,
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: size * 0.38
                    )
                )
                .frame(width: size * 0.72, height: size * 0.72)

            Circle()
                .stroke(DirectWidgetTheme.acid.opacity(0.28), lineWidth: 1)
                .frame(width: size * 0.62, height: size * 0.62)

            if connecting {
                ProgressView()
                    .tint(DirectWidgetTheme.acid)
            } else {
                Image(systemName: connected ? "checkmark" : "power")
                    .font(.system(size: size * 0.22, weight: .bold))
                    .foregroundStyle(DirectWidgetTheme.acid)
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .contentShape(Circle())
    }
}

struct DirectStatusDot: View {
    let connected: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(connected ? DirectWidgetTheme.acid : Color.white.opacity(0.32))
                .frame(width: 6, height: 6)

            Text(connected ? "ЗАЩИЩЕНО" : "НЕ ЗАЩИЩЕНО")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(DirectWidgetTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }
}

struct DirectActionButton: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(DirectWidgetTheme.acid)
        .frame(maxWidth: .infinity)
        .frame(height: 30)
        .background(DirectWidgetTheme.acid.opacity(0.10))
        .overlay {
            Rectangle()
                .stroke(DirectWidgetTheme.acid.opacity(0.34), lineWidth: 1)
        }
    }
}
