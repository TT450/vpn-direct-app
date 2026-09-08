import SwiftUI

enum AladdinWidgetTheme {
    static let navyTop = Color(red: 0.018, green: 0.028, blue: 0.075)
    static let navyBottom = Color(red: 0.045, green: 0.075, blue: 0.17)
    static let gold = Color(red: 0.98, green: 0.76, blue: 0.25)
    static let goldSoft = Color(red: 0.95, green: 0.70, blue: 0.20)

    @ViewBuilder
    static func background() -> some View {
        ZStack {
            LinearGradient(colors: [navyTop, navyBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(gold.opacity(0.08)).frame(width: 150, height: 150).blur(radius: 38).offset(x: 70, y: -65)
            Circle().stroke(gold.opacity(0.10), lineWidth: 1).frame(width: 180, height: 180).offset(x: -80, y: 80)
        }
    }
}

struct AladdinPowerMedallion: View {
    let connected: Bool
    let connecting: Bool

    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [AladdinWidgetTheme.gold.opacity(connected ? 0.20 : 0.08), .clear], center: .center, startRadius: 4, endRadius: 55))
            Circle().stroke(AladdinWidgetTheme.gold.opacity(connected ? 0.9 : 0.45), lineWidth: 2).frame(width: 70, height: 70)
            Circle().stroke(.white.opacity(0.10), lineWidth: 1).frame(width: 60, height: 60)
            if connecting {
                ProgressView().tint(AladdinWidgetTheme.gold)
            } else {
                Image(systemName: connected ? "checkmark" : "power")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(AladdinWidgetTheme.gold)
            }
        }
        .shadow(color: AladdinWidgetTheme.gold.opacity(connected ? 0.30 : 0.08), radius: 18)
    }
}

struct AladdinWidgetBackground<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        ZStack { AladdinWidgetTheme.background(); content() }
    }
}
