import Foundation
import SwiftUI

#if !os(iOS)
public struct LaunchScreenView: View {
    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("VPN Direct")
                .font(.title2.bold())
                .foregroundColor(.white)
        }
    }
}
#endif
