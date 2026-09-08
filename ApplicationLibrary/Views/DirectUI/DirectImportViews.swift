import Library
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)

struct DirectImportFileView: View {
    @ObservedObject var model: VPNConnectionModel
    @EnvironmentObject private var environments: ExtensionEnvironments
    @State private var profileName = ""
    @State private var fileURL: URL?
    @State private var fileLabel = "Файл не выбран"
    @State private var pickerPresented = false
    @State private var isSaving = false
    @State private var resultMessage: String?
    @State private var resultOK = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                SystemBackButton(model: model, title: "Подписки", destination: nil)
                PageHeading(
                    kicker: "ИМПОРТ / ФАЙЛ",
                    title: "Импорт файла",
                    subtitle: "JSON, Clash, WireGuard и другие конфиги"
                )
                .padding(.top, 17)

                HStack {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("ПОДДЕРЖИВАЕМЫЕ ФАЙЛЫ").microLabel(color: .white.opacity(0.42))
                        Text("json  ·  conf  ·  yaml  ·  ovpn  ·  txt")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                    Spacer()
                    Image(systemName: "doc.badge.arrow.up").foregroundStyle(DS.acid)
                }
                .padding(16)
                .frame(minHeight: 88)
                .background(DS.panel)
                .foregroundStyle(.white)
                .padding(.top, 24)

                ConfigField(number: "01", title: "ФАЙЛ") {
                    Button {
                        pickerPresented = true
                    } label: {
                        HStack {
                            Text(fileLabel)
                                .font(.system(size: 13))
                                .foregroundStyle(fileURL == nil ? DS.muted : DS.ink)
                                .lineLimit(1)
                            Spacer()
                            Text("ВЫБРАТЬ").microLabel(color: DS.green)
                        }
                        .padding(.horizontal, 13)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.35))
                        .overlay(Rectangle().stroke(DS.line))
                    }
                    .buttonStyle(HapticButtonStyle())
                }

                ConfigField(number: "02", title: "ИМЯ") {
                    TextField("Например, Home Lab", text: $profileName)
                        .font(.system(size: 13))
                        .padding(.horizontal, 13)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.35))
                        .overlay(Rectangle().stroke(DS.line))
                }

                if let resultMessage {
                    Label(resultMessage, systemImage: resultOK ? "checkmark.circle" : "exclamationmark.triangle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(resultOK ? DS.green : Color.orange)
                        .padding(.top, 14)
                }

                Button {
                    importFile()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView().tint(DS.acid)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(isSaving ? "Импорт…" : "Импортировать файл")
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
                .disabled(isSaving)
                .padding(.top, 18)

                Text("Файл читается на устройстве и нормализуется в рабочий конфиг sing-box. Пустые заглушки не создаются.")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.muted)
                    .lineSpacing(3)
                    .padding(.top, 15)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .fileImporter(
            isPresented: $pickerPresented,
            allowedContentTypes: VPNDirectImportContentTypes.localConfig,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                fileURL = url
                fileLabel = url.lastPathComponent
                if profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    profileName = url.deletingPathExtension().lastPathComponent
                }
            case let .failure(error):
                resultOK = false
                resultMessage = error.localizedDescription
            }
        }
    }

    private func importFile() {
        guard let fileURL else {
            resultOK = false
            resultMessage = "Выберите файл конфигурации"
            HapticManager.shared.play(.error)
            return
        }

        isSaving = true
        resultMessage = nil
        Task {
            defer { isSaving = false }
            do {
                let content: String = try await BlockingIO.run {
                    try fileURL.withRequiredSecurityScopedAccess(
                        or: NSError(
                            domain: "DirectImportFileView",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: String(localized: "Нет доступа к выбранному файлу")]
                        )
                    ) {
                        try String(contentsOf: fileURL, encoding: .utf8)
                    }
                }
                let profile = try await DirectLocalProfileImporter.importContent(content, preferredName: profileName)
                await SharedPreferences.selectedProfileID.set(profile.mustID)
                environments.profileUpdate.send()
                await model.reloadSubscriptions()
                if model.importFromAccessChoice {
                    model.handleImportedProfileActivated(subscriptionID: profile.mustID)
                } else {
                    model.activateNewlyImportedSubscription(profile.mustID)
                    resultOK = true
                    resultMessage = "Файл импортирован и активирован"
                    HapticManager.shared.play(.imported)
                }
            } catch {
                resultOK = false
                resultMessage = error.localizedDescription
                HapticManager.shared.play(.error)
            }
        }
    }
}

