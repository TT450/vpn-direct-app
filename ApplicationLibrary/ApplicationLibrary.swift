import Foundation

public class ApplicationLibrary {
    public static let bundle = Bundle(for: ApplicationLibrary.self)

    /// Warm optional local Direct backend bindings (no-op without private hooks).
    public static func prepareDirectBackend() {
        #if os(iOS)
        DirectBackendRuntime.warmUp()
        #endif
    }
}
