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
                            DirectNativeAccessChoiceView(model: model)
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

// MARK: - Access choice shown from the Home screen

private struct DirectNativeAccessChoiceView: View {
    @ObservedObject var model: VPNConnectionModel
    private var imported: [VPNSubscriptionItem] { model.importedSubscriptions }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    model.detailPage = nil
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                        Text("Главная")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.muted)
                }
                .buttonStyle(HapticButtonStyle())

                PageHeading(
                    kicker: "ПОДКЛЮЧЕНИЕ / ПОДПИСКИ",
                    title: "Выберите подписку",
                    subtitle: "VPN Direct — первым, добавленные подписки — ниже"
                )
                .padding(.top, 17)

                if let context = model.accessChoiceContext {
                    Text(context)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.acid.opacity(0.22))
                        .overlay(Rectangle().stroke(DS.line))
                        .padding(.top, 16)
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("VPN DIRECT").microLabel(color: DS.acid)
                            Text("Родная подписка").font(.system(size: 20, weight: .semibold))
                            Text("Встроенный доступ · без стороннего провайдера")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.52))
                        }
                        Spacer(minLength: 10)
                        Text("ОСНОВНАЯ")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.acid)
                            .padding(.horizontal, 8)
                            .frame(height: 27)
                            .overlay(Rectangle().stroke(DS.acid.opacity(0.72)))
                    }
                    .padding(16)

                    Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                    DirectNativeChoiceRow(
                        mark: "FREE",
                        title: "VPN Direct Free",
                        subtitle: model.isFreeAccessReady
                            ? "\(model.freeRemainingDisplayText) · \(model.freeTrafficMB) МБ"
                            : "3 рекламы → 1 час и 200 МБ",
                        isActive: model.activeAccess == .free
                    ) {
                        model.clearAccessChoiceContext()
                        model.handleAccessChoiceFree()
                    }

                    Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                    DirectNativeChoiceRow(
                        mark: "PLUS",
                        title: "VPN Direct Premium",
                        subtitle: model.isPremiumAccessReady
                            ? "\(model.premiumRemainingDays) дн · \(model.premiumTrafficGB) ГБ · \(model.premiumDevicesUsed)/\(model.premiumDeviceLimit)"
                            : "Без рекламы · от 1 месяца",
                        isActive: model.activeAccess == .premium
                    ) {
                        model.clearAccessChoiceContext()
                        model.handleAccessChoicePremium()
                    }
                }
                .foregroundStyle(.white)
                .background(DS.ink)
                .overlay(Rectangle().stroke(DS.acid.opacity(0.72), lineWidth: 1))
                .padding(.top, 24)

                if !imported.isEmpty {
                    HStack {
                        Text("ДОБАВЛЕННЫЕ ПОДПИСКИ").microLabel(color: DS.ink)
                        Spacer()
                        Text(String(format: "%02d", imported.count)).microLabel(color: DS.green)
                    }
                    .frame(height: 36)
                    .overlay(alignment: .top) { Hairline(color: DS.ink) }
                    .padding(.top, 24)

                    ForEach(Array(imported.enumerated()), id: \.element.id) { index, subscription in
                        DirectImportedChoiceRow(model: model, subscription: subscription)
                            .padding(.top, index == 0 ? 0 : 1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(DS.paper)
    }
}

private struct DirectNativeChoiceRow: View {
    let mark: String
    let title: String
    let subtitle: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(mark)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.ink)
                    .frame(width: 48, height: 42)
                    .background(DS.acid)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(title).font(.system(size: 13, weight: .semibold))
                        if isActive {
                            Text("АКТИВНА").microLabel(color: DS.acid)
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                Image(systemName: isActive ? "checkmark" : "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.acid)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .background(isActive ? Color.white.opacity(0.07) : Color.clear)
    }
}

private struct DirectImportedChoiceRow: View {
    @ObservedObject var model: VPNConnectionModel
    let subscription: VPNSubscriptionItem

    private var isActive: Bool { model.isSubscriptionActive(subscription.id) }

    var body: some View {
        Button {
            model.clearAccessChoiceContext()
            model.handleImportedProfileActivated(subscriptionID: subscription.id)
        } label: {
            HStack(spacing: 12) {
                Text("URL")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(isActive ? DS.acid : DS.ink)
                    .frame(width: 48, height: 42)
                    .background(isActive ? DS.ink : Color.white.opacity(0.72))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(subscription.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.ink)
                            .lineLimit(1)
                        if isActive {
                            Text("АКТИВНА").microLabel(color: DS.green)
                        }
                    }
                    Text("Внешний провайдер · \(subscription.expiry)")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                Image(systemName: isActive ? "checkmark" : "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isActive ? DS.green : DS.muted)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .background(isActive ? DS.acid.opacity(0.16) : Color.white.opacity(0.72))
        .overlay(Rectangle().stroke(isActive ? DS.green : DS.line))
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
