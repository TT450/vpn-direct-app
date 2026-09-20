import SwiftUI

#if os(iOS)

struct DirectServerPickerView: View {
    @ObservedObject var model: VPNConnectionModel
    @Environment(\.dismiss) private var dismiss

    private var locationCount: Int {
        let servers = model.activeSubscription?.servers ?? model.liveDirectServers
        return servers.filter { server in
            let id = server.id.lowercased()
            return !id.isEmpty && id != "direct" && id != "auto"
        }.count
    }

    var body: some View {
        SheetScaffold(
            kicker: "ЛОКАЦИИ / \(String(format: "%02d", locationCount))",
            title: "Все локации",
            close: { dismiss() },
            embedsScroll: false
        ) {
            VStack(spacing: 0) {
                DirectPingAllButton(model: model)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                DirectServerPickerContent(
                    model: model,
                    serverSource: .activeSubscription,
                    selectServer: { model.select(serverID: $0) }
                )
            }
        }
    }
}

/// Shared black ping control (home «Все локации» sheet + locations page).
struct DirectPingAllButton: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        Button {
            model.pingAllServers()
        } label: {
            ZStack {
                HStack(spacing: 10) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.paper)
                    Text("ПИНГ")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.paper)
                }

                if model.isPingingServers {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                            .tint(DS.paper)
                            .padding(.trailing, 14)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(DS.ink)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .disabled(model.isPingingServers || model.activeSubscription == nil)
        .opacity(model.activeSubscription == nil ? 0.45 : 1)
        .accessibilityLabel("Проверить пинг всех локаций")
    }
}

/// Shared server list + mode row used by the locations bottomsheet.
struct DirectServerPickerContent: View {
    enum ServerSource {
        case activeSubscription
        case liveDirect
    }

    @ObservedObject var model: VPNConnectionModel
    var serverSource: ServerSource = .activeSubscription
    var selectServer: (String?) -> Void

    @State private var query = ""
    @State private var tab = PickerTab.all
    /// Snapshot so 1 Hz runtime / traffic publishes do not re-sort the whole list.
    @State private var snapshotServers: [VPNServer] = []
    @State private var snapshotName = ""

    private enum PickerTab: String, CaseIterable {
        case all = "Все"
        case unlimited = "Безлимитные"
        case limited = "Лимитные"
        case favorites = "Избранное"
        case history = "Недавние"
    }

    private var servers: [VPNServer] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let source: [VPNServer]
        switch tab {
        case .all:
            source = snapshotServers
        case .unlimited:
            source = snapshotServers.filter { model.locationCap(for: $0) == nil }
        case .limited:
            source = snapshotServers.filter { model.locationCap(for: $0) != nil }
        case .favorites:
            let favs = model.favoriteServerIDs
            source = snapshotServers.filter { favs.contains($0.id) }
        case .history:
            source = model.recentServerIDs.compactMap { id in
                snapshotServers.first(where: { $0.id == id })
            }
        }

        let filtered: [VPNServer]
        if value.isEmpty {
            filtered = source
        } else {
            filtered = source.filter {
                $0.city.localizedCaseInsensitiveContains(value)
                    || $0.country.localizedCaseInsensitiveContains(value)
                    || $0.locationLabel.localizedCaseInsensitiveContains(value)
                    || snapshotName.localizedCaseInsensitiveContains(value)
            }
        }

