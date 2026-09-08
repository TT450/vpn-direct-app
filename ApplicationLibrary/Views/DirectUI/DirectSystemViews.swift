import Library
import SwiftUI
import UIKit

#if os(iOS)

struct SystemBackButton: View {
    @ObservedObject var model: VPNConnectionModel
    let title: String
    let destination: DetailPage?

    var body: some View {
        Button {
            model.detailPage = destination
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left")
                Text(title)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(DS.muted)
        }
        .buttonStyle(HapticButtonStyle())
    }
}

struct SystemSectionHeader: View {
    let number: String
    let title: String
    let meta: String

    var body: some View {
        HStack(spacing: 11) {
            Text(number).microLabel(color: DS.green)
            Text(title).microLabel(color: DS.ink)
            Spacer()
            Text(meta).microLabel()
        }
        .frame(height: 40)
        .overlay(alignment: .top) { Hairline(color: DS.ink) }
    }
}

struct SystemRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var accent = false
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accent ? DS.green : DS.ink)
                    .frame(width: 25)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(DS.muted)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent ? DS.green : DS.muted)
            }
            .frame(minHeight: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .overlay(alignment: .bottom) { Hairline() }
    }
}

struct DirectSystemSettingsWarningView: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                SystemBackButton(model: model, title: "Профиль", destination: nil)
                PageHeading(
                    kicker: "ЗАЩИЩЁННЫЙ РАЗДЕЛ",
                    title: "Системные настройки",
                    subtitle: "Параметры сетевого ядра и маршрутизации"
                )
                .padding(.top, 17)

                VStack(spacing: 0) {
                    HStack(spacing: 15) {
                        Text("!")
                            .font(.system(size: 31, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DS.acid)
                            .frame(width: 64, height: 64)
                            .overlay(Rectangle().stroke(DS.acid.opacity(0.48)))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("ТРЕБУЕТ ВНИМАНИЯ").microLabel(color: DS.acid)
                            Text("Здесь легко нарушить работу VPN")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Эти параметры предназначены для диагностики и ручной настройки подключения.")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.56))
                                .lineSpacing(3)
                        }
                    }
                    .padding(17)

                    Text("Если VPN подключается и работает стабильно — ничего менять не нужно.")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(DS.acid)

                    VStack(spacing: 0) {
                        SystemRiskRow(
                            number: "01",
                            title: "Туннель и маршруты",
                            subtitle: "Неверное значение может отключить интернет или локальные устройства."
                        )
                        SystemRiskRow(
                            number: "02",
                            title: "Данные ядра",
                            subtitle: "После очистки приложению потребуется заново подготовить рабочие файлы."
                        )
                        SystemRiskRow(
                            number: "03",
                            title: "Запуск по требованию",
                            subtitle: "Меняет то, когда VPN включается и отключается автоматически."
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 5)
                }
                .background(DS.panel)
                .padding(.top, 24)

                Button {
                    model.detailPage = nil
                } label: {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Оставить как есть")
                        Spacer()
                        Text("РЕКОМЕНДУЕТСЯ").microLabel(color: DS.acid)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.acid)
                    .padding(.horizontal, 15)
                    .frame(height: 52)
                    .background(DS.ink)
                }
                .buttonStyle(HapticButtonStyle())
                .padding(.top, 14)

                Button {
                    model.openDetail(.systemSettings)
                } label: {
                    Text("Я понимаю — открыть системные настройки")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.muted)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .overlay(Rectangle().stroke(DS.line))
                }
                .buttonStyle(HapticButtonStyle())
                .padding(.top, 8)

                Text("Все параметры можно вернуть к значениям по умолчанию внутри соответствующего раздела.")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.muted)
                    .lineSpacing(3)
                    .padding(.top, 15)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .onAppear { HapticManager.shared.play(.warning) }
    }
}

private struct SystemRiskRow: View {
    let number: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Text(number).microLabel(color: DS.acid)
                .frame(width: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Hairline(color: .white.opacity(0.1)) }
    }
}

struct DirectSystemSettingsView: View {
    @ObservedObject var model: VPNConnectionModel
    @EnvironmentObject private var environments: ExtensionEnvironments
    @State private var specialFlags = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                SystemBackButton(model: model, title: "Профиль", destination: nil)
                PageHeading(
                    kicker: "СИСТЕМА / 05",
                    title: "Настройки",
                    subtitle: "Управление приложением и ядром"
                )
                .padding(.top, 17)

                HStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DIRECT CORE").microLabel(color: .white.opacity(0.42))
                        Text(model.isProtected ? "Система работает штатно" : "VPN отключён")
                            .font(.system(size: 19, weight: .semibold))
                        Text("sing-box · Packet Tunnel · iOS")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 7) {
                        Circle().fill(model.isProtected ? DS.acid : Color.orange).frame(width: 9, height: 9)
                        Text(model.isProtected ? "АКТИВНО" : "ОЖИДАНИЕ").microLabel(color: model.isProtected ? DS.acid : .orange)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 118)
                .background(DS.panel)
                .foregroundStyle(.white)
                .padding(.top, 24)

                SystemSectionHeader(number: "01", title: "ПОДКЛЮЧЕНИЕ", meta: "5 ПУНКТОВ")
                    .padding(.top, 22)
                SystemRow(icon: "app.badge", title: "Приложение", subtitle: "Поведение клиента и запуск") {
                    model.openDetail(.applicationSettings)
                }
                SystemRow(icon: "shippingbox", title: "Ядро", subtitle: "sing-box и параметры процесса") {
                    model.openDetail(.coreSettings)
                }
                SystemRow(icon: "network", title: "Туннель", subtitle: "Маршрутизация и интерфейс") {
                    model.openDetail(.tunnelSettings)
                }
                SystemRow(icon: "bolt.horizontal", title: "Запуск по требованию", subtitle: "Правила автоматического запуска") {
                    model.openDetail(.onDemandSettings)
                }
                SystemRow(icon: "arrow.clockwise", title: "Перезагрузка конфигурации", subtitle: "Применить актуальные параметры", accent: true) {
                    environments.postReload()
                    Task { await model.reloadSubscriptions() }
                }

                SystemSectionHeader(number: "02", title: "О ПРИЛОЖЕНИИ", meta: "OPEN SOURCE")
                    .padding(.top, 23)
                SystemRow(icon: "info.circle", title: "О приложении", subtitle: "Версия, лицензия и проект") {
                    model.openDetail(.about)
                }

                SystemSectionHeader(number: "03", title: "ОТЛАДКА", meta: "ДЛЯ ДИАГНОСТИКИ")
                    .padding(.top, 23)
                SystemRow(icon: "doc.text", title: "Журнал службы", subtitle: "События ядра и туннеля") {
                    model.openDetail(.serviceLog)
                }
                HStack(spacing: 13) {
                    Image(systemName: "fingerprint")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 25)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Специальные флаги").font(.system(size: 14, weight: .semibold))
                        Text("Расширенные параметры ядра").font(.system(size: 10)).foregroundStyle(DS.muted)
                    }
                    Spacer()
                    Toggle("", isOn: $specialFlags)
                        .labelsHidden()
                        .tint(DS.green)
                        .hapticToggle(specialFlags)
                        .onChangeCompat(of: specialFlags) { enabled in
                            Task { await SharedPreferences.ignoreMemoryLimit.set(enabled) }
                        }
                }
                .frame(minHeight: 64)
                .overlay(alignment: .bottom) { Hairline() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .task {
            specialFlags = await SharedPreferences.ignoreMemoryLimit.get()
        }
    }
}

private struct AboutFact: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).microLabel()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(.horizontal, 13)
        .overlay(alignment: .leading) { Rectangle().fill(DS.line).frame(width: 1) }
        .overlay(alignment: .bottom) { Hairline() }
    }
}

struct DirectAboutAppView: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                SystemBackButton(model: model, title: "Настройки", destination: .systemSettings)
                PageHeading(kicker: "ПРОЕКТ / OPEN SOURCE", title: "О приложении", subtitle: "VPN Direct для iPhone")
                    .padding(.top, 17)

                HStack(spacing: 17) {
                    Text("A")
                        .font(.system(size: 41, weight: .medium, design: .monospaced))
                        .foregroundStyle(DS.acid)
                        .frame(width: 80, height: 80)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.24)))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VPN DIRECT").microLabel(color: .white.opacity(0.42))
                        Text("Быстрый VPN")
                            .font(.system(size: 23, weight: .semibold))
                        Text("для приватного подключения")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(17)
                .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
                .background(DS.panel)
                .foregroundStyle(.white)
                .padding(.top, 24)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)], spacing: 0) {
                    AboutFact(label: "ВЕРСИЯ", value: "\(Bundle.main.version) / \(Bundle.main.versionNumber)")
                    AboutFact(label: "ЯДРО", value: "sing-box")
                    AboutFact(label: "ПЛАТФОРМА", value: "iOS 15+")
                    AboutFact(label: "ЛИЦЕНЗИЯ", value: "GPLv3")
                }

                SystemSectionHeader(number: "01", title: "ОТКРЫТЫЙ КОД", meta: "GPLv3")
                    .padding(.top, 25)
                Text("Клиент основан на открытом проекте sing-box for Apple. Сетевое ядро и исходный код доступны для аудита сообществом.")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.muted)
                    .lineSpacing(4)
                    .padding(.vertical, 16)

                SystemSectionHeader(number: "02", title: "ССЫЛКИ", meta: "1 РЕСУРС")
                SystemRow(icon: "star.bubble", title: "Оценить в App Store", subtitle: "Поддержать развитие проекта", accent: true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }
}