struct DirectImportConfigTextView: View {
    @ObservedObject var model: VPNConnectionModel
    @EnvironmentObject private var environments: ExtensionEnvironments
    @State private var profileName = ""
    @State private var configText = ""
    @State private var isSaving = false
    @State private var resultMessage: String?
    @State private var resultOK = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                SystemBackButton(model: model, title: "Подписки", destination: nil)
                PageHeading(
                    kicker: "ИМПОРТ / КОНФИГ",
                    title: "Вставить конфиг",
                    subtitle: "JSON, Clash YAML, WireGuard или список URI"
                )
                .padding(.top, 17)

                HStack {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("БЕЗ ССЫЛКИ").microLabel(color: .white.opacity(0.42))
                        Text("sing-box · xray · clash · wg · uri")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                    Spacer()
                    Image(systemName: "doc.plaintext").foregroundStyle(DS.acid)
                }
                .padding(16)
                .frame(minHeight: 88)
                .background(DS.panel)
                .foregroundStyle(.white)
                .padding(.top, 24)

                ConfigField(number: "01", title: "КОНФИГУРАЦИЯ") {
                    TextEditor(text: $configText)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 160)
                        .padding(10)
                        .background(Color.white.opacity(0.35))
                        .overlay(Rectangle().stroke(DS.line))
                }

                ConfigField(number: "02", title: "ИМЯ") {
                    TextField("Например, Manual Nodes", text: $profileName)
                        .font(.system(size: 13))
                        .padding(.horizontal, 13)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.35))
                        .overlay(Rectangle().stroke(DS.line))
                }

                if let resultMessage {
                    Label(resultMessage, systemImage: resultOK ? "checkmark.circle" : "exclamationmark.triangle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(resultOK ? DS.green : Color.orange)
                        .padding(.top, 14)
                }

                Button {
                    importText()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView().tint(DS.acid)
                        } else {
                            Image(systemName: "plus.square.on.square")
                        }
                        Text(isSaving ? "Создание…" : "Создать из конфига")
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
                .disabled(isSaving)
                .padding(.top, 18)

                Text("Вставьте полный конфиг или список share-ссылок. Пустой `{}` не принимается.")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.muted)
                    .lineSpacing(3)
                    .padding(.top, 15)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .onAppear {
            if configText.isEmpty, let pending = model.pendingImportConfigText?.trimmingCharacters(in: .whitespacesAndNewlines),
               !pending.isEmpty
            {
                configText = pending
                model.pendingImportConfigText = nil
            }
        }
    }

    private func importText() {
        let trimmed = configText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            resultOK = false
            resultMessage = "Вставьте конфигурацию"
            HapticManager.shared.play(.error)
            return
        }
        guard DirectLocalProfileImporter.looksLikeConfigContent(trimmed) else {
            resultOK = false
            resultMessage = "Неизвестный формат. Нужен JSON, Clash, WG или список URI"
            HapticManager.shared.play(.error)
            return
        }

        isSaving = true
        resultMessage = nil
        Task {
            defer { isSaving = false }
            do {
                let profile = try await DirectLocalProfileImporter.importContent(trimmed, preferredName: profileName)
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
            } catch {
                resultOK = false
                resultMessage = error.localizedDescription
                HapticManager.shared.play(.error)
            }
        }
    }
}

#endif
