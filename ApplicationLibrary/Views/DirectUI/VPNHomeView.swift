import Libbox
import Library
import NetworkExtension
import SwiftUI
import UIKit

#if os(iOS)

@MainActor
public struct VPNHomeView: View {
    @EnvironmentObject private var environments: ExtensionEnvironments
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = VPNConnectionModel()

    @State private var showQRScanner = false
    @State private var importRequest: NewProfileView.ImportRequest?
    @State private var previousActiveSheet: AppSheet?

    public init() {}

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            DS.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                Color.clear.frame(height: 58)

                Group {
                    if let detailPage = model.detailPage {
                        switch detailPage {
                        case let .subscription(id):
                            DirectSubscriptionDetailView(model: model, subscriptionID: id)
                        case .security:
                            DirectSecurityCenterView(model: model)
                        case .connection:
                            DirectConnectionSettingsView(model: model)
                        case .diagnostics:
                            DirectDiagnosticsView(model: model)
                        case .activity:
                            DirectActivityView(model: model)
                        case .systemSettings:
                            DirectSystemSettingsView(model: model)
                        case .systemWarning:
                            DirectSystemSettingsWarningView(model: model)
                        case .about:
                            DirectAboutAppView(model: model)
                        case .serviceLog:
                            DirectServiceLogView(model: model)
                        case .newConfiguration:
                            DirectNewConfigurationView(model: model)
                        case .applicationSettings:
                            DirectApplicationSettingsView(model: model)
                        case .coreSettings:
                            DirectCoreSettingsView(model: model)
                        case .tunnelSettings:
                            DirectTunnelSettingsView(model: model)
                        case .onDemandSettings:
                            DirectOnDemandSettingsView(model: model)
                        case .accessChoice:
                            DirectAccessChoiceView(model: model)
                        case .freeAccess:
                            DirectFreeAccessView(model: model)
                        case .premiumPlans:
                            DirectPremiumPlansView(model: model)
                        case .payment:
                            DirectPaymentMethodView(model: model)
                        case .addOns:
                            DirectAddOnsView(model: model)
                        }
                    } else {
                        switch model.selectedTab {
                        case .home:
                            DirectHomePage(model: model)
                        case .subscriptions:
                            DirectSubscriptionsPage(model: model) {
                                model.isMenuOpen = true
                            }
                        case .profile:
                            DirectProfilePage(model: model)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomNavigation
            }

            if model.isMenuOpen {
                Color.black.opacity(0.12)
                    .ignoresSafeArea(edges: .bottom)
                    .padding(.top, 58)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.isMenuOpen = false
                        HapticManager.shared.play(.menuClosed)
                    }
                    .zIndex(30)

                addSubscriptionMenu
                    .padding(.top, 62)
                    .padding(.trailing, 16)
                    .zIndex(40)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            VStack(spacing: 0) {
                appHeader
                Spacer(minLength: 0)
                    .allowsHitTesting(false)
            }
            .zIndex(50)
        }
        .tint(DS.ink)
        .preferredColorScheme(.light)
        .buttonStyle(HapticButtonStyle())
        .hapticScrollThresholds()
        .appLock(enabled: model.faceIDLock)
        .animation(.easeOut(duration: 0.2), value: model.isMenuOpen)
        .onChangeCompat(of: model.detailPage) { _ in
            HapticManager.shared.play(.navigation)
        }
        .onChangeCompat(of: model.activeSheet) { newSheet in
            if previousActiveSheet == nil, newSheet != nil {
                HapticManager.shared.play(.sheetPresented)
            } else if previousActiveSheet != nil, newSheet == nil {
                HapticManager.shared.play(.sheetDismissed)
            }
            previousActiveSheet = newSheet
        }
        .alert($model.alert)
        .onAppear {
            model.bind(environments)
            if environments.extensionProfile == nil {
                environments.postReload()
            } else {
                model.syncFromExtension()
            }
        }
        .onChangeCompat(of: scenePhase) { phase in
            if phase == .active {
                environments.extensionProfile?.refreshStatus()
                model.syncFromExtension()
            }
        }
        .onReceive(environments.$extensionProfile) { _ in
            model.syncFromExtension()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NEVPNStatusDidChange)) { _ in
            Task { @MainActor in
                environments.extensionProfile?.refreshStatus()
                model.syncFromExtension()
            }
        }
        .onReceive(environments.profileUpdate) { _ in
            Task { await model.reloadSubscriptions() }
        }
        .onReceive(environments.selectedProfileUpdate) { _ in
            Task { await model.reloadSubscriptions() }
        }
        .onReceive(environments.commandClient.$groups) { _ in
            model.updateFromGroups()
        }
        .onChangeCompat(of: environments.extensionProfile?.status) { status in
            model.syncFromExtension()
            // Do NOT settle disconnect here — iOS flickers `.disconnected` while starting.
            // Failure handling lives in syncFromExtension with a debounce + status re-check.
        }
        .sheet(item: $model.activeSheet) { sheet in
            Group {
                switch sheet {
                case .serverPicker:
                    DirectServerPickerView(model: model)
                case .connectionReport:
                    DirectConnectionReportView(model: model)
                case .profiles:
                    DirectConnectionProfilesView(model: model)
                case .recovery:
                    DirectRecoveryView(model: model)
                }
            }
            .modifier(ServerPickerChrome())
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView { result in
                handleQRScanResult(result)
            }
        }
        .sheet(item: $importRequest) { request in
            NavigationSheet(title: "Импорт подписки") {
                NewProfileView(request, onSuccess: { profile in
                    await SharedPreferences.selectedProfileID.set(profile.mustID)
                    environments.profileUpdate.send()
                    await model.reloadSubscriptions()
                    importRequest = nil
                    if model.importFromAccessChoice {
                        model.handleImportedProfileActivated(subscriptionID: profile.mustID)
                    }
                })
                .environmentObject(environments)
            }
        }
        .sheet(item: $environments.pendingImportRemoteProfile) { request in
            NavigationSheet(title: "Импорт подписки", onDismiss: {
                environments.profileUpdate.send()
            }, content: {
                NewProfileView(.init(name: request.name, url: request.url), onSuccess: { profile in
                    await SharedPreferences.selectedProfileID.set(profile.mustID)
                    environments.profileUpdate.send()
                    await model.reloadSubscriptions()
                    if model.importFromAccessChoice {
                        model.handleImportedProfileActivated(subscriptionID: profile.mustID)
                    }
                })
                .environmentObject(environments)
            })
        }
    }

    private var appHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("VPN DIRECT").font(.system(size: 16, weight: .bold))
                Text("PRIVATE NETWORK").microLabel()
            }
            Spacer()
            Text("VPN / \(String(format: "%02d", model.headerPageIndex))").microLabel()
            Button {
                model.isMenuOpen.toggle()
                HapticManager.shared.play(model.isMenuOpen ? .menuOpened : .menuClosed)
            } label: {
                ZStack {
                    if model.isMenuOpen {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                    } else {
                        VStack(spacing: 5) {
                            Capsule().fill(DS.ink).frame(width: 16, height: 1.5)
                            Capsule().fill(DS.ink).frame(width: 16, height: 1.5)
                        }
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .background(model.isMenuOpen ? DS.ink : Color.clear)
                .foregroundStyle(model.isMenuOpen ? DS.acid : DS.ink)
                .overlay(Rectangle().stroke(DS.ink, lineWidth: 1))
            }
            .buttonStyle(HapticButtonStyle())
            .padding(.leading, 8)
        }
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .frame(height: 58)
        .overlay(alignment: .bottom) { Hairline() }
        .zIndex(20)
        .background(DS.paper)
    }

    private var addSubscriptionMenu: some View {
        let actions: [(String, String, String, String, () -> Void)] = [
            ("01", "Отсканировать QR", "Открыть камеру", "qrcode.viewfinder", { showQRScanner = true }),
            ("02", "Вставить из буфера", "Использовать скопированную ссылку", "doc.on.clipboard", { pasteFromClipboard() }),
            ("03", "Ручной ввод", "Ввести URL подписки", "arrow.right", {
                model.selectedTab = .subscriptions
                model.openDetail(.newConfiguration)
            }),
        ]

        return VStack(spacing: 0) {
            HStack {
                Text("ДОБАВИТЬ ПОДПИСКУ").microLabel(color: .white.opacity(0.48))
                Spacer()
                Text("03 ВАРИАНТА").microLabel(color: .white.opacity(0.48))
            }
            .padding(16)

            ForEach(actions, id: \.0) { item in
                Button {
                    model.isMenuOpen = false
                    item.4()
                    HapticManager.shared.play(item.0 == "02" ? .imported : .navigation)
                } label: {
                    HStack(spacing: 13) {
                        Text(item.0).microLabel(color: .white.opacity(0.35))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.1).font(.system(size: 14, weight: .medium))
                            Text(item.2).font(.system(size: 10)).foregroundStyle(.white.opacity(0.46))
                        }
                        Spacer()
                        Image(systemName: item.3).foregroundStyle(DS.acid)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 68)
                    .contentShape(Rectangle())
                }
                .buttonStyle(HapticButtonStyle())
                .overlay(alignment: .top) { Hairline(color: .white.opacity(0.1)) }
            }
        }
        .foregroundStyle(.white)
        .frame(width: min(UIScreen.main.bounds.width - 32, 350))
        .background(DS.ink)
        .shadow(color: .black.opacity(0.24), radius: 24, y: 12)
    }

    private var bottomNavigation: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                Button {
                    model.select(tab: tab)
                } label: {
                    VStack(spacing: 5) {
                        Text(String(format: "%02d", tab.rawValue)).microLabel(color: model.selectedTab == tab ? DS.green : DS.muted)
                        Text(tab.title)
                            .font(.system(size: 11, weight: model.selectedTab == tab ? .semibold : .regular))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(model.selectedTab == tab ? DS.acid.opacity(0.14) : .clear)
                }
                .buttonStyle(HapticButtonStyle())
            }
        }
        .frame(height: 64)
        .overlay(alignment: .top) { Hairline() }
    }

    private func pasteFromClipboard() {
        guard let string = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty
        else {
            model.alert = AlertState(errorMessage: String(localized: "Буфер обмена пуст."))
            return
        }
        applyImportString(string)
    }

    private func handleQRScanResult(_ result: QRScanResult) {
        switch result {
        case let .qrCode(string, _):
            applyImportString(string)
            showQRScanner = false
        case .qrsData:
            model.alert = AlertState(errorMessage: String(localized: "Используйте QR с vless:// или https:// ссылкой подписки."))
            showQRScanner = false
        }
    }

    private func applyImportString(_ raw: String) {
        let trimmed = normalizeImportString(raw)
        if VLESSConfigBuilder.isVLESSLink(trimmed) {
            let name = (try? VLESSConfigBuilder.parse(trimmed))?.name ?? ""
            importRequest = NewProfileView.ImportRequest(name: name, url: trimmed)
            return
        }
        if SubscriptionConfigBuilder.isHTTPURL(trimmed) {
            importRequest = NewProfileView.ImportRequest(
                name: SubscriptionConfigBuilder.suggestedName(for: trimmed),
                url: trimmed
            )
            return
        }
        var error: NSError?
        let remoteProfile = LibboxParseRemoteProfileImportLink(trimmed, &error)
        if let error {
            model.alert = AlertState(action: "parse import link", error: error)
            return
        }
        guard let remoteProfile else {
            model.alert = AlertState(errorMessage: String(localized: "Нужна ссылка vless:// или https:// подписки."))
            return
        }
        importRequest = NewProfileView.ImportRequest(name: remoteProfile.name, url: remoteProfile.url)
    }

    private func normalizeImportString(_ raw: String) -> String {
        AutoSubscriptionImporter.normalizeImportURL(raw)
    }
}

private struct ServerPickerChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(0)
        } else if #available(iOS 16.0, *) {
            content
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}

#endif
