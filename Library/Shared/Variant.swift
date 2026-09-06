import Foundation
import Libbox

public enum Variant {
    #if os(macOS)
        public static var useSystemExtension = false
    #else
        public static let useSystemExtension = false
    #endif

    #if os(iOS)
        public static let applicationName = "VPN Direct"
    #elseif os(macOS)
        public static let applicationName = "VPN Direct"
    #elseif os(tvOS)
        public static let applicationName = "VPN Direct"
    #endif

    public static let isBeta = LibboxVersion().contains("-")

    #if DEBUG
        public static let inDebug = true
    #else
        public static let inDebug = false
    #endif

    #if os(iOS)
        public static var debugNoIOS26 = false
        public static var debugNoIOS18 = false
    #endif

    #if targetEnvironment(simulator)
        public static let screenshotMode = true
    #else
        public static let screenshotMode = ProcessInfo.processInfo.arguments.contains("-FASTLANE_SNAPSHOT")
    #endif
}
