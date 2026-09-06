import Foundation

/// Diagnostics for a parse pass over subscription content or share-link lists.
public struct VPNDirectParseDiagnostics: Equatable {
    public var total: Int
    public var parsed: Int
    public var unsupported: Int
    public var malformed: Int
    public var unsupportedComponents: [String]

    public init(
        total: Int = 0,
        parsed: Int = 0,
        unsupported: Int = 0,
        malformed: Int = 0,
        unsupportedComponents: [String] = []
    ) {
        self.total = total
        self.parsed = parsed
        self.unsupported = unsupported
        self.malformed = malformed
        self.unsupportedComponents = unsupportedComponents
    }
}

public struct VPNDirectParseResult {
    public var nodes: [NormalizedNode]
    public var diagnostics: VPNDirectParseDiagnostics

    public init(nodes: [NormalizedNode], diagnostics: VPNDirectParseDiagnostics) {
        self.nodes = nodes
        self.diagnostics = diagnostics
    }
}

/// Universal parser surface. Milestone 2: VLESS adapter; Milestone 3 expands schemes.
public protocol VPNDirectParser {
    /// Schemes this parser accepts (e.g. `vless`).
    var supportedSchemes: [String] { get }

    func parseShareLink(_ link: String) throws -> NormalizedNode
}

public enum VPNDirectParserRegistry {
    public static var shareLinkParsers: [VPNDirectParser] = [
        VLESSShareLinkParser(),
        HysteriaShareLinkParser(),
        VMessShareLinkParser(),
        TrojanShareLinkParser(),
        ShadowsocksShareLinkParser(),
        TUICShareLinkParser(),
        AnyTLSShareLinkParser(),
        WireGuardShareLinkParser(),
        SOCKSShareLinkParser(),
        HTTPProxyShareLinkParser(),
        SSHShareLinkParser(),
        ShadowTLSShareLinkParser(),
        NaiveProxyShareLinkParser(),
    ]

    public static func parseShareLinks(_ links: [String]) -> VPNDirectParseResult {
        var nodes: [NormalizedNode] = []
        var diagnostics = VPNDirectParseDiagnostics(total: links.count)
        var unsupportedComponents = Set<String>()

        for link in links {
            let lower = link.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let scheme = lower.split(separator: ":", maxSplits: 1).first.map(String.init),
                  !scheme.isEmpty
            else {
                diagnostics.malformed += 1
                continue
            }

            guard let parser = shareLinkParsers.first(where: { $0.supportedSchemes.contains(scheme) }) else {
                diagnostics.unsupported += 1
                continue
            }

            do {
                nodes.append(try parser.parseShareLink(link))
                diagnostics.parsed += 1
            } catch let error as VLESSConfigBuilder.VLESSError {
                if case let .unsupportedFeature(component, _) = error {
                    diagnostics.unsupported += 1
                    unsupportedComponents.insert(component)
                } else {
                    diagnostics.malformed += 1
                }
            } catch let error as VPNDirectCoreError {
                if case let .unsupportedFeature(component, _) = error {
                    diagnostics.unsupported += 1
                    unsupportedComponents.insert(component)
                } else {
                    diagnostics.malformed += 1
                }
            } catch {
                diagnostics.malformed += 1
            }
        }

        diagnostics.unsupportedComponents = unsupportedComponents.sorted()
        return VPNDirectParseResult(nodes: nodes, diagnostics: diagnostics)
    }
}