private struct DirectLogLine: Identifiable, Equatable {
    let id: String
    let level: String
    let message: String
    let accent: Bool
}

struct DirectServiceLogView: View {
    @ObservedObject var model: VPNConnectionModel
    @EnvironmentObject private var environments: ExtensionEnvironments

    @State private var lines: [DirectLogLine] = []
    @State private var isPaused = false
    @State private var isLive = false
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var selectedLevel: Int?
    @State private var copied = false
    @State private var sourceLabel = "OFFLINE"

    private var visibleLines: [DirectLogLine] {
        lines.filter { line in
            if let selectedLevel {
                let mapped = logLevelValue(line.level)
                if mapped > selectedLevel { return false }
            }
            if searchText.isEmpty { return true }
            return line.message.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    SystemBackButton(model: model, title: "Настройки", destination: .systemSettings)
                    PageHeading(kicker: "ОТЛАДКА / LIVE", title: "Журнал", subtitle: "События ядра и сетевого туннеля")
                        .padding(.top, 17)

                    HStack(spacing: 0) {
                        Label(isLive ? "LIVE" : "OFFLINE", systemImage: "circle.fill")
                            .microLabel(color: isLive && !isPaused ? DS.green : DS.muted)
                        Spacer()
                        Button { isSearching.toggle() } label: {
                            Image(systemName: "magnifyingglass").frame(width: 44, height: 44)
                        }
                        Button {
                            isPaused.toggle()
                            HapticManager.shared.play(isPaused ? .toggleOff : .toggleOn)
                        } label: {
                            Image(systemName: isPaused ? "play" : "pause").frame(width: 44, height: 44)
                        }
                        Menu {
                            Button("Все уровни") { selectedLevel = nil }
                            ForEach(LogLevel.allCases) { level in
                                Button(level.name) { selectedLevel = level.rawValue }
                            }
                            Divider()
                            Button("Очистить", role: .destructive) {
                                lines = []
                                environments.commandClient.clearLogs()
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease").frame(width: 44, height: 44)
                        }
                    }
                    .buttonStyle(HapticButtonStyle())
                    .frame(height: 54)
                    .overlay(alignment: .bottom) { Hairline() }
                    .padding(.top, 19)

                    if isSearching {
                        TextField("Поиск в журнале", text: $searchText)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(.horizontal, 13)
                            .frame(height: 44)
                            .background(Color.white.opacity(0.35))
                            .overlay(Rectangle().stroke(DS.line))
                            .padding(.top, 10)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("PACKET–TUNNEL / SERVICE.LOG").microLabel(color: .white.opacity(0.42))
                            Spacer()
                            Text(isPaused ? "PAUSED" : sourceLabel)
                                .microLabel(color: isPaused ? .orange : (isLive ? DS.acid : DS.muted))
                        }
                        .padding(.bottom, 16)

                        if visibleLines.isEmpty {
                            Text(emptyHint)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.vertical, 12)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(visibleLines) { line in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(line.level)
                                            .foregroundStyle(line.accent ? Color.orange : .white.opacity(0.62))
                                            .frame(width: 45, alignment: .leading)
                                        Text(line.message)
                                            .foregroundStyle(.white.opacity(0.87))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .font(.system(size: 10, design: .monospaced))
                                    .padding(.vertical, 8)
                                    .overlay(alignment: .bottom) { Hairline(color: .white.opacity(0.09)) }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.panel)
                    .padding(.top, 18)

                    HStack(spacing: 8) {
                        Button {
                            UIPasteboard.general.string = visibleLines.map { "\($0.level) \($0.message)" }.joined(separator: "\n")
                            HapticManager.shared.play(.copied)
                            copied = true
                            Task {
                                try? await Task.sleep(nanoseconds: 1_200_000_000)
                                copied = false
                            }
                        } label: {
                            Label(copied ? "Скопировано" : "Копировать", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 45)
                                .foregroundStyle(DS.acid)
                                .background(DS.ink)
                        }
                        Button {
                            let text = visibleLines.map { "\($0.level) \($0.message)" }.joined(separator: "\n")
                            HapticManager.shared.play(.shared)
                            if let url = try? text.generateShareFile(name: "service.log") {
                                DirectSharePresenter.share([url])
                            }
                        } label: {
                            Label("Поделиться", systemImage: "square.and.arrow.up")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 45)
                                .overlay(Rectangle().stroke(DS.ink))
                        }
                    }
                    .buttonStyle(HapticButtonStyle())
                    .padding(.top, 10)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock").foregroundStyle(DS.green)
                        Text("Перед отправкой журнал автоматически скрывает адреса подписок, токены и другие приватные значения.")
                            .font(.system(size: 10)).foregroundStyle(DS.muted).lineSpacing(3)
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
        }
        .task {
            environments.connect()
            await captureSnapshot(force: true)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                if !isPaused {
                    await captureSnapshot(force: false)
                }
            }
        }
    }

    private var emptyHint: String {
        if model.isConnected {
            return isLive ? "Ждём события…" : "Подключаемся к журналу…"
        }
        return "Журнал доступен при активном VPN."
    }

    private func captureSnapshot(force: Bool) async {
        environments.connect()
        let client = environments.commandClient
        let connected = client.isConnected
        isLive = connected
        sourceLabel = connected ? "STREAMING" : (model.isConnected ? "CONNECTING" : "OFFLINE")

        let raw: [String]
        if connected, !client.logList.isEmpty {
            raw = client.logList.suffix(60).map(\.message)
        } else if force || lines.isEmpty {
            raw = await loadFileLines()
            if !raw.isEmpty { sourceLabel = "FILE" }
        } else {
            return // keep frozen content — no flicker to empty
        }

        guard !raw.isEmpty || force else { return }
        let mapped = raw.enumerated().map { index, message -> DirectLogLine in
            let clean = strippedANSI(message)
            let level = inferredLevel(clean)
            return DirectLogLine(
                id: "\(index)-\(clean.hashValue)",
                level: level,
                message: clean,
                accent: level == "ERROR" || level == "WARN"
            )
        }
        // Only replace when content actually changed.
        if mapped.map(\.message) != lines.map(\.message) {
            lines = mapped
        }
    }

    private func loadFileLines() async -> [String] {
        let primary = FilePath.cacheDirectory.appendingPathComponent("stderr.log")
        let secondary = FilePath.cacheDirectory.appendingPathComponent("stderr.log.old")
        let text = await BlockingIO.run {
            if let content = try? String(contentsOf: primary), !content.isEmpty { return content }
            return (try? String(contentsOf: secondary)) ?? ""
        }
        return text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .suffix(60)
            .map(String.init)
    }

    private func inferredLevel(_ message: String) -> String {
        let upper = message.uppercased()
        if upper.contains("ERROR") { return "ERROR" }
        if upper.contains("WARN") { return "WARN" }
        if upper.contains("DEBUG") { return "DEBUG" }
        if upper.contains("READY") { return "READY" }
        return "INFO"
    }

    private func logLevelValue(_ name: String) -> Int {
        switch name {
        case "ERROR": return LogLevel.error.rawValue
        case "WARN": return LogLevel.warn.rawValue
        case "DEBUG": return LogLevel.debug.rawValue
        default: return LogLevel.info.rawValue
        }
    }

    private func strippedANSI(_ message: String) -> String {
        message.replacingOccurrences(of: #"\u001B\[[0-9;]*m"#, with: "", options: .regularExpression)
    }
}

