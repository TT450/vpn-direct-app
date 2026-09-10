import SwiftUI

#if os(iOS)

/// Branded animated splash shown after the system Launch Screen.
public struct SplashView: View {
    @State private var appeared = false
    @State private var progress: CGFloat = 0.08

    public init() {}

    public var body: some View {
        ZStack {
            DS.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("A / 01").microLabel(color: .white.opacity(0.35))
                    Spacer()
                    Text("PRIVATE NETWORK").microLabel(color: .white.opacity(0.35))
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        .frame(width: 176, height: 176)

                    Circle()
                        .trim(from: 0.03, to: progress)
                        .stroke(DS.acid, style: StrokeStyle(lineWidth: 2, lineCap: .square))
                        .frame(width: 176, height: 176)
                        .rotationEffect(.degrees(-90))

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1, height: 232)

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 232, height: 1)

                    Text("A")
                        .font(.system(size: 74, weight: .medium, design: .monospaced))
                        .foregroundStyle(DS.acid)
                        .offset(y: appeared ? 0 : 8)
                        .opacity(appeared ? 1 : 0)
                }

                VStack(spacing: 8) {
                    Text("VPN DIRECT")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(.white)
                    Text("PRIVATE NETWORK")
                        .microLabel(color: .white.opacity(0.42))
                }
                .padding(.top, 42)
                .opacity(appeared ? 1 : 0)

                Spacer()

                HStack(spacing: 8) {
                    Circle().fill(DS.acid).frame(width: 5, height: 5)
                    Text("ПОДГОТОВКА ЗАЩИЩЁННОГО КАНАЛА")
                        .microLabel(color: .white.opacity(0.46))
                }
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 1.65)) {
                progress = 0.97
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("VPN Direct запускается")
    }
}

/// Kept for call sites that still reference the old name.
public typealias LaunchScreenView = SplashView

#endif
