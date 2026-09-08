import CryptoKit
import Foundation

/// Remnawave / Happ XRAY_JSON → NormalizedSubscription (TheTochka location semantics).
///
/// Converted leaf outbounds are flattened into `NormalizedNode.attributes` and rebuilt by
/// `UniversalOutboundBuilder` (no LEGACY `outbound` attachment for new Xray imports).
public enum XrayJSONAdapter {
    public static func parse(_ content: String) throws -> NormalizedSubscription {
        guard let data = content.data(using: .utf8) else {
            throw SubscriptionConfigBuilder.SubscriptionError.xrayJSONUnsupported
        }
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw SubscriptionConfigBuilder.SubscriptionError.xrayJSONUnsupported
        }

        let profiles: [[String: Any]]
        if let arr = root as? [[String: Any]] {
            // Distinguish profile wrappers (`outbounds`/`remarks`) from a bare outbound list
            // (3x-ui one-client JSON array of proxy objects with top-level `protocol`).
            let looksLikeOutboundList = !arr.isEmpty && arr.allSatisfy { item in
                let proto = ((item["protocol"] as? String) ?? "").lowercased()
                return !proto.isEmpty && item["outbounds"] == nil
            }
            if looksLikeOutboundList {
                profiles = [["remarks": "Server 1", "outbounds": arr]]
            } else {
                profiles = arr
            }
        } else if let obj = root as? [String: Any] {
            // Top-level Xray / 3x-ui object (single profile or outbounds wrapper).
            if obj["outbounds"] != nil || obj["protocol"] != nil || obj["remarks"] != nil {
                profiles = [obj]
            } else {
                throw SubscriptionConfigBuilder.SubscriptionError.xrayJSONUnsupported
            }
        } else {
            throw SubscriptionConfigBuilder.SubscriptionError.xrayJSONUnsupported
        }

        var locations: [NormalizedLocation] = []
        var firstName: String?
        var allImportWarnings: [String] = []

