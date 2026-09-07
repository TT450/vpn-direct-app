// swift-tools-version: 5.9
import PackageDescription

/// Standalone XCTest package for VPN Direct parsers/builders (no Xcode target required).
/// Library sources are symlinked under Sources/VPNDirectParsers (SPM forbids path outside package root).
/// Libbox is a test stub; SubscriptionMetadata / SubscriptionConfigBuilder are lightweight stubs.
/// Capabilities: set VPN_DIRECT_CAPABILITY_JSON (see Tests) for fail-open test probes.
let package = Package(
    name: "VPNDirectParserPackage",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "VPNDirectParsers", targets: ["VPNDirectParsers"]),
    ],
    targets: [
        .target(
            name: "Libbox",
            path: "Sources/Libbox"
        ),
        .target(
            name: "VPNDirectParsers",
            dependencies: ["Libbox"],
            path: "Sources/VPNDirectParsers"
        ),
        .testTarget(
            name: "VPNDirectParserTests",
            dependencies: ["VPNDirectParsers"],
            path: "Tests",
            exclude: ["README.md"]
        ),
    ]
)
