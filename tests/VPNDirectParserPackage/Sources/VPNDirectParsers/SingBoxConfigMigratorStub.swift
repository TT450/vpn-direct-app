import Foundation
import Libbox

/// Test stub: production migrator also touches ProfileManager; parsers only need `migrate(_:)`.
public enum SingBoxConfigMigrator {
    public static func migrate(_ json: String) throws -> String {
        var error: NSError?
        LibboxCheckConfig(json, &error)
        if let error {
            throw error
        }
        return json
    }
}
