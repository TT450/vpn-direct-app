import Foundation

/// Test-only Libbox surface so VPN Direct parsers compile without the XCFramework.
@discardableResult
public func LibboxCheckConfig(_ configContent: String?, _ error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
    error?.pointee = nil
    return true
}

public func LibboxVersion() -> String { "test-libbox" }

public func LibboxVPNDirectCoreMagic() -> String { "VPN_DIRECT_CORE" }
public func LibboxVPNDirectCoreAPIVersion() -> Int { 1 }
public func LibboxVPNDirectCoreName() -> String { "VPNDirectCore" }
public func LibboxVPNDirectCoreVersion() -> String { "test" }
public func LibboxVPNDirectCapabilityJSON() -> String { "" }
public func LibboxVPNDirectBuildTagsCSV() -> String { "with_mieru,with_awg" }
public func LibboxVPNDirectAWGVersionsCSV() -> String { "2,3.0,3.1" }
public func LibboxVPNDirectHysteria2ObfuscationsCSV() -> String { "salamander,gecko" }
public func LibboxVPNDirectSupportsXHTTP() -> Bool { true }
public func LibboxVPNDirectSupportsAWG() -> Bool { true }
public func LibboxVPNDirectSupportsMASQUEConnectIP() -> Bool { true }
public func LibboxVPNDirectSupportsMASQUEConnectUDP() -> Bool { false }
public func LibboxVPNDirectSupportsVLESSEncryption() -> Bool { true }
public func LibboxVPNDirectSupportsMieru() -> Bool { true }