        for (index, profile) in profiles.enumerated() {
            let remarks = ((profile["remarks"] as? String) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = remarks.isEmpty ? "Server \(index + 1)" : remarks

            if isTrafficStub(displayName) {
                continue
            }

            // Profile may itself be a single flat outbound (`protocol` + settings, no `outbounds`).
            let xrayOutbounds: [[String: Any]]
            if let nested = profile["outbounds"] as? [[String: Any]], !nested.isEmpty {
                xrayOutbounds = nested
            } else if let proto = profile["protocol"] as? String, !proto.isEmpty {
                xrayOutbounds = [profile]
            } else {
                xrayOutbounds = []
            }
            var convertFailures: [String] = []
            let helperProtocols: Set<String> = [
                "freedom", "blackhole", "dns", "dokodemo-door", "direct", "block",
            ]
            var proxyOutbounds: [[String: Any]] = []
            for outbound in xrayOutbounds {
                let proto = ((outbound["protocol"] as? String) ?? "").lowercased()
                let tag = ((outbound["tag"] as? String) ?? "").lowercased()
                if helperProtocols.contains(proto) || tag == "direct" || tag == "block" || tag == "dns" {
                    continue
                }
                let supported: Set<String> = [
                    "vless", "hysteria", "hysteria2", "vmess", "trojan",
                    "shadowsocks", "ss", "socks", "http", "wireguard",
                ]
                if supported.contains(proto) {
                    proxyOutbounds.append(outbound)
                } else if !proto.isEmpty {
                    let label = (outbound["tag"] as? String) ?? proto
                    convertFailures.append("unsupported_protocol:\(proto):\(label)")
                }
            }

            let routing = (profile["routing"] as? [String: Any]) ?? [:]
            let balancers = (routing["balancers"] as? [[String: Any]]) ?? []

            let ordered = proxyOutbounds.sorted { lhs, rhs in
                let lt = (lhs["tag"] as? String) ?? ""
                let rt = (rhs["tag"] as? String) ?? ""
                if lt == "proxy" { return true }
                if rt == "proxy" { return false }
                return false
            }

            var endpoints: [NormalizedNode] = []
            var xrayTagToIndex: [String: Int] = [:]
            var pendingDialers: [(endpointIndex: Int, xrayDialer: String)] = []
            // Dedupe only within this profile/location — never globally across countries.
            var seenServersInProfile = Set<String>()
            // convertFailures may already contain unsupported_protocol diagnostics.

            for (entryIndex, xray) in ordered.enumerated() {
                let xrayTag = ((xray["tag"] as? String) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let fallbackTag = "loc-\(index + 1)-\(entryIndex + 1)"
                let proto = ((xray["protocol"] as? String) ?? "").lowercased()

                let converted: [String: Any]?
                if proto == "vless" {
                    converted = XrayVLESSConverter.convert(xray, fallbackTag: fallbackTag)
                } else if proto == "hysteria" || proto == "hysteria2" {
                    converted = HysteriaOutboundFactory.fromXray(xray, fallbackTag: fallbackTag)
                } else {
                    converted = XrayLeafConverter.convert(xray, fallbackTag: fallbackTag)
                }
                guard let outbound = converted else {
                    let label = xrayTag.isEmpty ? fallbackTag : xrayTag
                    convertFailures.append("\(proto):\(label)")
                    VPNDirectLog.parser.warning("\(VPNDirectRedactor.redact("xray_convert_failed protocol=\(proto) tag=\(label)"))")
                    continue
                }
                let type = (outbound["type"] as? String) ?? proto
                let server = (outbound["server"] as? String) ?? ""
                let port = outbound["server_port"] as? Int ?? 0
                var detourXray: String?
                if let dialer = xrayDialerProxyTag(xray) {
                    detourXray = dialer
                }
                if EndpointValidator.isBlockedLoopbackHost(server) {
                    let label = xrayTag.isEmpty ? fallbackTag : xrayTag
                    convertFailures.append("loopback:\(label)")
                    continue
                }
                let fingerprint = leafFingerprint(outbound, detour: detourXray)
                if !seenServersInProfile.insert(fingerprint).inserted {
                    continue
                }

                // TheTochka/Happ: single-leaf profiles keep remarks as the UI name (flags/labels).
                // Multi-leaf profiles prefer the Xray tag, else a stable remarks suffix (not "-n1").
                let leafName: String
                if ordered.count == 1 {
                    leafName = displayName
                } else if !xrayTag.isEmpty {
                    leafName = xrayTag
                } else {
                    leafName = "\(displayName)-\(entryIndex + 1)"
                }

                var attributes = flattenOutboundFields(outbound)
                var rawExtensions: [String: String] = [:]
                if !xrayTag.isEmpty { attributes["xrayTag"] = xrayTag }
                // Preserve streamSettings keys the converters may not map yet.
                // Skip finalmask/fragment dumps when already mapped to tls_fragment* / multiplex.
                let mappedTLSFragment = attributes["tls_fragment"] == "1"
                let mappedMultiplex = attributes["multiplex"] == "1"
                if let stream = xray["streamSettings"] as? [String: Any] {
                    for (k, v) in flattenJSON(stream, prefix: "stream") {
                        let lower = k.lowercased()
                        if mappedTLSFragment,
                           lower.hasPrefix("stream.finalmask") || lower == "stream.fragment"
                            || lower.hasPrefix("stream.fragment.")
                        {
                            continue
                        }
                        if mappedMultiplex, lower.hasPrefix("stream.mux") {
                            continue
                        }
                        if attributes[k] == nil {
                            switch CompatibilityFieldPolicy.classify(key: k, value: v) {
                            case .harmlessMetadata, .panelMetadata, .futureField:
                                rawExtensions[k] = v
                            case .protocolExtension, .connectionCritical:
                                // Keep for builder; fail closed later if still unconsumed at emit.
                                rawExtensions[k] = v
                                attributes[k] = v
                            }
                        }
                    }
                }
                if let settings = xray["settings"] as? [String: Any] {
                    for (k, v) in flattenJSON(settings, prefix: "settings") {
                        rawExtensions[k] = v
                    }
                }

                let node = NormalizedNode(
                    name: leafName,
                    protocolID: VPNDirectProtocolID(rawValue: type),
                    server: server,
                    port: port,
                    transport: transportID(from: outbound),
                    security: securityID(from: outbound),
                    uuid: outbound["uuid"] as? String,
                    attributes: attributes,
                    rawExtensions: rawExtensions,
                    outbound: nil,
                    detour: detourXray
                )
                if !xrayTag.isEmpty {
                    xrayTagToIndex[xrayTag] = endpoints.count
                }
                if let dialer = detourXray {
                    pendingDialers.append((endpoints.count, dialer))
                }
                endpoints.append(node)
            }

            // Resolve dialerProxy Xray tags → sibling endpoint names (later remapped to sing-box tags).
            for hook in pendingDialers {
                guard let targetIndex = xrayTagToIndex[hook.xrayDialer],
                      endpoints.indices.contains(hook.endpointIndex),
                      endpoints.indices.contains(targetIndex)
                else { continue }
                endpoints[hook.endpointIndex].detour = endpoints[targetIndex].name
            }

            // Prefer Hysteria leaves first inside the location.
            endpoints.sort { a, b in
                let ah = a.protocolID == .hysteria || a.protocolID == .hysteria2
                let bh = b.protocolID == .hysteria || b.protocolID == .hysteria2
                if ah == bh { return false }
                return ah && !bh
            }

            // Topology-aware: independent convert failures warn via empty skip; abort only if nothing left.
            // Balancer-referenced missing leaves are handled inside applyBalancers (selector match).
            if endpoints.isEmpty {
                if !convertFailures.isEmpty {
                    let preview = convertFailures.prefix(8).joined(separator: ",")
                    throw VPNDirectCoreError.unsupportedFeature(
                        component: "xray.\(displayName)",
                        detail: "lost all leaves: \(preview)"
                    )
                }
                continue
            }
            if !convertFailures.isEmpty {
                let preview = convertFailures.prefix(12).joined(separator: ", ")
                allImportWarnings.append(
                    "Imported \(endpoints.count) leaf(s) for \(displayName); rejected \(convertFailures.count): \(preview)"
                )
            }

            let kind: NormalizedLocationKind = isGlobalAutoName(displayName) ? .globalAuto : .country
            let (filtered, strategy) = try applyBalancers(
                balancers: balancers,
                endpoints: endpoints,
                locationName: displayName
            )
            endpoints = filtered

            locations.append(
                NormalizedLocation(
                    id: "profile-\(index + 1)",
                    name: displayName,
                    kind: kind,
                    strategy: strategy,
                    endpoints: endpoints
                )
            )
            if firstName == nil {
                firstName = displayName
            }
        }

        guard !locations.isEmpty else {
            throw SubscriptionConfigBuilder.SubscriptionError.noSupportedLinks
        }

        return NormalizedSubscription(
            name: firstName,
            locations: locations,
            importWarnings: allImportWarnings
        )
    }

    /// Rich within-profile leaf key (no raw secrets — hashed uuid/password/pbk).
    private static func leafFingerprint(_ outbound: [String: Any], detour: String?) -> String {
        let type = (outbound["type"] as? String) ?? ""
        let server = (outbound["server"] as? String) ?? ""
        let port = outbound["server_port"] as? Int ?? 0
        let transportDict = outbound["transport"] as? [String: Any]
        let transport = (transportDict?["type"] as? String) ?? ""
        let tls = outbound["tls"] as? [String: Any]
        let securityFlag: String
        if (tls?["enabled"] as? Bool) == true {
            securityFlag = tls?["reality"] != nil ? "reality" : "tls"
        } else {
            securityFlag = "none"
        }
        let uuidHash = stableHash(outbound["uuid"] as? String)
        let passHash = stableHash(outbound["password"] as? String)
        let flow = (outbound["flow"] as? String) ?? ""
        let encryption = (outbound["encryption"] as? String) ?? ""
        let path = listOrString(transportDict?["path"])
        let host = listOrString(transportDict?["host"])
        let serviceName = (transportDict?["service_name"] as? String) ?? ""
        let mode = (transportDict?["mode"] as? String) ?? ""
        let extraHash = stableHash(stringifyJSON(transportDict?["extra"]))
        let sni = (tls?["server_name"] as? String) ?? ""
        let alpn = listOrString(tls?["alpn"])
        let fpHash = stableHash((tls?["utls"] as? [String: Any])?["fingerprint"] as? String)
        let reality = tls?["reality"] as? [String: Any]
        let pbkHash = stableHash(reality?["public_key"] as? String)
        let sidHash = stableHash(reality?["short_id"] as? String)
        let packetEncoding = (outbound["packet_encoding"] as? String) ?? ""
        let alterId = "\(outbound["alter_id"] as? Int ?? -1)"
        let method = (outbound["method"] as? String) ?? ""
        let scy = (outbound["security"] as? String) ?? ""
        let obfs = outbound["obfs"] as? [String: Any]
        let obfsType = (obfs?["type"] as? String) ?? (outbound["obfs"] as? String) ?? ""
        let obfsPassHash = stableHash(obfs?["password"] as? String)
        let hopPorts = listOrString(outbound["server_ports"])
        let muxHash = stableHash(stringifyJSON(outbound["multiplex"]))
        let xmuxHash = stableHash(stringifyJSON(transportDict?["xmux"]))
        let detourTag = detour ?? ""
        return [
            type, server, "\(port)", transport, securityFlag,
            uuidHash, passHash, flow, encryption, path, host, serviceName, mode, extraHash,
            sni, alpn, fpHash, pbkHash, sidHash, packetEncoding, alterId, method, scy,
            obfsType, obfsPassHash, hopPorts, muxHash, xmuxHash, detourTag,
        ].joined(separator: "|")
    }

    private static func listOrString(_ value: Any?) -> String {
        if let s = value as? String { return s }
        if let arr = value as? [Any] {
            return arr.map { "\($0)" }.joined(separator: ",")
        }
        if let arr = value as? [String] {
            return arr.joined(separator: ",")
        }
        return ""
    }

    private static func stringifyJSON(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let s = value as? String { return s }
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value),
              let s = String(data: data, encoding: .utf8)
        else {
            return "\(value)"
        }
        return s
    }

