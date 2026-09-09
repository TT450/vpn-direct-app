import Foundation

/// Exact Xray SplitHTTP/XHTTP → Leadaxe/sing-box-lx v1.14.0-lx.35 transport mapper.
///
/// Xray's `extra` is not an additive bag. When present, Xray unmarshals it into a fresh
/// SplitHTTPConfig and then overwrites only Host/Path/Mode from the outer config. This mapper
/// mirrors that precedence. Unknown/effectively-unrepresentable members are retained under
/// `extra`; `CompatibilityFieldPolicy` makes that fail closed before production emission.
enum XrayXHTTPMapper {
    private static let stringFields: [(xray: String, sing: String)] = [
        ("xPaddingBytes", "x_padding_bytes"),
        ("scMaxEachPostBytes", "sc_max_each_post_bytes"),
        ("scMinPostsIntervalMs", "sc_min_posts_interval_ms"),
        ("scStreamUpServerSecs", "sc_stream_up_server_secs"),
        ("sessionIDPlacement", "session_placement"),
        ("sessionPlacement", "session_placement"),
        ("sessionIDKey", "session_key"),
        ("sessionKey", "session_key"),
        ("sessionIDTable", "session_table"),
        ("sessionIDLength", "session_length"),
        ("seqPlacement", "seq_placement"),
        ("seqKey", "seq_key"),
        ("uplinkDataPlacement", "uplink_data_placement"),
        ("uplinkDataKey", "uplink_data_key"),
        ("uplinkChunkSize", "uplink_chunk_size"),
        ("uplinkHTTPMethod", "uplink_http_method"),
        ("xPaddingKey", "x_padding_key"),
        ("xPaddingHeader", "x_padding_header"),
        ("xPaddingPlacement", "x_padding_placement"),
        ("xPaddingMethod", "x_padding_method"),
    ]

    private static let intFields: [(xray: String, sing: String)] = [
        ("scMaxBufferedPosts", "sc_max_buffered_posts"),
        ("serverMaxHeaderBytes", "server_max_header_bytes"),
        ("scMaxConcurrentPosts", "sc_max_concurrent_posts"),
    ]

    private static let boolFields: [(xray: String, sing: String)] = [
        ("noGRPCHeader", "no_grpc_header"),
        ("noSSEHeader", "no_sse_header"),
        ("xPaddingObfsMode", "x_padding_obfs_mode"),
    ]

    private static let xmuxStringFields: [(xray: String, sing: String)] = [
        ("maxConcurrency", "max_concurrency"),
        ("maxConnections", "max_connections"),
        ("cMaxReuseTimes", "c_max_reuse_times"),
        ("hMaxRequestTimes", "h_max_request_times"),
        ("hMaxReusableSecs", "h_max_reusable_secs"),
    ]

    // Plain integer in pinned lx (not a range).
    private static let xmuxIntFields: [(xray: String, sing: String)] = [
        ("hKeepAlivePeriod", "h_keep_alive_period"),
    ]

