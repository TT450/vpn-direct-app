import Foundation
import Libbox
import Library
import SwiftUI

@MainActor
public final class NewProfileViewModel: BaseViewModel {
    @Published public var isSaving = false
    @Published public var createSucceeded = false
    @Published public var profileName = ""
    #if !os(tvOS)
        @Published public var profileType = ProfileType.local
    #else
        @Published public var profileType = ProfileType.remote
    #endif
    @Published public var fileImport = false
    @Published public var fileURL: URL?
    @Published public var remotePath = ""
    @Published public var autoUpdate = true
    @Published public var autoUpdateInterval: Int32 = 60
    @Published public var pickerPresented = false

    public let isImport: Bool

    public init(importRequest: NewProfileView.ImportRequest? = nil, localImportRequest: NewProfileView.LocalImportRequest? = nil) {
        isImport = importRequest != nil
        super.init()
        if let importRequest {
            profileName = importRequest.name
            profileType = .remote
            remotePath = importRequest.url
        } else if let localImportRequest {
            profileName = localImportRequest.name
            profileType = .local
            fileImport = true
            fileURL = localImportRequest.fileURL
        }
    }

    public func resetFields() {
        profileName = ""
        profileType = .local
        fileImport = false
        fileURL = nil
        remotePath = ""
    }

    public func createProfile(
        environments: ExtensionEnvironments,
        dismiss: DismissAction? = nil,
        onSuccess: ((Profile) async -> Void)? = nil,
        sendUpdateNotification: Bool = true
    ) async {
        defer { isSaving = false }

        let isVLESS = VLESSConfigBuilder.isVLESSLink(remotePath)
        let isShareLink = SubscriptionConfigBuilder.isShareLinkContent(remotePath)
        let isSubscriptionURL = SubscriptionConfigBuilder.isHTTPURL(remotePath)

        if (isVLESS || isShareLink || isSubscriptionURL), profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Name is filled from the link / host during parse.
        } else if profileName.isEmpty {
            alert = AlertState(errorMessage: String(localized: "Missing profile name"))
            return
        }

        if !isVLESS, !isShareLink, !isSubscriptionURL, profileType == .icloud, remotePath.isEmpty {
            alert = AlertState(errorMessage: String(localized: "Missing path"))
            return
        }

        if !isVLESS, !isShareLink, !isSubscriptionURL, profileType == .remote, remotePath.isEmpty {
            alert = AlertState(errorMessage: String(localized: "Missing URL"))
            return
        }

        let createdProfile: Profile
        do {
            createdProfile = try await createProfileBackground()
        } catch {
            alert = AlertState(action: "create profile", error: error)
            return
        }

        if let onSuccess {
            await onSuccess(createdProfile)
        }
        if sendUpdateNotification {
            environments.profileUpdate.send()
        }
        createSucceeded = true
        dismiss?()