        // Happ-style: measured first (lowest ping), unmeasured at the end.
        return filtered.sorted { lhs, rhs in
            switch (lhs.ping > 0, rhs.ping > 0) {
            case (true, true): return lhs.ping < rhs.ping
            case (true, false): return true
            case (false, true): return false
            case (false, false):
                return lhs.locationLabel.localizedCaseInsensitiveCompare(rhs.locationLabel) == .orderedAscending
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            tabs

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if query.isEmpty, tab == .all {
                        connectionModeRow

                        if let pinned = pinnedServer {
                            DirectServerPickerRow(
                                model: model,
                                index: 1,
                                server: pinned,
                                selectServer: selectServer,
                                forceSelected: isPinnedActive(pinned)
                            )
                        }
                    }

                    listHeader

                    if remainingServers.isEmpty, pinnedServer == nil {
                        emptyState
                    } else {
                        ForEach(Array(remainingServers.enumerated()), id: \.element.id) { index, server in
                            DirectServerPickerRow(
                                model: model,
                                index: (pinnedServer != nil && query.isEmpty && tab == .all ? 2 : 1) + index,
                                server: server,
                                selectServer: selectServer
                            )
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .hapticScrollThresholds()
        .hapticSelection(tab)
        .onAppear {
            captureSnapshot()
            model.requestURLTest()
        }
        .task {
            await model.refreshLocationCaps()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                await model.refreshLocationCaps()
            }
        }
        .onChangeCompat(of: model.activeSubscriptionID) { _ in captureSnapshot() }
        .onChangeCompat(of: model.isPingingServers) { pinging in
            if !pinging { captureSnapshot() }
        }
        .onChangeCompat(of: model.selectedServerID) { _ in captureSnapshot() }
        .onChangeCompat(of: model.connectionMode) { _ in captureSnapshot() }
        .onChangeCompat(of: model.locationCaps) { _ in captureSnapshot() }
    }

    /// Location currently driven by the active connection mode (or manual pick).
    private var pinnedServer: VPNServer? {
        guard let pinned = model.pinnedLocationServer else { return nil }
        return snapshotServers.first(where: { $0.id == pinned.id })
    }

    private var remainingServers: [VPNServer] {
        guard query.isEmpty, tab == .all, let pinned = pinnedServer else {
            return servers
        }
        return servers.filter { $0.id != pinned.id }
    }

    private func isPinnedActive(_ server: VPNServer) -> Bool {
        if model.selectedServerID == server.id { return true }
        if model.activeServer?.id == server.id { return true }
        return false
    }

    private var modeDisplayTitle: String { model.connectionModeDisplayTitle }

    private var modeDisplaySubtitle: String { model.connectionModeDisplaySubtitle }

    private var modeBadgeLetter: String {
        switch model.connectionMode {
        case "Авто": return "A"
        case "Пользовательский": return "M"
        case "Максимальная скорость": return "S"
        case "Стабильный": return "R"
        case "Для видео": return "V"
        case "5G", "Антиблокировка": return "X"
        default: return "A"
        }
    }

    private var isModeDrivenSelection: Bool {
        model.connectionMode != "Пользовательский"
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.green)

            TextField("Страна или город", text: $query)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Text("СБРОС")
                        .microLabel(color: DS.green)
                }
                .buttonStyle(HapticButtonStyle())
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 44)
        .background(Color.white.opacity(0.45))
        .overlay(Rectangle().stroke(DS.line))
        .padding(.horizontal, 20)
    }

    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(PickerTab.allCases, id: \.rawValue) { item in
                    Button {
                        tab = item
                    } label: {
                        HStack(spacing: 5) {
                            Text(item.rawValue)
                                .font(.system(size: 10, weight: tab == item ? .semibold : .medium))
                                .lineLimit(1)

                            if item == .favorites {
                                Text(String(format: "%02d", model.favoriteServerIDs.count))
                                    .microLabel(color: tab == item ? DS.green : DS.muted)
                            } else if item == .limited {
                                Text(String(format: "%02d", limitedCount))
                                    .microLabel(color: tab == item ? DS.green : DS.muted)
                            } else if item == .unlimited {
                                Text(String(format: "%02d", unlimitedCount))
                                    .microLabel(color: tab == item ? DS.green : DS.muted)
                            }
                        }
                        .foregroundStyle(DS.ink)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 40)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(tab == item ? DS.ink : DS.line.opacity(0.55))
                                .frame(height: tab == item ? 2 : 1)
                                .padding(.horizontal, tab == item ? 8 : 0)
                        }
                    }
                    .buttonStyle(HapticButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 5)
    }

    private var unlimitedCount: Int {
        snapshotServers.filter { model.locationCap(for: $0) == nil }.count
    }

    private var limitedCount: Int {
        snapshotServers.filter { model.locationCap(for: $0) != nil }.count
    }

    private var listHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("02 / \((snapshotName.isEmpty ? "VPN DIRECT" : snapshotName).uppercased())")
                    .microLabel(color: DS.green)
                Text(listHeaderTitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.ink)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%02d", servers.count))
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.ink)
                Text("ЛОКАЦИЙ").microLabel()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 11)
        .background(DS.ink.opacity(0.045))
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var listHeaderTitle: String {
        switch tab {
        case .all: return "Доступные серверы"
        case .unlimited: return "Безлимитные"
        case .limited: return "Лимитные"
        case .favorites, .history: return tab.rawValue
        }
    }

    private var connectionModeRow: some View {
        Button {
            model.activeSheet = .profiles
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    Rectangle()
                        .fill(isModeDrivenSelection ? DS.ink : DS.panel)
                    Text(modeBadgeLetter)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.acid)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("РЕЖИМ").microLabel(color: DS.green)
                        Text("АКТИВНО").microLabel(color: DS.ink)
                    }
                    Text(modeDisplayTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(modeDisplaySubtitle)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(DS.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 5)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("ПИНГ").microLabel()
                    Text(model.activeServer?.pingLabel ?? (model.isProtected ? "…" : "—"))
                        .microLabel(color: DS.green)
                }

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DS.muted)
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 76)
            .background(DS.acid.opacity(0.12))
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(DS.ink)
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: emptyStateIcon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.acid)
                }

            Text(emptyStateTitle)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.ink)

            Text(emptyStateSubtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyStateIcon: String {
        if !query.isEmpty { return "magnifyingglass" }
        switch tab {
        case .limited: return "chart.bar.fill"
        case .unlimited: return "infinity"
        case .favorites: return "star"
        case .history: return "clock"
        case .all: return "server.rack"
        }
    }

    private var emptyStateTitle: String {
        if !query.isEmpty { return "Ничего не найдено" }
        switch tab {
        case .limited: return "Нет лимитных локаций"
        case .unlimited: return "Нет безлимитных локаций"
        case .favorites: return "Нет избранных"
        case .history: return "Нет недавних"
        case .all: return "Нет доступных серверов"
        }
    }

    private var emptyStateSubtitle: String {
        if !query.isEmpty { return "Попробуйте другое название страны или города" }
        switch tab {
        case .limited: return "Лимитные локации появятся после входа в приложение"
        case .unlimited: return "В этой подписке пока только лимитные или пустой список"
        case .favorites: return "Отметьте локации звездой в списке"
        case .history: return "Выберите локацию — она появится здесь"
        case .all: return "Для этой подписки пока нет локаций"
        }
    }

    private func captureSnapshot() {
        switch serverSource {
        case .activeSubscription:
            snapshotServers = model.serversForLocationPicker.filter { server in
                let id = server.id.lowercased()
                return !id.isEmpty && id != "direct" && id != "auto"
            }
            snapshotName = model.activeSubscription?.name ?? ""
        case .liveDirect:
            snapshotServers = model.serversForLocationPicker
            snapshotName = model.premiumSubscription?.name
                ?? model.freeSubscription?.name
                ?? "VPN DIRECT"
        }
    }
}