    /// Apply Xray `routing.balancers` selector prefixes + strategy.
    /// - leastPing / leastLoad → location `.urltest`
    /// - random → fail closed (no silent urltest substitution)
    private static func applyBalancers(
        balancers: [[String: Any]],
        endpoints: [NormalizedNode],
        locationName: String
    ) throws -> ([NormalizedNode], NormalizedLocationStrategy) {
        guard !balancers.isEmpty else {
            // Multi-leaf without balancers → select, never invent urltest.
            return (endpoints, endpoints.count > 1 ? .select : .single)
        }

        // Remnawave typically emits one balancer per profile; honor the first, validate all.
        var selected = endpoints
        var strategy: NormalizedLocationStrategy = .urltest

        for (bIndex, balancer) in balancers.enumerated() {
            let selectors = (balancer["selector"] as? [String]) ?? []
            let strategyType = balancerStrategyType(balancer)
            switch strategyType {
            case "leastping", "leastload", "least_ping", "least_load", "":
                strategy = .urltest
            case "random":
                throw VPNDirectCoreError.unsupportedFeature(
                    component: "xray.balancer.\(locationName)",
                    detail: "strategy=random has no silent sing-box equivalent; refusing urltest substitution"
                )
            default:
                throw VPNDirectCoreError.unsupportedFeature(
                    component: "xray.balancer.\(locationName)",
                    detail: "unsupported balancer strategy=\(strategyType)"
                )
            }

            if !selectors.isEmpty {
                let filtered = endpoints.filter { node in
                    let tag = node.attributes["xrayTag"] ?? node.name
                    return selectors.contains { prefix in
                        tag == prefix || tag.hasPrefix(prefix)
                    }
                }
                if filtered.isEmpty {
                    throw VPNDirectCoreError.malformedConfig(
                        component: "xray.balancer.\(locationName)",
                        detail: "balancer[\(bIndex)] selector matched zero leaves: \(selectors.joined(separator: ","))"
                    )
                }
                // First balancer defines the location leaf set (Remnawave country profile).
                if bIndex == 0 {
                    selected = filtered
                }
            }
        }
        return (selected, selected.count > 1 ? strategy : .single)
    }

