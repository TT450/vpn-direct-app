import Foundation

/// Remnawave / Happ XRAY_JSON → NormalizedSubscription (TheTochka location semantics).
enum XrayJSONAdapter {
    static func parse(_ content: String) throws -> NormalizedSubscription {
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
                return proto == "vless" || proto == "hysteria" || proto == "hysteria2"
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

            for (entryIndex, xray) in ordered.enumerated() {
                let xrayTag = ((xray["tag"] as? String) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let fallbackTag = "loc-\(index + 1)-\(entryIndex + 1)"
                let proto = ((xray["protocol"] as? String) ?? "").lowercased()

                let converted: [String: Any]?
                if proto == "vless" {
                    converted = XrayVLESSConverter.convert(xray, fallbackTag: fallbackTag)
                } else {
                    converted = HysteriaOutboundFactory.fromXray(xray, fallbackTag: fallbackTag)
                }
                guard var outbound = converted else { continue }

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
                outbound["tag"] = leafName

                var detourXray: String?
                if let dialer = xrayDialerProxyTag(xray) {
                    detourXray = dialer
                }

                let node = NormalizedNode(
                    name: leafName,
                    protocolID: VPNDirectProtocolID(rawValue: type),
                    server: server,
                    port: port,
                    transport: transportID(from: outbound),
                    security: securityID(from: outbound),
                    uuid: outbound["uuid"] as? String,
                    attributes: [
                        "xrayTag": xrayTag,
                    ],
                    outbound: outbound,
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

            guard !endpoints.isEmpty else { continue }

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
}
