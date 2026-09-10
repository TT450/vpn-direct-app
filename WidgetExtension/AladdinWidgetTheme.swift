import SwiftUI

// MARK: - Aladdin × TheTochka palette

enum AladdinWidgetTheme {
    // Deep TheTochka red
    static let redDeep = Color(red: 0.20, green: 0.015, blue: 0.025)
    static let red = Color(red: 0.72, green: 0.025, blue: 0.055)
    static let redBright = Color(red: 0.92, green: 0.055, blue: 0.085)

    // Aladdin gold
    static let gold = Color(red: 0.98, green: 0.73, blue: 0.25)
    static let goldBright = Color(red: 1.0, green: 0.84, blue: 0.42)

    static let white = Color.white
    static let secondaryText = Color.white.opacity(0.58)
    static let tertiaryText = Color.white.opacity(0.36)

    // MARK: Background

    @ViewBuilder
    static func background() -> some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: redDeep, location: 0),
                    .init(color: Color(red: 0.38, green: 0.015, blue: 0.035), location: 0.48),
                    .init(color: Color(red: 0.16, green: 0.008, blue: 0.018), location: 1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(redBright.opacity(0.18))
                .frame(width: 130, height: 130)
                .blur(radius: 38)
                .offset(x: 62, y: -58)

            Circle()
                .fill(gold.opacity(0.055))
                .frame(width: 110, height: 110)
                .blur(radius: 32)
                .offset(x: -55, y: 60)

            Circle()
                .stroke(gold.opacity(0.08), lineWidth: 1)
                .frame(width: 170, height: 170)
                .offset(x: 55, y: 65)
        }
        .clipped()
    }
}

// MARK: - Magical power button

struct AladdinPowerMedallion: View {
    let connected: Bool
    let connecting: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    connected
                        ? AladdinWidgetTheme.redBright.opacity(0.18)
                        : AladdinWidgetTheme.gold.opacity(0.055)
                )
                .frame(width: size, height: size)
                .blur(radius: size * 0.18)

            Circle()
                .stroke(
                    AladdinWidgetTheme.gold.opacity(connected ? 0.82 : 0.52),
                    lineWidth: max(1, size * 0.025)
                )
                .frame(width: size * 0.84, height: size * 0.84)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AladdinWidgetTheme.redBright.opacity(connected ? 0.72 : 0.30),
                            AladdinWidgetTheme.redDeep.opacity(0.95),
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: size * 0.38
                    )
                )
                .frame(width: size * 0.72, height: size * 0.72)

            Circle()
                .stroke(AladdinWidgetTheme.gold.opacity(0.28), lineWidth: 1)
                .frame(width: size * 0.62, height: size * 0.62)

            if connecting {
                ProgressView()
                    .tint(AladdinWidgetTheme.goldBright)
            } else {
                Image(systemName: connected ? "checkmark" : "power")
                    .font(.system(size: size * 0.22, weight: .bold))
                    .foregroundStyle(AladdinWidgetTheme.goldBright)
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .contentShape(Circle())
    }
}

// MARK: - Small status dot

struct AladdinStatusDot: View {
    let connected: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(connected ? Color.green : Color.white.opacity(0.32))
                .frame(width: 6, height: 6)

            Text(connected ? "ЗАЩИЩЕНО" : "НЕ ЗАЩИЩЕНО")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(AladdinWidgetTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }
}

// MARK: - Gold action

struct AladdinActionButton: View {
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
        .foregroundStyle(AladdinWidgetTheme.goldBright)
        .frame(maxWidth: .infinity)
        .frame(height: 30)
        .background(AladdinWidgetTheme.gold.opacity(0.10))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(AladdinWidgetTheme.gold.opacity(0.34), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}
