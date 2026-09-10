import SwiftUI

#if os(iOS)

struct DirectServerPickerView: View {
    @ObservedObject var model: VPNConnectionModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var tab = PickerTab.all
    /// Snapshot so 1 Hz runtime / traffic publishes do not re-sort the whole list.
    @State private var snapshotServers: [VPNServer] = []
    @State private var snapshotName = ""
    @State private var snapshotUpdated = ""

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
            let recent = model.recentServerIDs
            source = recent.compactMap { id in snapshotServers.first(where: { $0.id == id }) }
        }
        let filtered: [VPNServer]
        if value.isEmpty {
            filtered = source
        } else {
            filtered = source.filter {
                $0.locationLabel.localizedCaseInsensitiveContains(value)
                    || $0.city.localizedCaseInsensitiveContains(value)
                    || $0.country.localizedCaseInsensitiveContains(value)
                    || snapshotName.localizedCaseInsensitiveContains(value)
            }
        }
        // Happ-style: measured first (lowest ping), unmeasured at the end.
        return filtered.sorted { lhs, rhs in
            switch (lhs.ping > 0, rhs.ping > 0) {
            case (true, true): return lhs.ping < rhs.ping
            case (true, false): return true
            case (false, true): return false
            case (false, false): return lhs.locationLabel.localizedCaseInsensitiveCompare(rhs.locationLabel) == .orderedAscending
            }
        }
    }

    private var pingModeLabel: String {
        ServerEndpointPing.preferredMode(isConnected: model.isConnected).label
    }

    var body: some View {
        let selectedID = model.selectedServerID
        let favorites = model.favoriteServerIDs
        let usesAuto = model.usesAutoSelection
        let activeLabel = model.activeServer?.locationLabel ?? "—"
        let activePing = model.activeServer?.pingLabel ?? "—"
        let list = servers

        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ПОДПИСКА / \(snapshotServers.count) ЛОКАЦИЙ").microLabel()
                    Text("Выбор локации").font(.system(size: 31, weight: .semibold))
                    Text("\(snapshotName) · только серверы активной подписки")
                        .font(.system(size: 11)).foregroundStyle(DS.muted)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").frame(width: 40, height: 40).background(DS.ink).foregroundStyle(DS.acid)
                }
                .buttonStyle(HapticButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 16)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(DS.muted)
                TextField("Найти страну или город", text: $query)
                    .textInputAutocapitalization(.never)
                if !query.isEmpty {
                    Button("СБРОС") { query = "" }.microLabel()
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color.white.opacity(0.52))
            .overlay(Rectangle().stroke(DS.line, lineWidth: 1))
            .padding(.horizontal, 20)

            HStack(spacing: 0) {
                ForEach(PickerTab.allCases, id: \.rawValue) { item in
                    Button {
                        tab = item
                    } label: {
                        HStack(spacing: 4) {
                            Text(item.rawValue)
                            if item == .favorites {
                                Text(String(format: "%02d", favorites.count))
                                    .microLabel(color: tab == item ? DS.green : DS.muted)
                            }
                        }
                        .font(.system(size: 11, weight: tab == item ? .semibold : .regular))
                        .foregroundStyle(tab == item ? DS.ink : DS.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(tab == item ? Color.white.opacity(0.72) : Color.clear)
                        .overlay(alignment: .bottom) {
                            if tab == item {
                                Rectangle().fill(DS.ink).frame(height: 2)
                            }
                        }
                    }
                    .buttonStyle(HapticButtonStyle())
                    if item != PickerTab.allCases.last {
                        Hairline().frame(width: 1).padding(.vertical, 8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color.white.opacity(0.52))
            .overlay(Rectangle().stroke(DS.line, lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Button {
                model.pingAllServers()
            } label: {
                HStack(spacing: 10) {
                    if model.isPingingServers {
                        ProgressView()
                            .tint(DS.acid)
                    } else {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundStyle(DS.acid)
                    }
                    Text(model.isPingingServers ? "Пинг…" : "Пинг")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(model.isPingingServers ? "ИЗМЕРЕНИЕ · \(pingModeLabel)" : pingModeLabel)
                        .microLabel(color: .white.opacity(0.45))
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(.white)
                .background(DS.ink)
            }
            .buttonStyle(HapticButtonStyle())
            .disabled(model.isPingingServers || snapshotServers.isEmpty)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if query.isEmpty, tab == .all {
                        AutoSelectionRow(
                            usesAuto: usesAuto,
                            activeLabel: activeLabel,
                            activePing: activePing,
                            onSelect: { model.select(serverID: nil) }
                        )
                    }

                    if !list.isEmpty {
                        HStack {
                            Text("01 / \(snapshotName.uppercased())").microLabel()
                            Spacer()
                            Text("\(list.count) ЛОКАЦИЙ · \(snapshotUpdated.uppercased())").microLabel()
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 42)
                        .background(DS.ink.opacity(0.05))

                        ForEach(Array(list.enumerated()), id: \.element.id) { index, server in
                            ServerRow(
                                index: index + 1,
                                server: server,
                                isSelected: selectedID == server.id,
                                isFavorite: favorites.contains(server.id),
                                onSelect: { model.select(serverID: server.id) },
                                onToggleFavorite: { model.toggleFavorite(serverID: server.id) }
                            )
                        }
                    } else {
                        VStack(spacing: 8) {
                            Text("Ничего не найдено").font(.system(size: 16, weight: .semibold))
                            Text("Попробуйте другое название страны или города")
                                .font(.system(size: 11)).foregroundStyle(DS.muted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding(.top, 16)
            }
        }
        .background(DS.paper.ignoresSafeArea())
        .hapticScrollThresholds()
        .hapticSelection(tab)
        .onAppear(perform: captureSnapshot)
        .onChangeCompat(of: model.activeSubscriptionID) { _ in captureSnapshot() }
        .onChangeCompat(of: model.isPingingServers) { pinging in
            // Refresh measured pings into the snapshot when a run finishes.
            if !pinging { captureSnapshot() }
        }
    }

    private func captureSnapshot() {
        let sub = model.activeSubscription
        snapshotServers = sub?.servers ?? []
        snapshotName = sub?.name ?? ""
        snapshotUpdated = sub?.updated ?? ""
    }
}

private struct AutoSelectionRow: View {
    let usesAuto: Bool
    let activeLabel: String
    let activePing: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text("A")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .frame(width: 38, height: 38)
                    .background(DS.ink)
                    .foregroundStyle(DS.acid)
                VStack(alignment: .leading, spacing: 4) {
                    Text("БАЛАНСИРОВЩИК / РЕКОМЕНДУЕТСЯ").microLabel(color: DS.green)
                    Text("Автовыбор").font(.system(size: 16, weight: .semibold))
                    Text("По задержке, доступности и нагрузке").font(.system(size: 10)).foregroundStyle(DS.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("СЕЙЧАС").microLabel()
                    Text(activeLabel).font(.system(size: 12, weight: .semibold))
                    Text(activePing).microLabel()
                }
                Image(systemName: usesAuto ? "checkmark" : "arrow.right")
                    .foregroundStyle(DS.green)
            }
            .padding(.horizontal, 20)
            .frame(height: 92)
            .background(usesAuto ? DS.acid.opacity(0.11) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .overlay(alignment: .bottom) { Hairline() }
    }
}

private struct ServerRow: View {
    let index: Int
    let server: VPNServer
    let isSelected: Bool
    let isFavorite: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 11) {
                Text(String(format: "%02d", index)).microLabel()
                FlagImage(code: server.countryCode, width: 30, height: 20)
                Text(server.locationLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.green)
                }
                .buttonStyle(HapticButtonStyle())
                VStack(alignment: .trailing, spacing: 4) {
                    Text(server.pingLabel).microLabel(color: server.ping > 100 ? .orange : DS.ink)
                    Text("ЗАГРУЗКА \(server.load)%").microLabel()
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            DS.ink.opacity(0.12)
                            (server.ping > 100 ? Color.orange : DS.green)
                                .frame(width: geometry.size.width * CGFloat(max(server.load, 1)) / 100)
                        }
                    }
                    .frame(width: 64, height: 2)
                }
                Image(systemName: isSelected ? "checkmark" : "arrow.right")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? DS.green : DS.ink)
            }
            .padding(.horizontal, 20)
            .frame(height: 66)
            .background(isSelected ? DS.acid.opacity(0.1) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .overlay(alignment: .bottom) { Hairline() }
    }
}

#endif
