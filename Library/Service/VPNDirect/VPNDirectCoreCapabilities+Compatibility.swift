import Foundation

/// Source-compatibility aliases used by builders while capability naming is normalized around the
/// ABI's MASQUE spelling. Keep this extension intentionally tiny: it must not infer support from
/// build tags or other non-authoritative metadata.
public extension VPNDirectCoreCapabilities {
    var supportsMasqueConnectIP: Bool { supportsMASQUEConnectIP }
    var supportsMasqueConnectUDP: Bool { supportsMASQUEConnectUDP }
}