private struct DirectServerPickerRow: View {
    @ObservedObject var model: VPNConnectionModel
    let index: Int
    let server: VPNServer
    var selectServer: (String?) -> Void
    var forceSelected: Bool = false

    private var isSelected: Bool {
        if forceSelected { return true }
        return model.selectedServerID == server.id
    }

    private var pingIsHigh: Bool {
        server.ping > 100
    }

    var body: some View {
        let exhausted = model.isLocationCapExhausted(server)
        HStack(spacing: 0) {
            Button {
                guard !exhausted else {
                    selectServer(nil) // no-op path; parent may ignore
                    model.alert = AlertState(errorMessage: String(localized: "Лимит этой локации исчерпан — подключение недоступно."))
                    return
                }
                selectServer(server.id)
            } label: {
                HStack(spacing: 10) {
                    Text(String(format: "%02d", index))
                        .microLabel(color: isSelected ? DS.green : DS.muted)
                        .frame(width: 21, alignment: .leading)

                    FlagImage(
                        code: server.countryCode,
                        width: 31,
                        height: 21,
                        fallbackLabel: model.flagFallbackLabel(for: server)
                    )
                        .opacity(exhausted ? 0.45 : 1)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(server.locationLabel)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(exhausted ? DS.muted : DS.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text(model.locationQuotaSubtitle(for: server))
                            .microLabel(color: exhausted ? DS.danger : (isSelected ? DS.green : DS.muted))

                        if let used = model.locationQuotaUsedFraction(for: server) {
                            DirectLocationQuotaBar(usedFraction: used, height: 3.5)
                                .padding(.top, 2)
                                .frame(maxWidth: 160, alignment: .leading)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 3) {
                        if exhausted {
                            Text("НЕТ")
                                .microLabel(color: DS.danger)
                        } else {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(pingIsHigh ? DS.danger : DS.green)
                                    .frame(width: 5, height: 5)
                                Text(server.pingLabel)
                                    .microLabel(color: pingIsHigh ? DS.danger : DS.ink)
                            }

                            HStack(spacing: 4) {
                                Text("LOAD").microLabel()
                                Text("\(server.load)%")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(DS.muted)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 61, alignment: .leading)
                .contentShape(Rectangle())
                .opacity(exhausted ? 0.85 : 1)
            }
            .buttonStyle(HapticButtonStyle())
            .disabled(exhausted)

            Button {
                model.toggleFavorite(serverID: server.id)
            } label: {
                Image(systemName: model.favoriteServerIDs.contains(server.id) ? "star.fill" : "star")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(model.favoriteServerIDs.contains(server.id) ? DS.green : DS.muted)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())
            .disabled(exhausted)

            Image(systemName: exhausted ? "lock.fill" : (isSelected ? "checkmark" : "chevron.right"))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(exhausted ? DS.danger : (isSelected ? DS.green : DS.muted))
                .frame(width: 24)
        }
        .padding(.horizontal, 20)
        .background(isSelected ? DS.acid.opacity(0.10) : Color.clear)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

#endif