    static func merge(from outer: [String: Any], into transport: inout [String: Any]) {
        let extraWasPresent = outer["extra"] != nil
        let effective: [String: Any]

        if extraWasPresent {
            guard let extraObject = decodeObject(outer["extra"]) else {
                // Unparseable Xray extra bag — do not emit invalid transport.extra (Libbox rejects it).
                return
            }
            // Exact Xray semantics: extra replaces the config except Host/Path/Mode, which are
            // copied back from the outer object by Xray before validation/build.
            effective = extraObject
        } else {
            effective = outer
        }

        var unknown = effective

        // Xray overrides these from the outer config after decoding `extra`; the converter itself
        // already handles outer path/mode/host. Values inside extra therefore have no effect.
        unknown.removeValue(forKey: "host")
        unknown.removeValue(forKey: "path")
        unknown.removeValue(forKey: "mode")
        unknown.removeValue(forKey: "extra")

        if let headersRaw = unknown.removeValue(forKey: "headers") {
            if let headers = stringDictionary(headersRaw),
               !headers.keys.contains(where: { $0.caseInsensitiveCompare("host") == .orderedSame })
            {
                if !headers.isEmpty { transport["headers"] = headers }
            } else {
                // Xray itself rejects Host in SplitHTTP headers and non-string header values.
                unknown["headers"] = headersRaw
            }
        }

        for (xrayKey, singKey) in stringFields {
            guard let raw = unknown.removeValue(forKey: xrayKey) else { continue }
            if let value = rangeOrString(raw) {
                transport[singKey] = value
            } else {
                unknown[xrayKey] = raw
            }
        }

        for (xrayKey, singKey) in intFields {
            guard let raw = unknown.removeValue(forKey: xrayKey) else { continue }
            if let value = exactInt(raw) {
                transport[singKey] = value
            } else {
                unknown[xrayKey] = raw
            }
        }

        for (xrayKey, singKey) in boolFields {
            guard let raw = unknown.removeValue(forKey: xrayKey) else { continue }
            if let value = exactBool(raw) {
                transport[singKey] = value
            } else {
                unknown[xrayKey] = raw
            }
        }

        // downloadSettings is not on pinned lx V2RayXHTTPOptions — drop (do not emit unknown key).
        unknown.removeValue(forKey: "downloadSettings")

        if let xmuxRaw = unknown.removeValue(forKey: "xmux") {
            if var xmux = xmuxRaw as? [String: Any] {
                var nested: [String: Any] = [:]
                for (xrayKey, singKey) in xmuxStringFields {
                    guard let raw = xmux.removeValue(forKey: xrayKey) else { continue }
                    if let value = rangeOrString(raw) {
                        nested[singKey] = value
                    } else {
                        xmux[xrayKey] = raw
                    }
                }
                for (xrayKey, singKey) in xmuxIntFields {
                    guard let raw = xmux.removeValue(forKey: xrayKey) else { continue }
                    if let value = exactInt(raw) {
                        nested[singKey] = value
                    } else {
                        xmux[xrayKey] = raw
                    }
                }
                if let raw = xmux.removeValue(forKey: "noGRPCHeader") {
                    if let value = exactBool(raw) {
                        // Xray sometimes nests this under xmux; pinned lx keeps it on transport root.
                        transport["no_grpc_header"] = value
                    } else {
                        xmux["noGRPCHeader"] = raw
                    }
                }
                if !nested.isEmpty {
                    transport["xmux"] = nested
                }
                if !xmux.isEmpty { unknown["xmux"] = xmux }
            } else {
                unknown["xmux"] = xmuxRaw
            }
        }

        // Drop empty header maps left by panels.
        if let headers = unknown["headers"] as? [String: Any], headers.isEmpty {
            unknown.removeValue(forKey: "headers")
        }

        // Pinned Libbox has no transport.extra bag — never emit unknown leftovers onto transport
        // (CheckConfig → "json: unknown field"). Mapped Core fields above are enough for White LIST.
        _ = unknown
    }

    private static func decodeObject(_ raw: Any?) -> [String: Any]? {
        if let object = raw as? [String: Any] { return object }
        guard let string = raw as? String, !string.isEmpty,
              let data = string.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object
    }

    private static func stringDictionary(_ raw: Any) -> [String: String]? {
        if let value = raw as? [String: String] { return value }
        guard let object = raw as? [String: Any] else { return nil }
        var output: [String: String] = [:]
        for (key, value) in object {
            guard let string = value as? String else { return nil }
            output[key] = string
        }
        return output
    }

    /// Pinned lx range-shaped fields are JSON strings (`"n"` or `"min-max"`).
    private static func rangeOrString(_ raw: Any) -> String? {
        if let value = raw as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = raw as? NSNumber { return value.stringValue }
        if let object = raw as? [String: Any] {
            let from = exactInt(object["from"] ?? object["From"])
            let to = exactInt(object["to"] ?? object["To"])
            if let from, let to { return from == to ? "\(from)" : "\(from)-\(to)" }
        }
        if let values = raw as? [Any], values.count == 2,
           let from = exactInt(values[0]), let to = exactInt(values[1])
        {
            return from == to ? "\(from)" : "\(from)-\(to)"
        }
        return nil
    }

    private static func exactInt(_ raw: Any?) -> Int? {
        if let value = raw as? Int { return value }
        if let value = raw as? NSNumber { return value.intValue }
        if let value = raw as? String {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let object = raw as? [String: Any],
           let from = exactInt(object["from"] ?? object["From"]),
           let to = exactInt(object["to"] ?? object["To"]),
           from == to
        {
            return from
        }
        if let values = raw as? [Any], values.count == 2,
           let from = exactInt(values[0]), let to = exactInt(values[1]), from == to
        {
            return from
        }
        return nil
    }

    private static func exactBool(_ raw: Any?) -> Bool? {
        if let value = raw as? Bool { return value }
        if let value = raw as? NSNumber { return value.boolValue }
        if let value = raw as? String {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true": return true
            case "0", "false": return false
            default: return nil
            }
        }
        return nil
    }
}
