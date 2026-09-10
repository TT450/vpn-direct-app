import Foundation

/// Maps 3x-ui / Xray client `mux` and `streamSettings.finalmask` onto sing-box fields.
///
/// - Mux → sing-box `multiplex` (enabled + max_connections from Xray concurrency).
/// - Finalmask for Hysteria is handled in `HysteriaOutboundFactory` (obfs).
/// - Finalmask TCP `tlshello`/`fragment` → TLS fragment options when mappable.
/// - Unrecognized connection-critical finalmask → fail closed (`nil` conversion).
enum XrayMuxAndMask {
    enum ApplyResult {
        case ok
        /// Caller must abort conversion (unsupported connection-critical mask).
        case unsupported(String)
    }

    /// Apply outbound-level mux and stream finalmask into a sing-box outbound dict.
    static func apply(from xray: [String: Any], into outbound: inout [String: Any]) -> ApplyResult {
        if let muxResult = applyMux(from: xray, into: &outbound), case .unsupported(let d) = muxResult {
            return .unsupported(d)
        }
        let stream = (xray["streamSettings"] as? [String: Any]) ?? [:]
        if let mask = stream["finalmask"] as? [String: Any], !mask.isEmpty {
            return applyFinalMask(mask, into: &outbound)
        }
        // Legacy 3x-ui fragment/noises as sockopt-adjacent stream keys.
        if let fragment = stream["fragment"] as? [String: Any], !fragment.isEmpty {
            return applyLegacyFragment(fragment, into: &outbound)
        }
        return .ok
    }

    private static func applyMux(from xray: [String: Any], into outbound: inout [String: Any]) -> ApplyResult? {
        guard let mux = xray["mux"] as? [String: Any] else { return nil }
        let enabled: Bool
        if let b = mux["enabled"] as? Bool {
            enabled = b
        } else if let n = mux["enabled"] as? NSNumber {
            enabled = n.boolValue
        } else {
            // Present but not clearly enabled — treat as connection-critical unknown shape.
            return .unsupported("xray.mux: missing/invalid enabled")
        }
        guard enabled else { return .ok }

        // XHTTP xmux is transport-local; outbound mux + xmux together is ambiguous.
        if let transport = outbound["transport"] as? [String: Any],
           (transport["type"] as? String)?.lowercased() == "xhttp",
           transport["xmux"] != nil
        {
            return .unsupported("xray.mux: conflicts with XHTTP xmux")
        }

        var multiplex: [String: Any] = ["enabled": true]
        if let concurrency = mux["concurrency"] as? Int, concurrency > 0 {
            multiplex["max_connections"] = concurrency
        } else if let concurrency = mux["concurrency"] as? NSNumber, concurrency.intValue > 0 {
            multiplex["max_connections"] = concurrency.intValue
        }
        // Xray-only UDP mux knobs have no 1:1 sing-box multiplex field — fail closed if set.
        if mux["xudpConcurrency"] != nil || mux["xudpProxyUDP443"] != nil {
            return .unsupported("xray.mux: xudpConcurrency/xudpProxyUDP443 not expressible in sing-box multiplex")
        }
        outbound["multiplex"] = multiplex
        return .ok
    }

    private static func applyFinalMask(_ mask: [String: Any], into outbound: inout [String: Any]) -> ApplyResult {
        let type = ((outbound["type"] as? String) ?? "").lowercased()
        // Hysteria path already consumes finalmask as obfs; if we got here on hy outbound, skip.
        if type == "hysteria" || type == "hysteria2" {
            return .ok
        }

        var mappedSomething = false
        if let tcp = mask["tcp"] as? [[String: Any]] {
            for entry in tcp {
                let t = ((entry["type"] as? String) ?? "").lowercased()
                switch t {
                case "tlshello", "fragment":
                    let settings = (entry["settings"] as? [String: Any]) ?? [:]
                    var tls = (outbound["tls"] as? [String: Any]) ?? ["enabled": true]
                    if let packets = settings["packets"] as? String, !packets.isEmpty {
                        tls["fragment"] = true
                        // Preserve range as opaque string for Core if it accepts delay range later.
                        if let length = settings["length"] as? String, !length.isEmpty {
                            tls["fragment_fallback_delay"] = length
                        }
                        outbound["tls"] = tls
                        mappedSomething = true
                    } else if settings.isEmpty {
                        var tls = (outbound["tls"] as? [String: Any]) ?? ["enabled": true]
                        tls["fragment"] = true
                        outbound["tls"] = tls
                        mappedSomething = true
                    } else {
                        return .unsupported("finalmask.tcp.\(t): unrecognized settings")
                    }
                case "", "none":
                    continue
                default:
                    return .unsupported("finalmask.tcp: unsupported type \(t)")
                }
            }
        }

        if let udp = mask["udp"] as? [[String: Any]], !udp.isEmpty {
            // UDP noise/mask is not expressible on VLESS/VMess/Trojan sing-box outbounds.
            return .unsupported("finalmask.udp: not supported for \(type)")
        }
        if let quic = mask["quic"] as? [String: Any], !quic.isEmpty {
            return .unsupported("finalmask.quic: not supported for \(type)")
        }
        if let quicParams = mask["quicParams"] as? [String: Any], !quicParams.isEmpty {
            return .unsupported("finalmask.quicParams: not supported for \(type)")
        }

        if mappedSomething || mask.isEmpty {
            return .ok
        }
        // Unknown top-level finalmask keys.
        let known: Set<String> = ["tcp", "udp", "quic", "quicParams"]
        let unknown = Set(mask.keys).subtracting(known)
        if !unknown.isEmpty {
            return .unsupported("finalmask: unknown keys \(unknown.sorted().joined(separator: ","))")
        }
        return .ok
    }

    private static func applyLegacyFragment(_ fragment: [String: Any], into outbound: inout [String: Any]) -> ApplyResult {
        var tls = (outbound["tls"] as? [String: Any]) ?? ["enabled": true]
        tls["fragment"] = true
        if let length = fragment["length"] as? String, !length.isEmpty {
            tls["fragment_fallback_delay"] = length
        }
        outbound["tls"] = tls
        return .ok
    }

    /// Encode multiplex object for attribute flatten / rebuild.
    static func multiplexAttrJSON(_ multiplex: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(multiplex),
              let data = try? JSONSerialization.data(withJSONObject: multiplex),
              let s = String(data: data, encoding: .utf8)
        else { return nil }
        return s
    }

    static func multiplexFromAttrs(_ attrs: [String: String]) -> [String: Any]? {
        guard let raw = attrs["multiplex_json"], !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }
}