struct ConfigField<Content: View>: View {
    let number: String
    let title: String
    let content: Content

    init(number: String, title: String, @ViewBuilder content: () -> Content) {
        self.number = number
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Text(number).microLabel(color: DS.green)
                Text(title).microLabel(color: DS.ink)
            }
            content
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

struct DirectNewConfigurationView: View {
    @ObservedObject var model: VPNConnectionModel
    @EnvironmentObject private var environments: ExtensionEnvironments
    @StateObject private var viewModel = NewProfileViewModel()
    @State private var typeLabel = "Удалённый"
    @State private var storageLabel = "Новый"
    @State private var resultMessage: String?
    @State private var resultOK = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                SystemBackButton(model: model, title: "Подписки", destination: nil)
                PageHeading(kicker: "ИМПОРТ / РУЧНОЙ ВВОД", title: "Новая конфигурация", subtitle: "Добавьте ссылку или URL подписки")
                    .padding(.top, 17)

                HStack {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("ПОДДЕРЖИВАЕМЫЕ ФОРМАТЫ").microLabel(color: .white.opacity(0.42))
                        Text("vless · vmess · trojan · ss · hy2 · https://")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                    Spacer()
                    Image(systemName: "link").foregroundStyle(DS.acid)
                }
                .padding(16)
                .frame(minHeight: 88)
                .background(DS.panel)
                .foregroundStyle(.white)
                .padding(.top, 24)

