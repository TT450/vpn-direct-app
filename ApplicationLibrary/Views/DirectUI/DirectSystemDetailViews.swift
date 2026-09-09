import Libbox
import Library
import SwiftUI
import UIKit

#if os(iOS)

private struct SettingValueRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing

    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold))
                if let subtitle {
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(DS.muted)
                }
            }
            Spacer(minLength: 14)
            trailing
        }
        .frame(minHeight: subtitle == nil ? 54 : 66)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

private struct TechnicalToggle: View {
    let number: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    var onChange: ((Bool) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(number).microLabel(color: DS.green)
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(DS.green)
                    .hapticToggle(isOn)
                    .onChangeCompat(of: isOn) { value in
                        onChange?(value)
                    }
            }
            .frame(minHeight: 58)
            .overlay(alignment: .bottom) { Hairline() }

            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(DS.muted)
                .lineSpacing(3)
                .padding(.vertical, 11)

            Button {
                if let url = URL(string: "https://developer.apple.com/documentation/networkextension/nepackettunnelprovider") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Документация Apple").microLabel(color: DS.green)
                    Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .bold)).foregroundStyle(DS.green)
                }
            }
            .buttonStyle(HapticButtonStyle())
            .padding(.bottom, 14)
        }
    }
}

struct DirectApplicationSettingsView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var language = "Русский"
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                PageHeading(kicker: "СИСТЕМА / ПРИЛОЖЕНИЕ", title: "Приложение", subtitle: "Язык и поведение интерфейса")
                    .padding(.top, DS.pageTop)

                HStack {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("ЯЗЫК ИНТЕРФЕЙСА").microLabel(color: .white.opacity(0.42))
                        Text(language).font(.system(size: 22, weight: .semibold))
                    }
                    Spacer()
                    Text(language == "Русский" ? "RU" : "EN")
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundStyle(DS.acid)
                        .frame(width: 52, height: 52)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.22)))
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 104)
                .background(DS.panel)
                .foregroundStyle(.white)
                .padding(.top, 24)

                SystemSectionHeader(number: "01", title: "ЯЗЫК", meta: "2 ВАРИАНТА")
                    .padding(.top, 23)
                SettingValueRow(title: "Язык приложения", subtitle: "Полностью применится после перезапуска") {
                    Picker("Язык", selection: $language) {
                        Text("Русский").tag("Русский")
                        Text("English").tag("English")
                    }
                    .labelsHidden()
                    .tint(DS.green)
                    .hapticSelection(language)
                    .onChangeCompat(of: language) { value in
                        applyLanguage(value)
                    }
                }

                SettingValueRow(title: "Тактильная отдача", subtitle: "Сигнатуры действий, VPN и уведомлений") {
                    Toggle("", isOn: Binding(
                        get: { hapticsEnabled },
                        set: { newValue in
                            HapticManager.shared.setEnabled(newValue)
                            hapticsEnabled = newValue
                        }
                    ))
                        .labelsHidden()
                        .tint(DS.green)
                }

                Text("Системные названия протоколов и параметры ядра остаются без перевода, чтобы их можно было точно сопоставить с документацией.")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.muted)
                    .lineSpacing(3)
                    .padding(.top, 16)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .onAppear { language = currentLanguageLabel() }
    }

    private func currentLanguageLabel() -> String {
        guard let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
              let first = languages.first
        else { return "Русский" }
        return first.hasPrefix("en") ? "English" : "Русский"
    }

    private func applyLanguage(_ label: String) {
        if label == "English" {
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set(["ru"], forKey: "AppleLanguages")
        }
    }
}

struct DirectCoreSettingsView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var version = "—"
    @State private var dataSize = "…"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                PageHeading(kicker: "СИСТЕМА / CORE", title: "Ядро", subtitle: "Версия sing-box и размер данных")
                    .padding(.top, DS.pageTop)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("SING–BOX ENGINE").microLabel(color: .white.opacity(0.42))
                        Text(version).font(.system(size: 28, weight: .semibold, design: .monospaced))
                        Text("Актуальная версия ядра").font(.system(size: 10)).foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer()
                    Circle().fill(DS.acid).frame(width: 10, height: 10)
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
                .background(DS.panel)
                .foregroundStyle(.white)
                .padding(.top, 24)

                SystemSectionHeader(number: "01", title: "СВЕДЕНИЯ", meta: "ENGINE")
                    .padding(.top, 23)
                SettingValueRow(title: "Версия") {
                    Text(version).font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(DS.green)
                }
                SettingValueRow(title: "Размер данных") {
                    Text(dataSize).font(.system(size: 13, weight: .semibold, design: .monospaced))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .task {
            version = LibboxVersion()
            await refreshSize()
        }
    }

    private func refreshSize() async {
        let workingDirectory = FilePath.workingDirectory
        let size = await BlockingIO.run {
            Self.directorySizeString(at: workingDirectory)
        }
        dataSize = size
    }

    private nonisolated static func directorySizeString(at url: URL) -> String {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey]
        ) else { return "—" }
        var size = 0
        while let item = enumerator.nextObject() as? URL {
            size += (try? item.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(for: size) ?? "—"
    }
}

