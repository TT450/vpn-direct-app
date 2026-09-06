import Foundation
import GRDB
import Libbox

public extension Profile {
    nonisolated func updateRemoteProfile() async throws {
        if type != .remote {
            return
        }
        let url = remoteURL
        guard let url, !url.isEmpty else { return }
        let normalized = try await SubscriptionConfigBuilder.fetchAndNormalize(url: url)
        let remoteContent = normalized.json
        let hostFallback = SubscriptionConfigBuilder.suggestedName(for: url)
        SubscriptionMetadataStore.save(normalized.metadata, profileID: mustID)
        if let fetchedName = normalized.name ?? normalized.metadata.title,
           !fetchedName.isEmpty,
           !SubscriptionConfigBuilder.isHostLikeName(fetchedName),
           SubscriptionConfigBuilder.isHostLikeName(name) || name.caseInsensitiveCompare(hostFallback) == .orderedSame
        {
            await MainActor.run {
                name = fetchedName
            }
        }
        await MainActor.run {
            lastUpdated = Date()
        }
        try await ProfileManager.update(self)
        do {
            let oldContent = try await readAsync()
            if oldContent == remoteContent {
                return
            }
        } catch {}
        try await writeAsync(remoteContent)
        try await onProfileUpdated()
    }

    nonisolated func onProfileUpdated() async throws {
        if await SharedPreferences.selectedProfileID.get() == id {
            if let profile = try? await ExtensionProfile.load() {
                if await profile.status == .connected {
                    try await profile.reloadService()
                }
            }
        }
    }
}