                ConfigField(number: "01", title: "ССЫЛКА") {
                    TextField("vless://… или https://…/sub/…", text: $viewModel.remotePath)
                        .font(.system(size: 13, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .padding(.horizontal, 13)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.35))
                        .overlay(Rectangle().stroke(DS.line))
                        .onChangeCompat(of: viewModel.remotePath) { _ in
                            syncTypeFromLink()
                        }
                }

                ConfigField(number: "02", title: "ИМЯ") {
                    TextField("Например, VPN Direct Premium", text: $viewModel.profileName)
                        .font(.system(size: 13))
                        .padding(.horizontal, 13)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.35))
                        .overlay(Rectangle().stroke(DS.line))
                }

                ConfigField(number: "03", title: "ТИП") {
                    Picker("Тип", selection: $typeLabel) {
                        Text("Локальный").tag("Локальный")
                        Text("Удалённый").tag("Удалённый")
                    }
                    .pickerStyle(.segmented)
                    .onChangeCompat(of: typeLabel) { label in
                        viewModel.profileType = label == "Локальный" ? .local : .remote
                    }
                }

                ConfigField(number: "04", title: "ХРАНИЛИЩЕ") {
                    Picker("Файл", selection: $storageLabel) {
                        Text("Новый").tag("Новый")
                        Text("Основной").tag("Основной")
                    }
                    .pickerStyle(.segmented)
                    .onChangeCompat(of: storageLabel) { label in
                        viewModel.fileImport = label == "Основной"
                    }
                }

                if let resultMessage {
                    Label(resultMessage, systemImage: resultOK ? "checkmark.circle" : "exclamationmark.triangle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(resultOK ? DS.green : Color.orange)
                        .padding(.top, 14)
                }

                Button {
                    createConfiguration()
                } label: {
                    HStack {
                        if viewModel.isSaving {
                            ProgressView().tint(DS.acid)
                        } else {
                            Image(systemName: "doc.badge.plus")
                        }
                        Text(viewModel.isSaving ? "Создание…" : "Создать конфигурацию")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 15)
                    .frame(height: 52)
                    .foregroundStyle(DS.acid)
                    .background(DS.ink)
                }
                .buttonStyle(HapticButtonStyle())
                .disabled(viewModel.isSaving)
                .padding(.top, 18)

                Text("Ссылка хранится только на устройстве. Перед импортом приложение проверит формат и структуру конфигурации.")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.muted)
                    .lineSpacing(3)
                    .padding(.top, 15)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .onAppear {
            syncTypeFromLink()
        }
        .alert($viewModel.alert)
    }

    private func syncTypeFromLink() {
        let link = viewModel.remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if VLESSConfigBuilder.isVLESSLink(link)
            || SubscriptionConfigBuilder.isShareLinkContent(link)
            || SubscriptionConfigBuilder.isHTTPURL(link)
        {
            typeLabel = "Удалённый"
            viewModel.profileType = .remote
        }
    }

    private func createConfiguration() {
        let link = viewModel.remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty else {
            resultOK = false
            resultMessage = "Введите ссылку конфигурации"
            HapticManager.shared.play(.error)
            return
        }

        if !VLESSConfigBuilder.isVLESSLink(link),
           !SubscriptionConfigBuilder.isShareLinkContent(link),
           !SubscriptionConfigBuilder.isHTTPURL(link),
           viewModel.profileType == .remote
        {
            resultOK = false
            resultMessage = "Нужна ссылка vless://, vmess://, trojan:// или https:// подписки"
            HapticManager.shared.play(.error)
            return
        }

        viewModel.isSaving = true
        Task {
            await viewModel.createProfile(
                environments: environments,
                dismiss: nil,
                onSuccess: { profile in
                    await SharedPreferences.selectedProfileID.set(profile.mustID)
                    environments.profileUpdate.send()
                    await model.reloadSubscriptions()
                    if model.importFromAccessChoice {
                        model.handleImportedProfileActivated(subscriptionID: profile.mustID)
                    } else {
                        model.activateNewlyImportedSubscription(profile.mustID)
                        resultOK = true
                        resultMessage = "Конфигурация создана и активирована"
                        HapticManager.shared.play(.imported)
                    }
                }
            )
            if !viewModel.createSucceeded, viewModel.alert == nil {
                // alert may already be set by viewModel
            }
            if viewModel.alert != nil {
                resultOK = false
                resultMessage = "Не удалось создать конфигурацию"
                HapticManager.shared.play(.error)
            }
        }
    }
}

#endif