struct DirectTunnelSettingsView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var ignoreMemoryLimit = false
    @State private var excludeAPNs = true
    @State private var excludeCellularServices = true
    @State private var excludeLocalNetworks = true
    @State private var enforceRoutes = false
    @State private var excludeDeviceCommunication = true
    @State private var resetComplete = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                PageHeading(kicker: "СИСТЕМА / PACKET TUNNEL", title: "Туннель", subtitle: "Маршруты и системные исключения")
                    .padding(.top, DS.pageTop)

                HStack {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("PACKET TUNNEL").microLabel(color: .white.opacity(0.42))
                        Text("Системный маршрут").font(.system(size: 20, weight: .semibold))
                        Text("5 расширенных параметров").font(.system(size: 10)).foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer()
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 23)).foregroundStyle(DS.acid)
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 112)
                .background(DS.panel)
                .foregroundStyle(.white)
                .padding(.top, 24)

                SystemSectionHeader(number: "01", title: "ПАМЯТЬ", meta: "ОСТОРОЖНО")
                    .padding(.top, 23)
                SettingValueRow(title: "Игнорировать ограничение памяти", subtitle: "Может привести к аварийному завершению ядра") {
                    Toggle("", isOn: $ignoreMemoryLimit)
                        .labelsHidden()
                        .tint(DS.green)
                        .hapticToggle(ignoreMemoryLimit)
                        .onChangeCompat(of: ignoreMemoryLimit) { value in
                            Task { await SharedPreferences.ignoreMemoryLimit.set(value) }
                        }
                }

                SystemSectionHeader(number: "02", title: "СИСТЕМНЫЕ ИСКЛЮЧЕНИЯ", meta: "ADVANCED")
                    .padding(.top, 23)
                TechnicalToggle(number: "01", title: "excludeAPNs", description: "Исключает трафик Apple Push Notification Services, когда включён includeAllNetworks.", isOn: $excludeAPNs) { value in
                    Task { await SharedPreferences.excludeAPNs.set(value) }
                }
                TechnicalToggle(number: "02", title: "excludeCellularServices", description: "Исключает Wi‑Fi Calling, MMS, SMS и Visual Voicemail из VPN-маршрута.", isOn: $excludeCellularServices) { value in
                    Task { await SharedPreferences.excludeCellularServices.set(value) }
                }
                TechnicalToggle(number: "03", title: "excludeLocalNetworks", description: "Оставляет AirPlay, AirDrop, CarPlay и другие локальные подключения вне туннеля.", isOn: $excludeLocalNetworks) { value in
                    model.setLocalNetwork(value)
                }
                TechnicalToggle(number: "04", title: "enforceRoutes", description: "Принудительно направляет заданные маршруты через VPN и меняет системную область маршрутизации.", isOn: $enforceRoutes) { value in
                    model.setSecureDNS(value)
                }
                TechnicalToggle(number: "05", title: "excludeDeviceCommunication", description: "Исключает внутреннюю связь устройства. Для свойства нет отдельного описания Apple.", isOn: $excludeDeviceCommunication) { value in
                    Task { await SharedPreferences.excludeDeviceCommunication.set(value) }
                }

                Button {
                    ignoreMemoryLimit = false
                    excludeAPNs = true
                    excludeCellularServices = true
                    excludeLocalNetworks = true
                    enforceRoutes = false
                    excludeDeviceCommunication = true
                    resetComplete = true
                    HapticManager.shared.play(.deleted)
                    Task {
                        await SharedPreferences.ignoreMemoryLimit.set(false)
                        await SharedPreferences.excludeAPNs.set(true)
                        await SharedPreferences.excludeCellularServices.set(true)
                        await SharedPreferences.excludeDeviceCommunication.set(true)
                        model.setLocalNetwork(true)
                        model.setSecureDNS(false)
                    }
                } label: {
                    HStack {
                        Image(systemName: resetComplete ? "checkmark" : "eraser")
                        Text(resetComplete ? "Настройки сброшены" : "Сбросить настройки туннеля")
                        Spacer()
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 15)
                    .frame(height: 50)
                    .foregroundStyle(.red)
                    .overlay(Rectangle().stroke(Color.red.opacity(0.65)))
                }
                .buttonStyle(HapticButtonStyle())
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .task {
            ignoreMemoryLimit = await SharedPreferences.ignoreMemoryLimit.get()
            excludeAPNs = await SharedPreferences.excludeAPNs.get()
            excludeCellularServices = await SharedPreferences.excludeCellularServices.get()
            excludeLocalNetworks = await SharedPreferences.excludeLocalNetworks.get()
            enforceRoutes = await SharedPreferences.enforceRoutes.get()
            excludeDeviceCommunication = await SharedPreferences.excludeDeviceCommunication.get()
        }
    }
}

