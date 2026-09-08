import Foundation
import Libbox
import Library
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public struct NewProfileMenuView: View {
    @EnvironmentObject private var environments: ExtensionEnvironments
    @Environment(\.dismiss) private var dismiss
    @State private var alert: AlertState?
    @State private var importRequest: NewProfileView.ImportRequest?
    @State private var localImportRequest: NewProfileView.LocalImportRequest?
    #if os(tvOS)
        @State private var importCompleted = false
    #else
        @State private var showFileImporter = false
        @State private var showQRScanner = false
    #endif
    #if os(macOS)
        @State private var showNewProfile = false
    #endif

    public init() {}

    public var body: some View {
        #if os(macOS)
            macOSBody
        #else
            otherBody
        #endif
    }

    #if os(macOS)
        private var macOSBody: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text("New Profile")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                menuContent
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }
            .alert($alert)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: VPNDirectImportContentTypes.menuImport,
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showNewProfile) {
                NewProfileView(onSuccess: { profile in
                    await SharedPreferences.selectedProfileID.set(profile.mustID)
                    dismiss()
                })
                .environmentObject(environments)
            }
            .sheet(item: $localImportRequest) { request in
                NewProfileView(localImportRequest: request, onSuccess: { profile in
                    await SharedPreferences.selectedProfileID.set(profile.mustID)
                    dismiss()
                })
                .environmentObject(environments)
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerView { result in
                    handleQRScanResult(result)
                }
                .frame(minWidth: 500, minHeight: 400)
            }
            .sheet(item: $importRequest) { request in
                NewProfileView(request, onSuccess: { profile in
                    await SharedPreferences.selectedProfileID.set(profile.mustID)
                    dismiss()
                })
                .environmentObject(environments)
            }
        }
    #endif

    private var otherBody: some View {
        Group {
            if let request = importRequest {
                NewProfileView(request, onSuccess: { profile in
                    await SharedPreferences.selectedProfileID.set(profile.mustID)
                    dismiss()
                })
                .environmentObject(environments)
            } else if let request = localImportRequest {
                NewProfileView(localImportRequest: request, onSuccess: { profile in
                    await SharedPreferences.selectedProfileID.set(profile.mustID)
                    dismiss()
                })
                .environmentObject(environments)
            } else {
                menuContent
            }
        }
        .navigationTitle("New Profile")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .alert($alert)
        #if os(tvOS)
            .onChange(of: importCompleted) { newValue in
                if newValue {
                    dismiss()
                }
            }
        #else
            .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: VPNDirectImportContentTypes.menuImport,
                    allowsMultipleSelection: false
                ) { result in
                    handleFileImport(result)
                }
        #endif
        #if !os(tvOS)
        .sheet(isPresented: $showQRScanner) {
            QRScannerView { result in
                handleQRScanResult(result)
            }
        }
        #endif
    }

    private var menuContent: some View {
        FormView {
            Section {
                #if os(tvOS)
                    FormNavigationLink {
                        ImportProfileView(onComplete: {
                            importCompleted = true
                        })
                        .environmentObject(environments)
                    } label: {
                        Label("Import from iPhone or iPad", systemImage: "iphone.and.arrow.forward")
                    }
                #endif

                #if !os(tvOS)
                    FormButton {
                        showFileImporter = true
                    } label: {
                        Label("Import from File", systemImage: "doc.badge.plus")
                    }
                #endif

                #if !os(tvOS)
                    FormButton {
                        showQRScanner = true
                    } label: {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    }
                #endif

                #if os(macOS)
                    FormButton {
                        showNewProfile = true
                    } label: {
                        Label("Create Manually", systemImage: "square.and.pencil")
                    }
                #else
                    FormNavigationLink {
                        NewProfileView(onSuccess: { profile in
                            await SharedPreferences.selectedProfileID.set(profile.mustID)
                            dismiss()
                        })
                        .environmentObject(environments)
                    } label: {
                        Label("Create Manually", systemImage: "square.and.pencil")
                    }
                #endif
            }
        }
    }

    #if !os(tvOS)
        private func handleFileImport(_ result: Result<[URL], Error>) {
            Task { @MainActor in
                do {
                    let urls = try result.get()
                    guard let url = urls.first else { return }

                    let ext = url.pathExtension.lowercased()
                    // Textual configs (JSON / .ovpn / OpenConnect / Tailscale) go through the
                    // local import + normalizeRemoteContent path — not LibboxProfileContent.
                    if ["json", "ovpn", "conf", "xml", "txt"].contains(ext) || ext.isEmpty {
                        let fileName = url.deletingPathExtension().lastPathComponent
                        localImportRequest = NewProfileView.LocalImportRequest(name: fileName, fileURL: url)
                        return
                    }

                    let data = try await BlockingIO.run {
                        try url.withRequiredSecurityScopedAccess(
                            or: NSError(domain: "NewProfileMenuView", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "Missing access to selected file")])
                        ) {
                            try Data(contentsOf: url)
                        }
                    }
                    let content = try LibboxProfileContent.from(data)

                    alert = AlertState(
                        title: String(localized: "Import Profile"),
                        message: String(localized: "Are you sure to import profile \(content.name)?"),
                        primaryButton: .default(String(localized: "Import")) {
                            Task {
                                do {
                                    try await content.importProfile()
                                    environments.profileUpdate.send()
                                    dismiss()
                                } catch {
                                    alert = AlertState(action: "import profile", error: error)
                                }
                            }
                        },
                        secondaryButton: .cancel()
                    )
                } catch {
                    alert = AlertState(action: "read imported profile file", error: error)
                }
            }
        }
    #endif

    #if !os(tvOS)
        private func handleQRScanResult(_ result: QRScanResult) {
            switch result {
            case let .qrCode(string, _):
                handleQRCodeString(string)
            case let .qrsData(data):
                handleQRSData(data)
            }
        }

        private func handleQRCodeString(_ string: String) {
            let trimmed = Self.normalizeImportString(string)

            // VPN Direct / share QR codes usually encode a raw vless:// link.
            if VLESSConfigBuilder.isVLESSLink(trimmed) {
                let name = (try? VLESSConfigBuilder.parse(trimmed))?.name ?? ""
                importRequest = NewProfileView.ImportRequest(name: name, url: trimmed)
                showQRScanner = false
                return
            }

            if SubscriptionConfigBuilder.isShareLinkContent(trimmed) {
                importRequest = NewProfileView.ImportRequest(
                    name: SubscriptionConfigBuilder.suggestedName(forShareContent: trimmed),
                    url: trimmed
                )
                showQRScanner = false
                return
            }

            // Classic subscription URLs: https://host/sub/<uuid>
            // Also happ://add/https://... / incy://add/https://... deep links from panels.
            if SubscriptionConfigBuilder.isHTTPURL(trimmed) {
                importRequest = NewProfileView.ImportRequest(
                    name: SubscriptionConfigBuilder.suggestedName(for: trimmed),
                    url: trimmed
                )
                showQRScanner = false
                return
            }

            // Upstream sing-box remote profile import links (sing-box://import-remote-profile?...).
            var error: NSError?
            let remoteProfile = LibboxParseRemoteProfileImportLink(trimmed, &error)
            if let error {
                alert = AlertState(action: "parse QR code profile link", error: error)
                return
            }
            guard let remoteProfile else {
                alert = AlertState(errorMessage: String(localized: "The QR code does not contain a valid share link, https:// subscription, or profile import link."))
                return
            }
            importRequest = NewProfileView.ImportRequest(name: remoteProfile.name, url: remoteProfile.url)
            showQRScanner = false
        }

        /// Unwraps panel deep links like `happ://add/https://...` into the inner URL.
        private static func normalizeImportString(_ raw: String) -> String {
            var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = value.lowercased()
            for prefix in ["happ://add/", "incy://add/", "vpndirect://add/", "streisand://import/"] {
                if lower.hasPrefix(prefix) {
                    value = String(value.dropFirst(prefix.count))
                    if let decoded = value.removingPercentEncoding, !decoded.isEmpty {
                        value = decoded
                    }
                    break
                }
            }
            // Some QRs wrap the URL as target=https%3A%2F%2F...
            if let url = URL(string: value),
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let target = components.queryItems?.first(where: { $0.name == "target" })?.value,
               let decoded = target.removingPercentEncoding
            {
                return normalizeImportString(decoded)
            }
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        private func handleQRSData(_ data: Data) {
            do {
                let (actualData, _, _) = try BinaryMeta.readFileHeaderMeta(buffer: data)
                let content = try LibboxProfileContent.from(actualData)
                alert = AlertState(
                    title: String(localized: "Import Profile"),
                    message: String(localized: "Are you sure to import profile \(content.name)?"),
                    primaryButton: .default(String(localized: "Import")) {
                        Task {
                            do {
                                try await content.importProfile()
                                environments.profileUpdate.send()
                                dismiss()
                            } catch {
                                alert = AlertState(action: "import profile", error: error)
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            } catch {
                alert = AlertState(action: "decode QRS profile data", error: error)
            }
        }
    #endif
}
