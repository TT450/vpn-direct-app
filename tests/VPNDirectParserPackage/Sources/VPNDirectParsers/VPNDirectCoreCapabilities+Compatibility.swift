import Foundation

/// Parser-package mirror of the production MASQUE capability naming bridge.
public extension VPNDirectCoreCapabilities {
    var supportsMasqueConnectIP: Bool { supportsMASQUEConnectIP }
    var supportsMasqueConnectUDP: Bool { supportsMASQUEConnectUDP }
}
