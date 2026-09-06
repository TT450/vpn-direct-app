import Foundation
import Libbox

/// Builds a sing-box 1.13+ JSON config from a standard `vless://` share link.
/// Accepts any host / transport / security (TLS, Reality, WS, gRPC, etc.).
/// Does not require `vpndirect://` or any vendor-specific scheme.
public enum VLESSConfigBuilder {
    public struct Result {
        public let name: String
        public let uuid: String
        public let json: String
    }

    public struct OutboundResult {
        public let name: String
        public let uuid: String
        public let outbound: [String: Any]
    }

    public static func parse(_ raw: String) throws -> Result {
        let parsed = try parseOutbound(raw, tag: "proxy")
        let json = try wrapSingleOutbound(parsed.outbound)
        return Result(name: parsed.name, uuid: parsed.uuid, json: json)
    }

    public static func parseOutbound(_ raw: String, tag: String) throws -> OutboundResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("vless://") else {
            throw VLESSError.unsupportedScheme
        }

        // Fragment is the node name. Never feed it into query parsing — otherwise
        // Reality short_id becomes "abc#Name" and Libbox fails hex decode.
        let fragmentName = extractFragment(from: trimmed)
        let linkBody = trimmed.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? trimmed

        guard let components = URLComponents(string: linkBody) ?? {
            guard let encoded = linkBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
            return URLComponents(string: encoded)
        }() else {
            throw VLESSError.invalidURL
        }

        let uuid = components.user ?? ""
        guard !uuid.isEmpty else { throw VLESSError.missingUUID }

        let host = components.host ?? ""
        guard !host.isEmpty else { throw VLESSError.missingHost }

        let port = components.port ?? 443
        let query = Query(components.queryItems ?? [])

        let transportType = clean(query["type"] ?? query["network"] ?? "tcp").lowercased()
        let security = clean(query["security"] ?? "none").lowercased()
        let sni = clean(query["sni"] ?? query["host"] ?? host)
        let flow = cleanOptional(query["flow"])
        let alpn = cleanOptional(query["alpn"])?
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let fingerprint = cleanOptional(query["fp"])
        let path = cleanOptional(query["path"])
        let hostHeader = cleanOptional(query["host"])
        let serviceName = cleanOptional(query["serviceName"]) ?? cleanOptional(query["service_name"])

        var outbound: [String: Any] = [
            "type": "vless",
            "tag": tag,
            "server": host,
            "server_port": port,
            "uuid": uuid,
            "packet_encoding": clean(query["packetEncoding"] ?? "xudp"),
        ]

        if let flow, !flow.isEmpty {
            outbound["flow"] = flow
        }

        // VLESS encryption / PQ layer (extensible string; independent of TLS/REALITY).
        if let encryption = cleanOptional(query["encryption"]), !encryption.isEmpty, encryption.lowercased() != "none" {
            outbound["encryption"] = encryption
        }

        if security == "tls" || security == "reality" {
            var tls: [String: Any] = [
                "enabled": true,
                "server_name": sni,
                "insecure": query["allowInsecure"] == "1" || query["allowInsecure"] == "true",
            ]
            if let alpn, !alpn.isEmpty {
                tls["alpn"] = alpn
            }
            if let fingerprint, !fingerprint.isEmpty {
                tls["utls"] = [
                    "enabled": true,
                    "fingerprint": fingerprint,
                ]
            }
            if security == "reality" {
                var reality: [String: Any] = [
                    "enabled": true,
                ]
                if let pbk = cleanOptional(query["pbk"]), !pbk.isEmpty {
                    reality["public_key"] = pbk
                }
                // Reality short_id must be hex (0-16 bytes). Drop invalid leftovers.
                if let sid = cleanOptional(query["sid"]) {
                    let hex = String(sid.filter(\.isHexDigit))
                    if !hex.isEmpty {
                        reality["short_id"] = hex
                    }
                }
                tls["reality"] = reality
            }
            outbound["tls"] = tls
        }

        if let transport = buildTransport(type: transportType, path: path, host: hostHeader, serviceName: serviceName, query: query) {
            outbound["transport"] = transport
        }

