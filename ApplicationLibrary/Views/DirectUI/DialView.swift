import SwiftUI

#if os(iOS)

struct DialView: View {
    let isConnected: Bool
    let isBusy: Bool
    let action: () -> Void

    private let outerRadius: CGFloat = 132
    private let ringGapStart: CGFloat = 0.915
    private let ringGapEnd: CGFloat = 0.085
    private let dialBlue = Color(red: 0.28, green: 0.55, blue: 0.98)

    var body: some View {
        ZStack {
            // Gap on the right (3 o'clock) — no rotation.
            Circle()
                .trim(from: ringGapEnd, to: ringGapStart)
                .stroke(
                    isConnected ? DS.ink : DS.ink.opacity(0.14),
                    style: StrokeStyle(lineWidth: 2, lineCap: .butt)
                )

            Text("OFF")
                .font(.system(size: 9, weight: isConnected ? .medium : .bold, design: .monospaced))
                .foregroundStyle(isConnected ? DS.muted : DS.ink)
                .offset(x: -58, y: outerRadius + 14)

            Text("ON")
                .font(.system(size: 9, weight: isConnected ? .bold : .medium, design: .monospaced))
                .foregroundStyle(isConnected ? DS.ink : DS.muted)
                .offset(x: 58, y: outerRadius + 14)

            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(DS.ink)
                        .overlay(
                            Circle()
                                .strokeBorder(dialBlue.opacity(0.9), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 18, y: 9)

                    VStack(spacing: 5) {
                        Text("A / 01").microLabel(color: .white.opacity(0.48))
                        Text(isBusy ? "•••" : isConnected ? "ON" : "OFF")
                            .font(.system(size: 40, weight: .medium, design: .rounded))
                            .foregroundStyle(isConnected ? DS.acid : .white.opacity(0.82))
                        if isConnected {
                            Text("Нажмите, чтобы отключить")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        } else {
                            VStack(spacing: 1) {
                                Text("Нажмите, чтобы")
                                Text("подключить")
                            }
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                        }
                    }

                    Capsule()
                        .fill(isConnected ? DS.acid : Color.white.opacity(0.55))
                        .frame(width: 3, height: 26)
                        .offset(y: -78)
                        .rotationEffect(.degrees(isConnected ? 132 : -132))
                        .animation(.easeInOut(duration: 0.55), value: isConnected)
                }
                .frame(width: 180, height: 180)
            }
            .buttonStyle(HapticButtonStyle())
            // Keep dial tappable while connecting so user can cancel a hung start.
        }
        .frame(width: 264, height: 290)
        .accessibilityLabel(isConnected ? "Отключить VPN" : "Подключить VPN")
    }
}

#endif