    private static func balancerStrategyType(_ balancer: [String: Any]) -> String {
        if let strategy = balancer["strategy"] as? [String: Any],
           let type = strategy["type"] as? String
        {
            return type.lowercased()
        }
        if let strategy = balancer["strategy"] as? String {
            return strategy.lowercased()
        }
        return ""
    }

    /// First 8 hex chars of SHA256 — presence/identity without storing secrets in fingerprints/logs.
    private static func stableHash(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "-" }
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
    }

    /// Extract builder-facing fields from a converted sing-box outbound dict.
    private static func flattenOutboundFields(_ outbound: [String: Any]) -> [String: String] {
        var attrs: [String: String] = [:]

        func put(_ key: String, _ value: Any?) {
            guard let value else { return }
            if let s = value as? String {
                if !s.isEmpty { attrs[key] = s }
            } else if let n = value as? NSNumber {
                attrs[key] = n.stringValue
            } else if let b = value as? Bool {
                attrs[key] = b ? "1" : "0"
            } else if let arr = value as? [Any] {
                let joined = arr.map { "\($0)" }.joined(separator: ",")
                if !joined.isEmpty { attrs[key] = joined }
            }
        }

        put("uuid", outbound["uuid"])
        put("flow", outbound["flow"])
        put("encryption", outbound["encryption"])
        put("password", outbound["password"])
        put("method", outbound["method"])
        put("packet_encoding", outbound["packet_encoding"])
        put("auth_str", outbound["auth_str"])
        put("auth", outbound["auth"])
        if let aid = outbound["alter_id"] {
            put("aid", aid)
        }
        // VMess cipher lives in outbound["security"]; keep under scy so TLS security id stays clean.
        if let scy = outbound["security"] as? String, !scy.isEmpty {
            attrs["scy"] = scy
            attrs["security"] = scy
        }
        if let up = outbound["up_mbps"] { put("up", up) }
        if let down = outbound["down_mbps"] { put("down", down) }

        if let tls = outbound["tls"] as? [String: Any] {
            put("sni", tls["server_name"])
            if let insecure = tls["insecure"] as? Bool, insecure {
                attrs["insecure"] = "1"
                attrs["allowInsecure"] = "1"
            }
            if let alpn = tls["alpn"] as? [String], !alpn.isEmpty {
                attrs["alpn"] = alpn.joined(separator: ",")
            } else {
                put("alpn", tls["alpn"])
            }
            if let utls = tls["utls"] as? [String: Any] {
                put("fp", utls["fingerprint"])
            }
            if let reality = tls["reality"] as? [String: Any] {
                put("pbk", reality["public_key"])
                put("sid", reality["short_id"])
            }
            if let fragment = tls["fragment"] as? Bool, fragment {
                attrs["tls_fragment"] = "1"
            }
            if let delay = tls["fragment_fallback_delay"] as? String, !delay.isEmpty {
                attrs["tls_fragment_fallback_delay"] = delay
            }
        }

        if let transport = outbound["transport"] as? [String: Any] {
            if let t = transport["type"] as? String, !t.isEmpty {
                attrs["network"] = t
                attrs["net"] = t
            }
            // Prefer full list semantics for multi-value transport fields (REQ-P092).
            if let pathArr = transport["path"] as? [Any], !pathArr.isEmpty {
                attrs["path"] = pathArr.map { "\($0)" }.joined(separator: ",")
            } else {
                put("path", transport["path"])
            }
            if let hostArr = transport["host"] as? [Any], !hostArr.isEmpty {
                attrs["host"] = hostArr.map { "\($0)" }.joined(separator: ",")
            } else {
                put("host", transport["host"])
            }
            put("mode", transport["mode"])
            if let extra = transport["extra"] {
                if let s = extra as? String, !s.isEmpty {
                    attrs["extra"] = s
                } else if JSONSerialization.isValidJSONObject(extra),
                          let data = try? JSONSerialization.data(withJSONObject: extra),
                          let s = String(data: data, encoding: .utf8)
                {
                    attrs["extra"] = s
                }
            }
            put("service_name", transport["service_name"])
            put("scMaxEachPostBytes", transport["sc_max_each_post_bytes"] ?? transport["scMaxEachPostBytes"])
            put("scMinPostsIntervalMs", transport["sc_min_posts_interval_ms"] ?? transport["scMinPostsIntervalMs"])
            put("scMaxConcurrentPosts", transport["sc_max_concurrent_posts"] ?? transport["scMaxConcurrentPosts"])
            put("x_padding_bytes", transport["x_padding_bytes"] ?? transport["xPaddingBytes"])
            if let headers = transport["headers"] as? [String: String] {
                if let host = headers["Host"] ?? headers["host"], !host.isEmpty {
                    attrs["host"] = attrs["host"] ?? host
                    attrs["Host"] = host
                }
            }
        }

        if let obfs = outbound["obfs"] as? [String: Any] {
            put("obfs", obfs["type"])
            put("obfs_password", obfs["password"])
        } else {
            put("obfs", outbound["obfs"])
        }

        if let multiplex = outbound["multiplex"] as? [String: Any],
           let json = XrayMuxAndMask.multiplexAttrJSON(multiplex)
        {
            attrs["multiplex_json"] = json
            attrs["multiplex"] = "1"
        }

        return attrs
    }

    private static func firstString(_ value: Any?) -> String? {
        if let s = value as? String, !s.isEmpty { return s }
        if let arr = value as? [String], let first = arr.first, !first.isEmpty { return first }
        if let arr = value as? [Any], let first = arr.first {
            let s = "\(first)"
            return s.isEmpty ? nil : s
        }
        return nil
    }

    private static func isTrafficStub(_ name: String) -> Bool {
        name.localizedCaseInsensitiveContains("осталось трафика")
            || name.localizedCaseInsensitiveContains("traffic left")
    }

    private static func isGlobalAutoName(_ name: String) -> Bool {
        name.localizedCaseInsensitiveContains("автовыбор")
            || name.localizedCaseInsensitiveContains("autoselect")
            || name.localizedCaseInsensitiveContains("auto select")
    }

    private static func xrayDialerProxyTag(_ xray: [String: Any]) -> String? {
        let stream = (xray["streamSettings"] as? [String: Any]) ?? [:]
        let sockopt = (stream["sockopt"] as? [String: Any]) ?? [:]
        if let dialer = sockopt["dialerProxy"] as? String, !dialer.isEmpty {
            return dialer
        }
        if let proxySettings = xray["proxySettings"] as? [String: Any],
           let tag = proxySettings["tag"] as? String, !tag.isEmpty
        {
            return tag
        }
        return nil
    }

    private static func transportID(from outbound: [String: Any]) -> VPNDirectTransportID? {
        if let t = (outbound["transport"] as? [String: Any])?["type"] as? String {
            return VPNDirectTransportID(rawValue: t)
        }
        let type = ((outbound["type"] as? String) ?? "").lowercased()
        if type == "hysteria" || type == "hysteria2" {
            return .quic
        }
        return nil
    }

    private static func securityID(from outbound: [String: Any]) -> VPNDirectSecurityID? {
        let tls = outbound["tls"] as? [String: Any]
        guard (tls?["enabled"] as? Bool) == true else { return VPNDirectSecurityID.none }
        if tls?["reality"] != nil {
            return .reality
        }
        return .tls
    }

    /// Flatten nested JSON into dotted string keys for rawExtensions (lossy but auditable).
    private static func flattenJSON(_ object: [String: Any], prefix: String, depth: Int = 0) -> [String: String] {
        guard depth < 6 else { return [:] }
        var out: [String: String] = [:]
        for (key, value) in object {
            let path = prefix.isEmpty ? key : "\(prefix).\(key)"
            if let nested = value as? [String: Any] {
                for (k, v) in flattenJSON(nested, prefix: path, depth: depth + 1) {
                    out[k] = v
                }
            } else if let arr = value as? [Any] {
                out[path] = arr.map { "\($0)" }.joined(separator: ",")
            } else {
                out[path] = "\(value)"
            }
        }
        return out
    }
}
