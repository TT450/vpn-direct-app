import Foundation
import Library

#if os(iOS)

public enum AutoSubscriptionImporter {
    public static func normalizeImportURL(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = value.lowercased()
        for prefix in ["happ://add/", "incy://add/", "vpndirect://add/", "streisand://import/"] {
            if lower.hasPrefix(prefix) {
                value = String(value.dropFirst(prefix.count))
                if let decoded = value.removingPercentEncoding, !decoded.isEmpty {
                    value = decoded
                }
                break
            }
        }
        if let url = URL(string: value),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let target = components.queryItems?.first(where: { $0.name == "target" })?.value,
           let decoded = target.removingPercentEncoding
        {
            return normalizeImportURL(decoded)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func importIfNeeded(url: String, environments: ExtensionEnvironments) async throws -> Profile? {
        let normalized = normalizeImportURL(url)
        guard VLESSConfigBuilder.isVLESSLink(normalized)
            || SubscriptionConfigBuilder.isShareLinkContent(normalized)
            || SubscriptionConfigBuilder.isHTTPURL(normalized)
        else {
            return nil
        }

        let profiles = try await ProfileManager.list()
        if let existing = profiles.first(where: { ($0.remoteURL ?? "").caseInsensitiveCompare(normalized) == .orderedSame }) {
            await SharedPreferences.selectedProfileID.set(existing.mustID)
            await MainActor.run {
                environments.selectedProfileUpdate.send()
            }
            return existing
        }

        let viewModel = await MainActor.run { NewProfileViewModel(importRequest: .init(name: "", url: normalized)) }
        return try await importWithViewModel(viewModel, environments: environments)
    }

    @MainActor
    public static func importWithViewModel(_ viewModel: NewProfileViewModel, environments: ExtensionEnvironments) async throws -> Profile {
        var created: Profile?
        await viewModel.createProfile(environments: environments, dismiss: nil, onSuccess: { profile in
            created = profile
            await SharedPreferences.selectedProfileID.set(profile.mustID)
        }, sendUpdateNotification: true)
        if let created { return created }
        if let alert = viewModel.alert {
            throw NSError(domain: "AutoSubscriptionImporter", code: -1, userInfo: [
                NSLocalizedDescriptionKey: alert.message,
            ])
        }
        throw NSError(domain: "AutoSubscriptionImporter", code: -1, userInfo: [
            NSLocalizedDescriptionKey: String(localized: "Не удалось добавить подписку"),
        ])
    }
}

#endif
