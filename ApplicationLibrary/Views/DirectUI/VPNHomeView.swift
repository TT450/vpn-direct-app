import Libbox
import Library
import NetworkExtension
import SwiftUI
import UIKit

#if os(iOS)

private enum DirectChrome {
    static let appBarHeight: CGFloat = 58
    static let tabBarHeight: CGFloat = 46
}

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
        GeometryReader { proxy in
            let chromeWidth = proxy.size.width

            ZStack(alignment: .top) {
                DS.paper.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Reserve space for the overlay app bar — header itself is not in this tree.
                    Color.clear.frame(height: DirectChrome.appBarHeight)

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
                        case .importFile:
                            DirectImportFileView(model: model)
                        case .importConfigText:
                            DirectImportConfigTextView(model: model)
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
                            case .premiumPlans:
                                DirectPlansView(model: model)
                            case .planConstructor:
                                DirectConstructorView(model: model)
                            case .payment:
                                DirectPaymentMethodView(model: model)
                            case .addOns:
                                DirectAddOnsView(model: model)
                            case .authLogin:
                                DirectAuthLoginView(model: model)
                            case .authEmail:
                                DirectAuthEmailView(model: model)
                            case .authCode:
                                DirectAuthCodeView(model: model)
                            case .authRegister:
                                DirectAuthRegisterView(model: model)
                            case .authRecovery:
                                DirectAuthRecoveryView(model: model)
                            case .authBot:
                                DirectAuthBotView(model: model)
                            case .authPhone:
                                DirectAuthPhoneView(model: model)
                            case .authPhoneCode:
                                DirectAuthPhoneCodeView(model: model)
                            case .authSuccess:
                                DirectAuthSuccessView(model: model)
                            case .paymentProcessing:
                                DirectPaymentProcessingView(
                                    title: "Оплата",
                                    subtitle: "Подтверждаем оплату…"
                                )
                            case .paymentWaiting:
                                DirectPaymentWaitingView(model: model)
                            case .paymentCancelled:
                                DirectPaymentCancelledView(
                                    retry: { model.retryCheckout() },
                                    changeMethod: { model.openDetail(.payment) }
                                )
                            case .paymentError:
                                DirectPaymentErrorView(message: model.paymentErrorMessage) {
                                    model.retryCheckout()
                                }
                            case .paymentSuccess:
                                DirectPaymentSuccessView(
                                    title: "Подписка активна",
                                    price: model.lastSuccessPrice > 0 ? model.lastSuccessPrice : model.checkoutPrice,
                                    period: "\(model.lastSuccessPeriodDays) дней",
                                    activationPending: model.paymentActivationPending,
                                    openLocations: {
                                        model.closeDetail()
                                        model.select(tab: .locations)
                                    },
                                    openHome: {
                                        model.closeDetail()
                                        model.select(tab: .home)
                                    },
                                    refreshActivation: {
                                        model.startPaymentStatusPolling()
                                        Task { await model.refreshDirectAccount() }
                                    }
                                )
                            case .account:
                                DirectAccountView(model: model)
                            case .externalPay(let url):
                                DirectExternalPayWebView(
                                    url: url,
                                    onClose: {
                                        model.beginPaymentWaiting()
                                    },
                                    onSuccess: {
                                        model.beginPaymentWaiting()
                                    }
                                )
                            }
                        } else {
                            switch model.selectedTab {
                            case .home:
                                DirectHomePage(model: model)
                            case .locations:
                                DirectServersPage(model: model)
                            case .management:
                                DirectManagementPage(model: model) {
                                    model.isMenuOpen = true
                                }
                            case .profile:
                                DirectProfilePage(model: model)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .directRefreshable(enabled: model.detailPage != nil || model.selectedTab != .home) {
                        await model.performPullToRefresh()
                    }

                    bottomNavigation
                }
                .frame(width: chromeWidth, height: proxy.size.height)

                if model.isMenuOpen {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea(edges: .bottom)
                        .padding(.top, DirectChrome.appBarHeight)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.isMenuOpen = false
                            HapticManager.shared.play(.menuClosed)
                        }
                        .zIndex(30)

                    addSubscriptionMenu
                        .padding(.top, DirectChrome.appBarHeight + 4)
                        .padding(.trailing, 16)
                        .zIndex(40)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Overlay app bar: width locked to container, never laid out with tab content.
                appHeader
                    .frame(width: chromeWidth)
                    .zIndex(50)
            }
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
            consumeWidgetToggleIfNeeded()
            consumeBotAuthDeepLinkIfNeeded()
            consumePayDeepLinkIfNeeded()
            consumePlansDeepLinkIfNeeded()
            consumeAccountDeepLinkIfNeeded()
            model.resumeOpenPaymentsIfNeeded()
        }
        .onChangeCompat(of: scenePhase) { phase in
            if phase == .active {
                environments.extensionProfile?.refreshStatus()
                model.syncFromExtension()
                consumeWidgetToggleIfNeeded()
                consumeBotAuthDeepLinkIfNeeded()
                consumePayDeepLinkIfNeeded()
                consumePlansDeepLinkIfNeeded()
                consumeAccountDeepLinkIfNeeded()
                model.resumeOpenPaymentsIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vpnDirectWidgetToggle)) { _ in
            consumeWidgetToggleIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vpnDirectOpenBotAuth)) { _ in
            consumeBotAuthDeepLinkIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vpnDirectPaySuccess)) { _ in
            consumePayDeepLinkIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vpnDirectOpenPlans)) { _ in
            consumePlansDeepLinkIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vpnDirectOpenAccount)) { _ in
            consumeAccountDeepLinkIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vpnDirectCheckoutPaid)) { _ in
            // Silent background poll — do not yank into waiting from other screens.
            model.resumeOpenPaymentsIfNeeded(forceWaitingUI: false)
            model.startPaymentStatusPolling()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vpnDirectPayFail)) { _ in
            consumePayDeepLinkIfNeeded()
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
            .directRefreshable {
                await model.performPullToRefresh()
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
                    } else {
                        model.activateNewlyImportedSubscription(profile.mustID)
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
                    } else {
                        model.activateNewlyImportedSubscription(profile.mustID)
                    }
                })
                .environmentObject(environments)
            })
        }
    }

    private var appHeader: some View {
        HStack(spacing: 0) {
            if model.detailPage != nil {
                Button {
                    model.goBack()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.muted)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(HapticButtonStyle())
                .padding(.trailing, 8)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("VPN DIRECT").font(.system(size: 15, weight: .bold))
                Text("PRIVATE NETWORK").microLabel()
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 20)
        // Keep trailing controls out of the HStack flow — absolute pin to the bar edge.
        .overlay(alignment: .trailing) {
            HStack(spacing: 8) {
                Text("VPN / \(String(format: "%02d", model.headerPageIndex))")
                    .microLabel()
                Button {
                    model.isMenuOpen.toggle()
                    HapticManager.shared.play(model.isMenuOpen ? .menuOpened : .menuClosed)
                } label: {
                    ZStack {
                        if model.isMenuOpen {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .medium))
                        } else {
                            VStack(spacing: 4) {
                                Capsule().fill(DS.ink).frame(width: 14, height: 1.5)
                                Capsule().fill(DS.ink).frame(width: 14, height: 1.5)
                            }
                        }
                    }
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .background(model.isMenuOpen ? DS.ink : Color.clear)
                    .foregroundStyle(model.isMenuOpen ? DS.acid : DS.ink)
                    .overlay(Rectangle().stroke(DS.ink, lineWidth: 1))
                }
                .buttonStyle(HapticButtonStyle())
            }
            .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: DirectChrome.appBarHeight)
        .background(DS.paper)
        .overlay(alignment: .bottom) { Hairline() }
        // Tab switches must never animate this chrome.
        .transaction { $0.animation = nil }
    }

    private var addSubscriptionMenu: some View {
        let actions: [(String, String, String, String, () -> Void)] = [
            ("01", "Отсканировать QR", "Ссылка подписки или share-link", "qrcode.viewfinder", { showQRScanner = true }),
            ("02", "Вставить из буфера", "Ссылка или готовый конфиг", "doc.on.clipboard", { pasteFromClipboard() }),
            ("03", "Ручной ввод ссылки", "vless / vmess / trojan / https", "link", {
                model.selectedTab = .management
                model.openDetail(.newConfiguration)
            }),
            ("04", "Импорт файла", "JSON, Clash, WireGuard, ovpn", "doc.badge.arrow.up", {
                model.selectedTab = .management
                model.openDetail(.importFile)
            }),
            ("05", "Вставить конфиг", "Текст JSON / YAML / URI-список", "doc.plaintext", {
                model.selectedTab = .management
                model.openDetail(.importConfigText)
            }),
        ]

        return VStack(spacing: 0) {
            HStack {
                Text("ДОБАВИТЬ ПОДПИСКУ").microLabel(color: .white.opacity(0.48))
                Spacer()
                Text("05 ВАРИАНТОВ").microLabel(color: .white.opacity(0.48))
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
                    VStack(spacing: 3) {
                        Text(String(format: "%02d", tab.rawValue)).microLabel(color: model.selectedTab == tab ? DS.green : DS.muted)
                        Text(tab.title)
                            .font(.system(size: 11, weight: model.selectedTab == tab ? .semibold : .regular))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .background(model.selectedTab == tab ? DS.acid.opacity(0.14) : .clear)
                }
                .buttonStyle(HapticButtonStyle())
            }
        }
        .frame(height: DirectChrome.tabBarHeight)
        .contentShape(Rectangle())
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
            model.alert = AlertState(errorMessage: String(localized: "Используйте QR со ссылкой подписки или share-link."))
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
        if SubscriptionConfigBuilder.isShareLinkContent(trimmed) {
            importRequest = NewProfileView.ImportRequest(
                name: SubscriptionConfigBuilder.suggestedName(forShareContent: trimmed),
                url: trimmed
            )
            return
        }
        if SubscriptionConfigBuilder.isHTTPURL(trimmed) {
            importRequest = NewProfileView.ImportRequest(
                name: SubscriptionConfigBuilder.suggestedName(for: trimmed),
                url: trimmed
            )
            return
        }
        // Raw config body (JSON / Clash / WG / URI list) — not a bare URL.
        if DirectLocalProfileImporter.looksLikeConfigContent(trimmed) {
            model.pendingImportConfigText = trimmed
            model.selectedTab = .management
            model.openDetail(.importConfigText)
            return
        }
        var error: NSError?
        let remoteProfile = LibboxParseRemoteProfileImportLink(trimmed, &error)
        if let error {
            model.alert = AlertState(action: "parse import link", error: error)
            return
        }
        guard let remoteProfile else {
            model.alert = AlertState(errorMessage: String(localized: "Нужна ссылка, share-link или конфиг (JSON / Clash / WG)."))
            return
        }
        importRequest = NewProfileView.ImportRequest(name: remoteProfile.name, url: remoteProfile.url)
    }

    private func normalizeImportString(_ raw: String) -> String {
        AutoSubscriptionImporter.normalizeImportURL(raw)
    }

    private func consumeWidgetToggleIfNeeded() {
        guard VPNDirectDeepLink.consumePendingToggle() else { return }
        // Let NE profile finish binding after cold start from widget.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            model.toggleConnection()
        }
    }

    private func consumeBotAuthDeepLinkIfNeeded() {
        guard VPNDirectDeepLink.consumePendingBotAuth() else { return }
        model.openBotAuthFromDeepLink()
    }

    private func consumePayDeepLinkIfNeeded() {
        if VPNDirectDeepLink.consumePendingPaySuccess() {
            model.beginPaymentWaiting()
            return
        }
        if VPNDirectDeepLink.consumePendingPayFail() {
            model.openDetail(.paymentCancelled)
        }
    }

    private func consumePlansDeepLinkIfNeeded() {
        guard VPNDirectDeepLink.consumePendingPlans() else { return }
        model.selectedTab = .home
        model.openDetail(.premiumPlans)
    }

    private func consumeAccountDeepLinkIfNeeded() {
        guard VPNDirectDeepLink.consumePendingAccount() else { return }
        model.selectedTab = .profile
        model.openDetail(.account)
    }
}

private struct ServerPickerChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(0)
                .preferredColorScheme(.light)
        } else if #available(iOS 16.0, *) {
            content
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.light)
        } else {
            content.preferredColorScheme(.light)
        }
    }
}

#endif
