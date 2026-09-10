import Foundation

/// Typed JSON value for lossless raw/future extensions (REQ-P027 / #69).
/// Prefer this over string flattening for arrays/objects that may be connection-critical.
public enum VPNDirectJSONValue: Equatable, Sendable, Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([VPNDirectJSONValue])
    case object([String: VPNDirectJSONValue])
    case null

    public static func fromJSONObject(_ any: Any?) -> VPNDirectJSONValue {
        guard let any else { return .null }
        switch any {
        case is NSNull:
            return .null
        case let b as Bool:
            return .bool(b)
        case let n as NSNumber:
            // Distinguish Bool boxed as NSNumber.
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                return .bool(n.boolValue)
            }
            return .number(n.doubleValue)
        case let s as String:
            return .string(s)
        case let a as [Any]:
            return .array(a.map { fromJSONObject($0) })
        case let d as [String: Any]:
            return .object(d.mapValues { fromJSONObject($0) })
        default:
            return .string(String(describing: any))
        }
    }

    public var stringValue: String? {
        if case let .string(s) = self { return s }
        return nil
    }

    public var boolValue: Bool? {
        if case let .bool(b) = self { return b }
        return nil
    }

    public var numberValue: Double? {
        if case let .number(n) = self { return n }
        return nil
    }

    /// Lossy string for CompatibilityFieldPolicy key scans / legacy attrs.
    public var flattenedString: String {
        switch self {
        case .null:
            return ""
        case let .string(s):
            return s
        case let .number(n):
            if n.rounded() == n { return String(Int(n)) }
            return String(n)
        case let .bool(b):
            return b ? "1" : "0"
        case let .array(items):
            return items.map(\.flattenedString).joined(separator: ",")
        case let .object(obj):
            if let data = try? JSONSerialization.data(withJSONObject: obj.mapValues(\.jsonObject), options: [.sortedKeys]),
               let s = String(data: data, encoding: .utf8)
            {
                return s
            }
            return String(describing: obj)
        }
    }

    public var jsonObject: Any {
        switch self {
        case .null: return NSNull()
        case let .string(s): return s
        case let .number(n): return n
        case let .bool(b): return b
        case let .array(a): return a.map(\.jsonObject)
        case let .object(o): return o.mapValues(\.jsonObject)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? c.decode(Int.self) {
            self = .number(Double(i))
        } else if let d = try? c.decode(Double.self) {
            self = .number(d)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([VPNDirectJSONValue].self) {
            self = .array(a)
        } else if let o = try? c.decode([String: VPNDirectJSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case let .string(s): try c.encode(s)
        case let .number(n): try c.encode(n)
        case let .bool(b): try c.encode(b)
        case let .array(a): try c.encode(a)
        case let .object(o): try c.encode(o)
        }
    }
}