struct DirectOnDemandSettingsView: View {
    @ObservedObject var model: VPNConnectionModel
    @EnvironmentObject private var environments: ExtensionEnvironments
    @State private var mode = "Отключено"
    @State private var savedMode = "Отключено"

    private var explanation: String {
        switch mode {
        case "Всегда": "VPN будет автоматически подключаться при появлении любой сети."
        case "Неизвестный Wi‑Fi": "VPN включится в незнакомых Wi‑Fi сетях и останется выключенным в доверенных."
        case "Мобильная сеть": "VPN будет автоматически подключаться при переходе на мобильный интернет."
        default: "VPN не будет подключаться автоматически."
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                PageHeading(kicker: "АВТОМАТИКА / ON DEMAND", title: "Запуск по требованию", subtitle: "Когда VPN должен включаться сам")
                    .padding(.top, DS.pageTop)

                VStack(alignment: .leading, spacing: 8) {
                    Text("ТЕКУЩЕЕ ПРАВИЛО").microLabel(color: .white.opacity(0.42))
                    Text(mode).font(.system(size: 22, weight: .semibold))
                    Text(explanation).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5)).lineSpacing(3)
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                .background(DS.panel)
                .foregroundStyle(.white)
                .padding(.top, 24)

                SystemSectionHeader(number: "01", title: "РЕЖИМ", meta: "VPN ON DEMAND")
                    .padding(.top, 23)
                VStack(spacing: 0) {
                    ForEach(["Отключено", "Всегда", "Неизвестный Wi‑Fi", "Мобильная сеть"], id: \.self) { option in
                        Button {
                            mode = option
                        } label: {
                            HStack {
                                Text(option).font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Image(systemName: mode == option ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(mode == option ? DS.green : DS.muted)
                            }
                            .frame(height: 54)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(HapticButtonStyle())
                        .overlay(alignment: .bottom) { Hairline() }
                    }
                }

                Text(explanation)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.muted)
                    .lineSpacing(3)
                    .padding(.top, 15)

                Button {
                    Task {
                        await applyMode(mode)
                        savedMode = mode
                    }
                } label: {
                    HStack {
                        Image(systemName: savedMode == mode ? "checkmark" : "bolt")
                        Text(savedMode == mode ? "Правило сохранено" : "Применить правило")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 15)
                    .frame(height: 50)
                    .foregroundStyle(DS.acid)
                    .background(DS.ink)
                }
                .buttonStyle(HapticButtonStyle())
                .padding(.top, 18)

                Button {
                    mode = "Отключено"
                    savedMode = "Отключено"
                    Task { await applyMode("Отключено") }
                } label: {
                    HStack {
                        Image(systemName: "eraser")
                        Text("Сбросить")
                        Spacer()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(height: 50)
                }
                .buttonStyle(HapticButtonStyle())
                .overlay(alignment: .bottom) { Hairline() }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .task {
            mode = await loadMode()
            savedMode = mode
        }
    }

    private func loadMode() async -> String {
        let alwaysOn = await SharedPreferences.alwaysOn.get()
        let onDemand = await SharedPreferences.onDemandEnabled.get()
        let rules = await SharedPreferences.onDemandRules.get()
        if alwaysOn { return "Всегда" }
        if onDemand {
            if rules.contains(where: { $0.interfaceType == .cellular && $0.action == .connect && rules.count == 1 }) {
                return "Мобильная сеть"
            }
            return "Неизвестный Wi‑Fi"
        }
        return "Отключено"
    }

    private func applyMode(_ mode: String) async {
        switch mode {
        case "Всегда":
            model.setAutoConnect(true)
            model.setUnknownWiFi(false)
            await SharedPreferences.alwaysOn.set(true)
            await SharedPreferences.onDemandEnabled.set(false)
            await SharedPreferences.onDemandRules.set([])
            try? await environments.extensionProfile?.updateOnDemand(enabled: true, useDefaultRules: true)
        case "Неизвестный Wi‑Fi":
            model.setAutoConnect(true)
            model.setUnknownWiFi(true)
            await model.applySecuritySettings()
        case "Мобильная сеть":
            model.setAutoConnect(true)
            await SharedPreferences.alwaysOn.set(false)
            await SharedPreferences.onDemandEnabled.set(true)
            await SharedPreferences.onDemandRules.set([
                OnDemandRule(action: .connect, interfaceType: .cellular),
            ])
            try? await environments.extensionProfile?.updateOnDemand(enabled: true, useDefaultRules: false)
        default:
            model.setAutoConnect(false)
            await SharedPreferences.alwaysOn.set(false)
            await SharedPreferences.onDemandEnabled.set(false)
            await SharedPreferences.onDemandRules.set([])
            try? await environments.extensionProfile?.updateOnDemand(enabled: false, useDefaultRules: false)
        }
    }
}

#endif
