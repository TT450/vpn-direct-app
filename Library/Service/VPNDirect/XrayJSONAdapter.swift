import Foundation

/// Remnawave / Happ XRAY_JSON → NormalizedSubscription (TheTochka location semantics).
///
/// Converted leaf outbounds are flattened into `NormalizedNode.attributes` and rebuilt by
/// `UniversalOutboundBuilder` (no LEGACY `outbound` attachment for new Xray imports).
public enum XrayJSONAdapter {
    public static func parse(_ content: String) throws -> NormalizedSubscription {
        guard let data = content.data(using: .utf8),
              let profiles = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            throw SubscriptionConfigBuilder.SubscriptionError.xrayJSONUnsupported
        }

        var locations: [NormalizedLocation] = []
        var firstName: String?

        for (index, profile) in profiles.enumerated() {
            let remarks = ((profile["remarks"] as? String) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = remarks.isEmpty ? "Server \(index + 1)" : remarks

            if isTrafficStub(displayName) {
                continue
            }

            let xrayOutbounds = (profile["outbounds"] as? [[String: Any]]) ?? []
            let proxyOutbounds = xrayOutbounds.filter { outbound in
                let proto = ((outbound["protocol"] as? String) ?? "").lowercased()
                return proto == "vless"
                    || proto == "hysteria"
                    || proto == "hysteria2"
                    || proto == "vmess"
                    || proto == "trojan"
                    || proto == "shadowsocks"
                    || proto == "ss"
            }

            let routing = (profile["routing"] as? [String: Any]) ?? [:]
            let balancers = (routing["balancers"] as? [[String: Any]]) ?? []
            let hasBalancers = !balancers.isEmpty

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
            var convertFailures: [String] = []

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
                if EndpointValidator.isBlockedLoopbackHost(server) {
                    continue
                }
                let fingerprint = "\(type)|\(server)|\(port)"
                if !seenServersInProfile.insert(fingerprint).inserted {
                    continue
                }

                let leafName = "\(displayName)-n\(entryIndex + 1)"

                var detourXray: String?
                if let dialer = xrayDialerProxyTag(xray) {
                    detourXray = dialer
                }

                var attributes = flattenOutboundFields(outbound)
                var rawExtensions: [String: String] = [:]
                if !xrayTag.isEmpty { attributes["xrayTag"] = xrayTag }
                // Preserve streamSettings keys the converters may not map yet.
                if let stream = xray["streamSettings"] as? [String: Any] {
                    for (k, v) in flattenJSON(stream, prefix: "stream") {
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

            guard !endpoints.isEmpty else {
                if !convertFailures.isEmpty {
                    throw VPNDirectCoreError.unsupportedFeature(
                        component: "xray.\(displayName)",
                        detail: "all proxy outbounds failed conversion: \(convertFailures.joined(separator: ","))"
                    )
                }
                continue
            }

            let kind: NormalizedLocationKind = isGlobalAutoName(displayName) ? .globalAuto : .country
            let strategy: NormalizedLocationStrategy =
                (hasBalancers || endpoints.count > 1) ? .urltest : .single

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

        return NormalizedSubscription(name: firstName, locations: locations)
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
        }

        if let transport = outbound["transport"] as? [String: Any] {
            if let t = transport["type"] as? String, !t.isEmpty {
                attrs["network"] = t
                attrs["net"] = t
            }
            put("path", firstString(transport["path"]))
            put("host", firstString(transport["host"]))
            put("mode", transport["mode"])
            put("extra", transport["extra"])
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
