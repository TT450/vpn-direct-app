import SwiftUI

#if os(iOS)

struct DirectServerPickerView: View {
    @ObservedObject var model: VPNConnectionModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var tab = PickerTab.all

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
            source = model.activeSubscription?.servers ?? []
        case .favorites:
            source = model.favoriteServers(for: model.activeSubscription)
        case .history:
            source = model.recentServers(for: model.activeSubscription)
        }
        guard !value.isEmpty else { return source }
        return source.filter {
            $0.city.localizedCaseInsensitiveContains(value)
                || $0.country.localizedCaseInsensitiveContains(value)
                || (model.activeSubscription?.name.localizedCaseInsensitiveContains(value) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ПОДПИСКА / \(model.activeSubscription?.servers.count ?? 0) ЛОКАЦИЙ").microLabel()
                    Text("Выбор локации").font(.system(size: 31, weight: .semibold))
                    Text("\(model.activeSubscription?.name ?? "") · только серверы активной подписки")
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
                                Text(String(format: "%02d", model.favoriteServers(for: model.activeSubscription).count))
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
                    Text(model.isPingingServers ? "ИЗМЕРЕНИЕ" : "ВСЕ СЕРВЕРЫ")
                        .microLabel(color: .white.opacity(0.45))
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(.white)
                .background(DS.ink)
            }
            .buttonStyle(HapticButtonStyle())
            .disabled(model.isPingingServers || (model.activeSubscription?.servers.isEmpty ?? true))
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if query.isEmpty, tab == .all { AutoSelectionRow(model: model) }

                    if !servers.isEmpty {
                        HStack {
                            Text("01 / \((model.activeSubscription?.name ?? "").uppercased())").microLabel()
                            Spacer()
                            Text("\(servers.count) ЛОКАЦИЙ · \((model.activeSubscription?.updated ?? "").uppercased())").microLabel()
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 42)
                        .background(DS.ink.opacity(0.05))

                        ForEach(Array(servers.enumerated()), id: \.element.id) { index, server in
                            ServerRow(model: model, index: index + 1, server: server)
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
    }
}

private struct AutoSelectionRow: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        Button {
            model.select(serverID: nil)
        } label: {
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
                    Text(model.activeServer?.locationLabel ?? "—").font(.system(size: 12, weight: .semibold))
                    Text(model.activeServer?.pingLabel ?? "—").microLabel()
                }
                Image(systemName: model.usesAutoSelection ? "checkmark" : "arrow.right")
                    .foregroundStyle(DS.green)
            }
            .padding(.horizontal, 20)
            .frame(height: 92)
            .background(model.usesAutoSelection ? DS.acid.opacity(0.11) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .overlay(alignment: .bottom) { Hairline() }
    }
}

private struct ServerRow: View {
    @ObservedObject var model: VPNConnectionModel
    let index: Int
    let server: VPNServer
    private var isSelected: Bool { model.selectedServerID == server.id }

    var body: some View {
        Button {
            model.select(serverID: server.id)
        } label: {
            HStack(spacing: 11) {
                Text(String(format: "%02d", index)).microLabel()
                FlagImage(code: server.countryCode, width: 30, height: 20)
                Text(server.locationLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button {
                    model.toggleFavorite(serverID: server.id)
                } label: {
                    Image(systemName: model.favoriteServerIDs.contains(server.id) ? "star.fill" : "star")
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