        let name = fragmentName?.removingPercentEncoding ?? fragmentName ?? host
        return OutboundResult(name: name.isEmpty ? host : name, uuid: uuid, outbound: outbound)
    }

    private static func clean(_ value: String) -> String {
        value.components(separatedBy: "#").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? value
    }

    private static func cleanOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = clean(value)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func wrapSingleOutbound(_ outbound: [String: Any]) throws -> String {
        let config: [String: Any] = [
            "log": [
                "level": "info",
                "timestamp": true,
            ],
            "dns": [
                "servers": [
                    [
                        "type": "udp",
                        "tag": "dns-remote",
                        "server": "1.1.1.1",
                    ],
                    [
                        "type": "local",
                        "tag": "dns-local",
                    ],
                ],
                "final": "dns-remote",
                "strategy": "prefer_ipv4",
            ],
            "inbounds": [
                [
                    "type": "tun",
                    "tag": "tun-in",
                    "address": ["172.19.0.1/30"],
                    "mtu": 9000,
                    "auto_route": true,
                    "strict_route": true,
                    "stack": "gvisor",
                ],
            ],
            "outbounds": [
                outbound,
                [
                    "type": "direct",
                    "tag": "direct",
                ],
            ],
            "route": [
                "auto_detect_interface": true,
                "default_domain_resolver": [
                    "server": "dns-remote",
                    "strategy": "prefer_ipv4",
                ],
                "rules": [
                    [
                        "action": "sniff",
                    ],
                    [
                        "protocol": ["dns"],
                        "action": "hijack-dns",
                    ],
                    [
                        "ip_is_private": true,
                        "outbound": "direct",
                    ],
                ],
                "final": "proxy",
            ],
        ]

        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else {
            throw VLESSError.serializationFailed
        }

        var error: NSError?
        LibboxCheckConfig(json, &error)
        if let error {
            throw error
        }
        return try SingBoxConfigMigrator.migrate(json)
    }

    public static func isVLESSLink(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("vless://")
    }

    private static func buildTransport(type: String, path: String?, host: String?, serviceName: String?, query: Query) -> [String: Any]? {
        switch type {
        case "ws", "websocket":
            var transport: [String: Any] = ["type": "ws"]
            if let path, !path.isEmpty {
                transport["path"] = path
            }
            if let host, !host.isEmpty {
                transport["headers"] = ["Host": host]
            }
            return transport
        case "httpupgrade":
            var transport: [String: Any] = ["type": "httpupgrade"]
            if let path, !path.isEmpty {
                transport["path"] = path
            }
            if let host, !host.isEmpty {
                transport["host"] = host
            }
            return transport
        case "grpc":
            var transport: [String: Any] = ["type": "grpc"]
            if let serviceName, !serviceName.isEmpty {
                transport["service_name"] = serviceName
            }
            return transport
        case "http", "h2":
            var transport: [String: Any] = ["type": "http"]
            if let path, !path.isEmpty {
                transport["path"] = [path]
            }
            if let host, !host.isEmpty {
                transport["host"] = [host]
            }
            return transport
        case "xhttp", "splithttp":
            // Native XHTTP when Core supports it; otherwise degrade to httpupgrade.
            let useNativeXHTTP = VPNDirectCoreCapabilities.current.supportsXHTTP
            var transport: [String: Any] = [
                "type": useNativeXHTTP ? "xhttp" : "httpupgrade",
            ]
            if let path, !path.isEmpty {
                transport["path"] = path
            }
            if let host, !host.isEmpty {
                transport["host"] = host
            }
            if useNativeXHTTP {
                let mode = cleanOptional(query["mode"]) ?? "auto"
                transport["mode"] = mode
                if let extra = cleanOptional(query["extra"]) {
                    transport["extra"] = extra
                }
            } else if let mode = query["mode"], !mode.isEmpty {
                transport["headers"] = ["X-HTTP-Mode": mode]
            }
            return transport
        case "tcp", "raw", "":
            if query["headerType"] == "http" {
                var transport: [String: Any] = ["type": "http"]
                if let path, !path.isEmpty {
                    transport["path"] = [path]
                }
                if let host, !host.isEmpty {
                    transport["host"] = [host]
                }
                return transport
            }
            return nil
        default:
            return nil
        }
    }

    private static func extractFragment(from link: String) -> String? {
        guard let index = link.lastIndex(of: "#") else { return nil }
        let value = String(link[link.index(after: index)...])
        return value.isEmpty ? nil : value
    }

    private struct Query {
        private let map: [String: String]
        init(_ items: [URLQueryItem]) {
            var dict: [String: String] = [:]
            for item in items {
                if let value = item.value {
                    dict[item.name] = value
                }
            }
            map = dict
        }

        subscript(_ key: String) -> String? {
            map[key]
        }
    }

    public enum VLESSError: LocalizedError {
        case unsupportedScheme
        case invalidURL
        case missingUUID
        case missingHost
        case serializationFailed

        public var errorDescription: String? {
            switch self {
            case .unsupportedScheme:
                return "Only vless:// links are supported"
            case .invalidURL:
                return "Invalid VLESS URL"
            case .missingUUID:
                return "VLESS link is missing UUID"
            case .missingHost:
                return "VLESS link is missing host"
            case .serializationFailed:
                return "Failed to serialize configuration"
            }
        }
    }
}
