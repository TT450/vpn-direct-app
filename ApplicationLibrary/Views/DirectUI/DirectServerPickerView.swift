import SwiftUI

#if os(iOS)

struct DirectServerPickerView: View {
    @ObservedObject var model: VPNConnectionModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            DirectServerPickerContent(
                model: model,
                serverSource: .activeSubscription,
                selectServer: { model.select(serverID: $0) }
            )
        }
        .background(DS.paper.ignoresSafeArea())
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text("01").microLabel(color: DS.green)
                    Rectangle()
                        .fill(DS.acid)
                        .frame(width: 14, height: 2)
                    Text("SERVER / LOCATIONS").microLabel()
                }

                Text("Локации")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Выберите сервер для текущего подключения")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(DS.ink)
                    .foregroundStyle(DS.acid)
            }
            .buttonStyle(HapticButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 15)
    }
}

/// Shared server list + auto row used by the change-server sheet and the Локации tab.
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
        case favorites = "Избранное"
        case history = "Недавние"
    }

    private var servers: [VPNServer] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let source: [VPNServer]
        switch tab {
        case .all:
            source = snapshotServers
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
                        autoSelectionRow
                    }

                    listHeader

                    if servers.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(servers.enumerated()), id: \.element.id) { index, server in
                            DirectServerPickerRow(
                                model: model,
                                index: index + 1,
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
        .onChangeCompat(of: model.activeSubscriptionID) { _ in captureSnapshot() }
        .onChangeCompat(of: model.isPingingServers) { pinging in
            if !pinging { captureSnapshot() }
        }
    }

    private var currentLocationLabel: String {
        if let label = model.activeServer?.locationLabel, !label.isEmpty {
            return label
        }
        if model.usesAutoSelection, model.isProtected {
            return "Определяем…"
        }
        return "—"
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
        HStack(spacing: 0) {
            ForEach(PickerTab.allCases, id: \.rawValue) { item in
                Button {
                    tab = item
                } label: {
                    HStack(spacing: 5) {
                        Text(item.rawValue)
                            .font(.system(size: 10, weight: tab == item ? .semibold : .medium))

                        if item == .favorites {
                            Text(String(format: "%02d", model.favoriteServerIDs.count))
                                .microLabel(color: tab == item ? DS.green : DS.muted)
                        }
                    }
                    .foregroundStyle(DS.ink)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(tab == item ? DS.ink : DS.line.opacity(0.55))
                            .frame(height: tab == item ? 2 : 1)
                            .padding(.horizontal, tab == item ? 16 : 0)
                    }
                }
                .buttonStyle(HapticButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 5)
    }

    private var listHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("02 / \((snapshotName.isEmpty ? "VPN DIRECT" : snapshotName).uppercased())")
                    .microLabel(color: DS.green)
                Text(tab == .all ? "Доступные серверы" : tab.rawValue)
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

    private var autoSelectionRow: some View {
        Button {
            selectServer(nil)
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    Rectangle()
                        .fill(model.usesAutoSelection ? DS.ink : DS.panel)
                    Text("A")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.acid)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("SMART ROUTE").microLabel(color: DS.green)
                        if model.usesAutoSelection {
                            Text("АКТИВНО").microLabel(color: DS.ink)
                        }
                    }
                    Text("Автовыбор")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.ink)
                    Text("Лучший маршрут по задержке и доступности")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(DS.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 5)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("СЕЙЧАС").microLabel()
                    Text(currentLocationLabel)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DS.ink)
                        .lineLimit(1)
                    Text(model.activeServer?.pingLabel ?? (model.usesAutoSelection && model.isProtected ? "…" : "—"))
                        .microLabel(color: DS.green)
                }

                Image(systemName: model.usesAutoSelection ? "checkmark" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(model.usesAutoSelection ? DS.green : DS.muted)
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 76)
            .background(model.usesAutoSelection ? DS.acid.opacity(0.12) : Color.clear)
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
                    Image(systemName: query.isEmpty ? "server.rack" : "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.acid)
                }

            Text(query.isEmpty ? "Нет доступных серверов" : "Ничего не найдено")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.ink)

            Text(query.isEmpty ? "Для этой подписки пока нет локаций" : "Попробуйте другое название страны или города")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func captureSnapshot() {
        switch serverSource {
        case .activeSubscription:
            let sub = model.activeSubscription
            snapshotServers = (sub?.servers ?? []).filter { server in
                let id = server.id.lowercased()
                return !id.isEmpty && id != "direct" && id != "auto"
            }
            snapshotName = sub?.name ?? ""
        case .liveDirect:
            snapshotServers = model.liveDirectServers
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

    private var isSelected: Bool {
        model.selectedServerID == server.id
    }

    private var pingIsHigh: Bool {
        server.ping > 100
    }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                selectServer(server.id)
            } label: {
                HStack(spacing: 10) {
                    Text(String(format: "%02d", index))
                        .microLabel(color: isSelected ? DS.green : DS.muted)
                        .frame(width: 21, alignment: .leading)

                    FlagImage(code: server.countryCode, width: 31, height: 21)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(server.city.uppercased())
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text(server.country.uppercased())
                            .microLabel(color: isSelected ? DS.green : DS.muted)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 3) {
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
                .frame(maxWidth: .infinity, minHeight: 61, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(HapticButtonStyle())

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

            Image(systemName: isSelected ? "checkmark" : "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isSelected ? DS.green : DS.muted)
                .frame(width: 24)
        }
        .padding(.horizontal, 20)
        .background(isSelected ? DS.acid.opacity(0.10) : Color.clear)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

#endif
