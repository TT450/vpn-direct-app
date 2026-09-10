import Foundation
import Library

#if os(iOS)

enum DirectLocalProfileImporter {
    /// Import sing-box / Xray / Clash / WG / share-list content as a local profile.
    static func importContent(_ content: String, preferredName: String) async throws -> Profile {
        let normalized = try SubscriptionConfigBuilder.normalizeRemoteContent(content)
        let nextProfileID = try await ProfileManager.nextID()
        let directory = FilePath.sharedDirectory.appendingPathComponent("configs", isDirectory: true)
        let configURL = directory.appendingPathComponent("config_\(nextProfileID).json")

        try await BlockingIO.run {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try normalized.json.write(to: configURL, atomically: true, encoding: .utf8)
        }

        let fallbackName = normalized.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = rawName.isEmpty ? (fallbackName?.isEmpty == false ? fallbackName! : "Config") : rawName
        let uniqueName = try await ProfileManager.uniqueName(baseName)

        let profile = Profile(
            name: uniqueName,
            type: .local,
            path: configURL.relativePath,
            remoteURL: nil,
            autoUpdate: false,
            autoUpdateInterval: 60,
            lastUpdated: Date()
        )
        try await ProfileManager.create(profile)
        return profile
    }

    static func looksLikeConfigContent(_ raw: String) -> Bool {
        let detection = VPNDirectContentDetector.detect(text: raw)
        return detection.kind != .unknown && detection.kind != .recognizedUnsupported
    }
}

#endif
