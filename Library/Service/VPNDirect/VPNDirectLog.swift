import Foundation
import OSLog

/// Categorized logging for VPN Direct subscription / core pipeline.
public enum VPNDirectLog {
    public static let subscription = Logger(subsystem: "com.vpndirect", category: "subscription")
    public static let parser = Logger(subsystem: "com.vpndirect", category: "parser")
    public static let normalizer = Logger(subsystem: "com.vpndirect", category: "normalizer")
    public static let builder = Logger(subsystem: "com.vpndirect", category: "builder")
    public static let validator = Logger(subsystem: "com.vpndirect", category: "validator")
    public static let core = Logger(subsystem: "com.vpndirect", category: "core")
    public static let tunnel = Logger(subsystem: "com.vpndirect", category: "tunnel")
    public static let dns = Logger(subsystem: "com.vpndirect", category: "dns")
    public static let network = Logger(subsystem: "com.vpndirect", category: "network")
    public static let interop = Logger(subsystem: "com.vpndirect", category: "interop")
}

/// Redacts secrets from log / debug strings.
public enum VPNDirectRedactor {
    private static let patterns: [(String, String)] = [
        (#"(?i)(uuid|id|password|passwd|pass|token|auth|authorization|private[_-]?key|preshared|psk|hwid|api[_-]?key)\s*[:=]\s*["']?[^"'&\s]+"#, "$1=***"),
        (#"(?i)(vless|vmess|trojan|ss|hysteria2?|hy2|tuic|anytls)://[^\s]+"#, "$1://***"),
        (#"Bearer\s+[A-Za-z0-9\-._~+/]+=*"#, "Bearer ***"),
    ]

    public static func redact(_ input: String) -> String {
        var output = input
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(output.startIndex..<output.endIndex, in: output)
                output = regex.stringByReplacingMatches(in: output, range: range, withTemplate: replacement)
            }
        }
        return output
    }
}
