import UniformTypeIdentifiers

/// UTTypes accepted by Import from File for VPN Direct configs.
enum VPNDirectImportContentTypes {
    static var localConfig: [UTType] {
        var types: [UTType] = [.json, .plainText, .xml, .data]
        if let ovpn = UTType(filenameExtension: "ovpn") { types.append(ovpn) }
        if let conf = UTType(filenameExtension: "conf") { types.append(conf) }
        return types
    }

    static var menuImport: [UTType] {
        [.profile] + localConfig
    }
}