        #if os(macOS)
            resetFields()
        #endif
    }

    private nonisolated func createProfileBackground() async throws -> Profile {
        let nextProfileID = try await ProfileManager.nextID()

        var savePath = ""
        var remoteURL: String?
        var lastUpdated: Date?

        let profileName = await profileName
        let profileType = await profileType
        let fileImport = await fileImport
        let fileURL = await fileURL
        let remotePath = await remotePath
        let autoUpdate = await autoUpdate
        let autoUpdateInterval = await autoUpdateInterval

        if VLESSConfigBuilder.isVLESSLink(remotePath) {
            let parsed = try VLESSConfigBuilder.parse(remotePath)
            var resolvedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
            if resolvedName.isEmpty {
                resolvedName = parsed.name
            }
            let profileConfigDirectory = FilePath.sharedDirectory.appendingPathComponent("configs", isDirectory: true)
            let profileConfig = profileConfigDirectory.appendingPathComponent("config_\(nextProfileID).json")
            try await BlockingIO.run {
                try FileManager.default.createDirectory(at: profileConfigDirectory, withIntermediateDirectories: true)
                try parsed.json.write(to: profileConfig, atomically: true, encoding: .utf8)
            }
            savePath = profileConfig.relativePath
            let uniqueProfileName = try await ProfileManager.uniqueName(resolvedName.isEmpty ? "VLESS" : resolvedName)
            let profile = Profile(
                name: uniqueProfileName,
                type: .local,
                path: savePath,
                remoteURL: nil,
                autoUpdate: false,
                autoUpdateInterval: autoUpdateInterval,
                lastUpdated: nil
            )
            try await ProfileManager.create(profile)
            return profile
        } else if SubscriptionConfigBuilder.isShareLinkContent(remotePath) {
            let links = SubscriptionConfigBuilder.decodeShareLinks(remotePath)
            let built = try SubscriptionConfigBuilder.buildConfig(from: links)
            var resolvedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
            if resolvedName.isEmpty {
                resolvedName = built.name
                    ?? SubscriptionConfigBuilder.suggestedName(forShareContent: remotePath)
            }
            let profileConfigDirectory = FilePath.sharedDirectory.appendingPathComponent("configs", isDirectory: true)
            let profileConfig = profileConfigDirectory.appendingPathComponent("config_\(nextProfileID).json")
            try await BlockingIO.run {
                try FileManager.default.createDirectory(at: profileConfigDirectory, withIntermediateDirectories: true)
                try built.json.write(to: profileConfig, atomically: true, encoding: .utf8)
            }
            savePath = profileConfig.relativePath
            let uniqueProfileName = try await ProfileManager.uniqueName(resolvedName.isEmpty ? "Share link" : resolvedName)
            let profile = Profile(
                name: uniqueProfileName,
                type: .local,
                path: savePath,
                remoteURL: nil,
                autoUpdate: false,
                autoUpdateInterval: autoUpdateInterval,
                lastUpdated: nil
            )
            try await ProfileManager.create(profile)
            return profile
        } else if SubscriptionConfigBuilder.isHTTPURL(remotePath) || profileType == .remote {
            let sourceURL = remotePath
            let normalized = try await SubscriptionConfigBuilder.fetchAndNormalize(url: sourceURL)
            let hostFallback = SubscriptionConfigBuilder.suggestedName(for: sourceURL)
            var resolvedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
            if let fetchedName = normalized.name ?? normalized.metadata.title, !fetchedName.isEmpty {
                if resolvedName.isEmpty || resolvedName.caseInsensitiveCompare(hostFallback) == .orderedSame || SubscriptionConfigBuilder.isHostLikeName(resolvedName) {
                    resolvedName = fetchedName
                }
            } else if resolvedName.isEmpty {
                resolvedName = hostFallback
            }
            let profileConfigDirectory = FilePath.sharedDirectory.appendingPathComponent("configs", isDirectory: true)
            let profileConfig = profileConfigDirectory.appendingPathComponent("config_\(nextProfileID).json")
            try await BlockingIO.run {
                try FileManager.default.createDirectory(at: profileConfigDirectory, withIntermediateDirectories: true)
                try normalized.json.write(to: profileConfig, atomically: true, encoding: .utf8)
            }
            savePath = profileConfig.relativePath
            remoteURL = sourceURL
            lastUpdated = .now

            let uniqueProfileName = try await ProfileManager.uniqueName(resolvedName.isEmpty ? "Subscription" : resolvedName)
            let profile = Profile(
                name: uniqueProfileName,
                type: .remote,
                path: savePath,
                remoteURL: remoteURL,
                autoUpdate: autoUpdate,
                autoUpdateInterval: autoUpdateInterval,
                lastUpdated: lastUpdated
            )
            try await ProfileManager.create(profile)
            SubscriptionMetadataStore.save(normalized.metadata, profileID: profile.mustID)
            #if os(iOS) || os(tvOS)
                try UIProfileUpdateTask.configure()
            #else
                try await ProfileUpdateTask.configure()
            #endif
            return profile
        } else if profileType == .local {
            let profileConfigDirectory = FilePath.sharedDirectory.appendingPathComponent("configs", isDirectory: true)
            let profileConfig = profileConfigDirectory.appendingPathComponent("config_\(nextProfileID).json")
            try await BlockingIO.run {
                try FileManager.default.createDirectory(at: profileConfigDirectory, withIntermediateDirectories: true)
                if fileImport {
                    guard let fileURL else {
                        throw NSError(domain: "NewProfileViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "Missing file")])
                    }
                    try fileURL.withRequiredSecurityScopedAccess(
                        or: NSError(domain: "NewProfileViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "Missing access to selected file")])
                    ) {
                        let raw = try String(contentsOf: fileURL, encoding: .utf8)
                        // Prefer VPN Direct normalize (.ovpn / OpenConnect / Tailscale / share JSON).
                        // Fall back to raw write only for opaque Libbox profile JSON that already validates.
                        if let normalized = try? SubscriptionConfigBuilder.normalizeRemoteContent(raw) {
                            try normalized.json.write(to: profileConfig, atomically: true, encoding: .utf8)
                        } else {
                            try raw.write(to: profileConfig, atomically: true, encoding: .utf8)
                        }
                    }
                } else {
                    try "{}".write(to: profileConfig, atomically: true, encoding: .utf8)
                }
            }
            savePath = profileConfig.relativePath
        } else if profileType == .icloud {
            let iCloudDirectory = FilePath.iCloudDirectory
            try await BlockingIO.run {
                if !FileManager.default.fileExists(atPath: iCloudDirectory.path) {
                    try FileManager.default.createDirectory(at: iCloudDirectory, withIntermediateDirectories: true)
                }
                let saveURL = iCloudDirectory.appendingPathComponent(remotePath, isDirectory: false)
                do {
                    _ = try String(contentsOf: saveURL)
                } catch {
                    try "{}".write(to: saveURL, atomically: true, encoding: .utf8)
                }
            }
            savePath = remotePath
        }

        let uniqueProfileName = try await ProfileManager.uniqueName(profileName.isEmpty ? "Profile" : profileName)

        // Create Profile object - GRDB will set its ID after insertion
        let profile = Profile(
            name: uniqueProfileName,
            type: profileType,
            path: savePath,
            remoteURL: remoteURL,
            autoUpdate: profileType == .remote ? autoUpdate : false,
            autoUpdateInterval: autoUpdateInterval,
            lastUpdated: lastUpdated
        )
        try await ProfileManager.create(profile)

        // Return the profile object which now has its ID set by GRDB
        return profile
    }
}
