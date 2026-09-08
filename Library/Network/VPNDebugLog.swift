import Foundation

/// Tiny shared breadcrumb log in the App Group so we can pull it from the device.
public enum VPNDebugLog {
    private static var fileURL: URL {
        FilePath.workingDirectory.appendingPathComponent("vpn-debug.log")
    }

    public static func write(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        let data = Data(line.utf8)
        do {
            try FileManager.default.createDirectory(at: FilePath.workingDirectory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: fileURL, options: .atomic)
            }
        } catch {
            // Best-effort only.
        }
    }
}
