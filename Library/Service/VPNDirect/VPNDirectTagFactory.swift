import Foundation

enum VPNDirectTagFactory {
    static func uniqueTag(from name: String, fallback: String, used: inout Set<String>) -> String {
        var base = name
            .replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
            .replacingOccurrences(of: #"[^A-Za-z0-9._\-а-яА-ЯёЁ]"#, with: "", options: .regularExpression)
        while base.hasPrefix("-") {
            base = String(base.dropFirst())
        }
        while base.hasSuffix("-") {
            base = String(base.dropLast())
        }
        if base.isEmpty {
            base = fallback
        }
        if base.count > 48 {
            base = String(base.prefix(48))
        }
        var tag = base
        var index = 2
        while used.contains(tag) || tag == "proxy" || tag == "direct" || tag == "auto" {
            tag = "\(base)-\(index)"
            index += 1
        }
        used.insert(tag)
        return tag
    }
}
