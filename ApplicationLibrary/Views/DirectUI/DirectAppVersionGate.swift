import Foundation

#if os(iOS)

/// Marketing version + CFBundleVersion for force-update gates.
public struct DirectAppBuildIdentity: Comparable, Equatable, Sendable {
    public let versionComponents: [Int]
    public let build: Int
    public let displayLabel: String

    public init(version: String, build: Int) {
        let parts = version
            .split(separator: ".")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        versionComponents = parts.isEmpty ? [0] : parts
        self.build = max(0, build)
        displayLabel = "\(version) (\(self.build))"
    }

    public static func current() -> DirectAppBuildIdentity {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let buildRaw = (info?["CFBundleVersion"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let build = Int(buildRaw ?? "") ?? 0
        return DirectAppBuildIdentity(version: version?.isEmpty == false ? version! : "0", build: build)
    }

    public static func < (lhs: DirectAppBuildIdentity, rhs: DirectAppBuildIdentity) -> Bool {
        let count = max(lhs.versionComponents.count, rhs.versionComponents.count)
        for i in 0..<count {
            let a = i < lhs.versionComponents.count ? lhs.versionComponents[i] : 0
            let b = i < rhs.versionComponents.count ? rhs.versionComponents[i] : 0
            if a != b { return a < b }
        }
        return lhs.build < rhs.build
    }
}

public struct DirectForceUpdateRequirement: Equatable, Sendable {
    public let currentLabel: String
    public let requiredLabel: String
    public let updateURL: URL

    public init(currentLabel: String, requiredLabel: String, updateURL: URL) {
        self.currentLabel = currentLabel
        self.requiredLabel = requiredLabel
        self.updateURL = updateURL
    }
}

/// Evaluates catalog ios_min_* fields against the running binary.
public enum DirectAppVersionGate {
    public static let defaultUpdateURL = URL(string: "https://apps.apple.com/app/id6807402257")!

    public static func evaluate(catalog: DirectAppCatalog?) -> DirectForceUpdateRequirement? {
        guard let catalog else { return nil }
        // Admin "force_update" must be on — otherwise catalog still exposes min_* for soft use.
        guard catalog.iosForceUpdate else { return nil }
        let minVersion = catalog.iosMinVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !minVersion.isEmpty else { return nil }

        let minBuild = max(0, catalog.iosMinBuild ?? 0)
        let minimum = DirectAppBuildIdentity(version: minVersion, build: minBuild)
        let current = DirectAppBuildIdentity.current()
        // Example: min 1.0.12 (1) blocks 1.0.11 (112); 1.0.12 (1) and newer pass.
        guard current < minimum else { return nil }

        let latestVersion = catalog.iosLatestVersion?.trimmingCharacters(in: .whitespacesAndNewlines)
        let latestBuild = catalog.iosLatestBuild
        let required: DirectAppBuildIdentity
        if let latestVersion, !latestVersion.isEmpty {
            required = DirectAppBuildIdentity(version: latestVersion, build: max(0, latestBuild ?? 0))
        } else {
            required = minimum
        }

        let urlString = catalog.iosUpdateURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let url = URL(string: urlString) ?? defaultUpdateURL
        return DirectForceUpdateRequirement(
            currentLabel: current.displayLabel,
            requiredLabel: required.displayLabel,
            updateURL: url
        )
    }
}

#endif
