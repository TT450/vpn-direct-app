import Foundation
import SwiftUI

public struct SponsorsView: View {
    public init() {}

    public var body: some View {
        FormView {
            Section {
                Text("VPN Direct")
                    .font(.headline)
                Text("Быстрый VPN")
                    .foregroundStyle(.secondary)
            } header: {
                Text("About")
            } footer: {
                Text("Open-source VPN Direct client (GPLv3).")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("About")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
