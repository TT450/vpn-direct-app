import SwiftUI

#if os(iOS)

// MARK: - Shared utility shell

private struct UtilityShell<Content: View>: View {
    let kicker: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    init(kicker: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.kicker = kicker
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(kicker).microLabel()
                    Text(title)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(DS.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(DS.ink)
                        .foregroundStyle(DS.acid)
                }
                .buttonStyle(HapticButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 14)
            .overlay(alignment: .bottom) { Hairline() }
            .background(DS.paper)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    content
                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(DS.paper.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}

private struct UtilityHeader: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(number).microLabel(color: DS.ink)
            Text(title).microLabel(color: DS.ink)
            Spacer()
            Text(detail).microLabel(color: DS.green)
        }
        .frame(height: 38)
        .overlay(alignment: .top) { Hairline(color: DS.ink) }
    }
}

private struct UtilityRow: View {
    let mark: String
    let title: String
    let detail: String
    var accent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(mark)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent ? DS.acid : DS.ink)
                    .frame(width: 42, height: 42)
                    .background(accent ? DS.ink : Color.white.opacity(0.38))
                    .overlay(Rectangle().stroke(accent ? Color.clear : DS.line))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(detail).font(.system(size: 10)).foregroundStyle(DS.muted)
                }
                Spacer()
                Image(systemName: "arrow.right").font(.system(size: 11))
            }
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle())
        .overlay(alignment: .bottom) { Hairline() }
    }
}

// MARK: - Devices

struct DirectDevicesView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var devices: [DirectAccountDevice] = []
    @State private var loading = false
    @State private var errorText: String?
    @State private var revokeTarget: DirectAccountDevice?
    @State private var showRevokeCurrent = false

    var body: some View {
        UtilityShell(kicker: "ACCOUNT / DEVICES", title: "Устройства", subtitle: "Подключённые клиенты по HWID подписки") {
            UtilityHeader(number: "01", title: "ЛИМИТ", detail: deviceLimitLabel)

            if loading {
                ProgressView().padding(.vertical, 18)
            } else if devices.isEmpty {
                currentDeviceCard
            } else {
                ForEach(devices) { device in
                    deviceRow(device)
                }
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.danger)
                    .padding(.top, 10)
            }

            Text("Удаление снимает HWID с подписки: клиент перестанет получать конфиг, пока снова не подключится в пределах лимита.")
                .font(.system(size: 10))
                .foregroundStyle(DS.muted)
                .lineSpacing(3)
                .padding(.top, 14)

            Button {
                showRevokeCurrent = true
            } label: {
                HStack {
                    Text("ВЫЙТИ ИЗ АККАУНТА")
                    Spacer()
                    Image(systemName: "xmark")
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.ink)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .overlay(Rectangle().stroke(DS.ink))
            }
            .buttonStyle(HapticButtonStyle())
            .padding(.top, 16)

            UtilityHeader(number: "02", title: "БЕЗОПАСНОСТЬ", detail: "HWID")
                .padding(.top, 24)
            Text("Список — те же устройства, что в админке: модель/ОС из обращений к подписке. Удаление синхронизируется с панелью.")
                .font(.system(size: 10))
                .foregroundStyle(DS.muted)
                .lineSpacing(3)
                .padding(.top, 12)
        }
        .task { await reload() }
        .alert("Удалить устройство?", isPresented: Binding(
            get: { revokeTarget != nil },
            set: { if !$0 { revokeTarget = nil } }
        )) {
            Button("Удалить", role: .destructive) {
                if let target = revokeTarget {
                    Task { await revoke(target) }
                }
            }
            Button("Отмена", role: .cancel) { revokeTarget = nil }
        } message: {
            Text("Клиент потеряет место в лимите HWID до следующего подключения.")
        }
        .alert("Выйти из аккаунта?", isPresented: $showRevokeCurrent) {
            Button("Выйти", role: .destructive) {
                Task { await revokeCurrent() }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Вы выйдете из аккаунта на этом iPhone. Подключения других устройств не изменятся.")
        }
    }

    private var currentDeviceCard: some View {
        HStack(spacing: 14) {
            Text("01")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(DS.acid)
                .frame(width: 58, height: 58)
                .background(DS.ink)
            VStack(alignment: .leading, spacing: 5) {
                Text("НЕТ HWID").microLabel(color: DS.ink)
                Text("Пока нет подключённых клиентов").font(.system(size: 14, weight: .semibold))
                Text(model.isProtected ? "VPN на этом iPhone активен" : "Откройте подписку с устройства")
                    .font(.system(size: 10)).foregroundStyle(model.isProtected ? DS.green : DS.muted)
            }
            Spacer()
            Text("АКТИВНО").microLabel(color: DS.green)
        }
        .padding(.vertical, 15)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func deviceRow(_ device: DirectAccountDevice) -> some View {
        HStack(spacing: 12) {
            Text(device.isCurrent ? "NOW" : "DEV")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.acid)
                .frame(width: 42, height: 42)
                .background(DS.ink)
            VStack(alignment: .leading, spacing: 4) {
                Text(device.label).font(.system(size: 13, weight: .semibold))
                Text(device.detail)
                    .font(.system(size: 10)).foregroundStyle(DS.muted)
            }
            Spacer()
            if device.isCurrent {
                Text("АКТИВНО").microLabel(color: DS.green)
            } else {
                Button("УДАЛИТЬ") { revokeTarget = device }
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.ink)
            }
        }
        .frame(minHeight: 62)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var deviceLimitLabel: String {
        let used = devices.count
        let limit = model.hasPremiumEntitlement ? model.premiumDeviceLimit : model.selectedPlan.devices
        return String(format: "%02d / %d", used, max(limit, 1))
    }

    @MainActor
    private func reload() async {
        loading = true
        errorText = nil
        defer { loading = false }
        DirectBackendRuntime.warmUp()
        do {
            devices = try await DirectBackendRuntime.fetchAccountDevices()
        } catch {
            errorText = error.localizedDescription
            devices = []
        }
    }

    @MainActor
    private func revoke(_ device: DirectAccountDevice) async {
        DirectBackendRuntime.warmUp()
        do {
            try await DirectBackendRuntime.revokeAccountDevice(device.id)
            HapticManager.shared.play(.selection)
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
        revokeTarget = nil
    }

    @MainActor
    private func revokeCurrent() async {
        DirectBackendRuntime.warmUp()
        if let run = DirectBackendRuntime.logout {
            await run(model)
        }
        HapticManager.shared.play(.selection)
    }
}

// MARK: - Promo

struct DirectPromoView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var code = ""
    @State private var appliedCode: String?
    @State private var message: String?
    @State private var success = false
    @State private var busy = false

    var body: some View {
        UtilityShell(kicker: "DIRECT / PROMO", title: "Промокод", subtitle: "Введите код, полученный от VPN Direct") {
            UtilityHeader(number: "01", title: "КОД", detail: "АКТИВАЦИЯ")
            VStack(alignment: .leading, spacing: 9) {
                Text("ПРОМОКОД").microLabel(color: DS.ink)
                TextField("Например, DIRECT2026", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 13)
                    .frame(height: 54)
                    .background(Color.white.opacity(0.45))
                    .overlay(Rectangle().stroke(DS.line))
                    .disabled(busy)

                Button {
                    Task { await redeem() }
                } label: {
                    HStack {
                        Text(busy ? "ПРОВЕРЯЕМ…" : "ПРОВЕРИТЬ КОД")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(DS.ink)
                }
                .buttonStyle(HapticButtonStyle())
                .disabled(busy)

                if let message {
                    Text(message)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(success ? DS.green : DS.danger)
                        .padding(.top, 3)
                }
            }
            .padding(.top, 12)

            if let appliedCode {
                UtilityHeader(number: "02", title: "ВВЕДЁН", detail: appliedCode)
                    .padding(.top, 24)
                HStack(spacing: 12) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(DS.acid)
                        .frame(width: 42, height: 42)
                        .background(DS.ink)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(success ? "КОД ПРИМЕНЁН" : "КОД ПРИНЯТ В ПРИЛОЖЕНИИ").microLabel(color: DS.ink)
                        Text(success
                             ? "Бонус записан на аккаунт. Обновите профиль, если статус не изменился сразу."
                             : "Финальная проверка выполняется сервером перед применением скидки или бонуса.")
                            .font(.system(size: 10)).foregroundStyle(DS.muted)
                    }
                }
                .padding(.top, 13)
            }
        }
    }

    @MainActor
    private func redeem() async {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else {
            success = false
            message = "Введите промокод."
            return
        }
        busy = true
        defer { busy = false }
        DirectBackendRuntime.warmUp()
        do {
            let result = try await DirectBackendRuntime.redeemPromo(normalized)
            appliedCode = normalized
            success = result.ok
            message = result.message
            if result.ok {
                HapticManager.shared.play(.purchaseCompleted)
                await model.refreshDirectAccount()
            } else {
                HapticManager.shared.play(.error)
            }
        } catch {
            success = false
            message = error.localizedDescription
            HapticManager.shared.play(.error)
        }
    }
}

// MARK: - Payment history

struct DirectPaymentHistoryView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var payments: [DirectAccountPayment] = []
    @State private var loading = false
    @State private var errorText: String?

    var body: some View {
        UtilityShell(kicker: "ACCOUNT / PAYMENTS", title: "Платежи", subtitle: "Оплаты, продления и возвраты") {
            UtilityHeader(number: "01", title: "ИСТОРИЯ", detail: "ВСЕ ОПЕРАЦИИ")
            if loading {
                ProgressView().padding(.vertical, 18)
            } else if payments.isEmpty {
                emptyState
            } else {
                ForEach(Array(payments.enumerated()), id: \.element.id) { index, payment in
                    HStack(spacing: 12) {
                        Text(String(format: "%02d", index + 1)).microLabel(color: DS.acid)
                            .frame(width: 42, height: 42)
                            .background(DS.ink)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(payment.title).font(.system(size: 13, weight: .semibold))
                            Text(payment.subtitle)
                                .font(.system(size: 10)).foregroundStyle(DS.muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(payment.amountLabel).microLabel(color: DS.ink)
                            Text(payment.statusLabel)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(payment.isRefundLike ? DS.danger : DS.green)
                        }
                    }
                    .frame(minHeight: 62)
                    .overlay(alignment: .bottom) { Hairline() }
                }
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.danger)
                    .padding(.top, 8)
            }

            UtilityHeader(number: "02", title: "ВОЗВРАТЫ", detail: "SUPPORT")
                .padding(.top, 24)
            Text("Если операция отменена банком, зависла или требуется возврат, откройте поддержку и приложите номер операции из банковского приложения.")
                .font(.system(size: 10)).foregroundStyle(DS.muted).lineSpacing(3)
                .padding(.top, 12)
        }
        .task { await reload() }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("ПОКА НЕТ ОПЕРАЦИЙ").microLabel(color: DS.ink)
            Text("История платежей появится после первой оплаты через аккаунт.")
                .font(.system(size: 12)).foregroundStyle(DS.muted)
        }
        .padding(.vertical, 18)
    }

    @MainActor
    private func reload() async {
        loading = true
        errorText = nil
        defer { loading = false }
        DirectBackendRuntime.warmUp()
        do {
            payments = try await DirectBackendRuntime.fetchAccountPayments()
        } catch {
            errorText = error.localizedDescription
            payments = []
        }
    }
}

// MARK: - Support

struct DirectSupportView: View {
    @State private var selectedIssue = "Оплата"
    @State private var details = ""
    @State private var sent = false
    @State private var busy = false
    @State private var errorText: String?

    private let issues = ["Оплата", "Вход", "Подписка", "Подключение"]

    var body: some View {
        UtilityShell(kicker: "DIRECT / SUPPORT", title: "Поддержка", subtitle: "Разберём оплату, вход и проблемы с доступом") {
            UtilityHeader(number: "01", title: "ПРОБЛЕМА", detail: "ВЫБЕРИТЕ")
            Picker("", selection: $selectedIssue) {
                ForEach(issues, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 8) {
                Text("ОПИСАНИЕ").microLabel(color: DS.ink)
                TextEditor(text: $details)
                    .font(.system(size: 12))
                    .frame(minHeight: 118)
                    .padding(8)
                    .background(Color.white.opacity(0.42))
                    .overlay(Rectangle().stroke(DS.line))
                    .disabled(busy || sent)
            }
            .padding(.top, 16)

            Button {
                Task { await submit() }
            } label: {
                HStack {
                    Text(sent ? "ЗАПРОС ОТПРАВЛЕН" : (busy ? "ОТПРАВЛЯЕМ…" : "ОТПРАВИТЬ В ПОДДЕРЖКУ"))
                    Spacer()
                    Image(systemName: sent ? "checkmark" : "arrow.right")
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.acid)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(DS.ink)
            }
            .buttonStyle(HapticButtonStyle())
            .disabled(busy || sent)
            .padding(.top, 14)

            if let errorText {
                Text(errorText)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.danger)
                    .padding(.top, 6)
            }

            UtilityHeader(number: "02", title: "БЫСТРАЯ ПОМОЩЬ", detail: "ОПЛАТА / AUTH")
                .padding(.top, 24)
            supportRow("Оплата не активировалась", "Не повторяйте платёж. Сначала обновите статус операции.")
            supportRow("Не получается войти", "Проверьте способ входа: Apple, Google, email, телефон или код бота.")
            supportRow("Другой аккаунт", "Apple и email могут быть независимыми аккаунтами — не создавайте второй платёж, пока не проверим связку.")
        }
    }

    private func supportRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12, weight: .semibold))
            Text(detail).font(.system(size: 10)).foregroundStyle(DS.muted).lineSpacing(2)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { Hairline() }
    }

    @MainActor
    private func submit() async {
        let text = details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorText = "Опишите проблему в нескольких словах."
            return
        }
        busy = true
        errorText = nil
        defer { busy = false }
        DirectBackendRuntime.warmUp()
        do {
            try await DirectBackendRuntime.submitSupport(selectedIssue, text)
            sent = true
            HapticManager.shared.play(.selection)
        } catch {
            errorText = error.localizedDescription
            HapticManager.shared.play(.error)
        }
    }
}

// MARK: - Account linking

struct DirectAccountLinkingView: View {
    @ObservedObject var model: VPNConnectionModel
    @State private var showConfirm = false
    @State private var pendingMethod = ""
    @State private var message: String?

    var body: some View {
        UtilityShell(kicker: "ACCOUNT / IDENTITY", title: "Способы входа", subtitle: "Apple, email и другие способы могут быть отдельными аккаунтами") {
            UtilityHeader(number: "01", title: "ВАЖНО", detail: "НЕ СКЛЕИВАТЬ СЛУЧАЙНО")
            HStack(alignment: .top, spacing: 12) {
                Text("!")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.acid)
                    .frame(width: 42, height: 42)
                    .background(DS.ink)
                Text("Если вы вошли через Apple, а затем используете email, это может открыть другой аккаунт. Подписка автоматически не переносится.")
                    .font(.system(size: 11)).foregroundStyle(DS.ink).lineSpacing(3)
            }
            .padding(.top, 13)

            UtilityHeader(number: "02", title: "ТЕКУЩИЙ", detail: model.authMethodLabel.uppercased())
                .padding(.top, 24)
            Text(model.isDirectAuthenticated
                 ? "Сейчас активен: \(model.accountDisplayTitle) · \(model.authMethodLabel)"
                 : "Сначала войдите в аккаунт, затем можно связать другой способ входа.")
                .font(.system(size: 10))
                .foregroundStyle(DS.muted)
                .padding(.top, 10)

            UtilityHeader(number: "03", title: "СКЛЕЙКА", detail: "ПОДТВЕРЖДЕНИЕ")
                .padding(.top, 24)
            UtilityRow(mark: "APPLE", title: "Apple ID", detail: "Проверить / привязать Apple", accent: true) {
                pendingMethod = "apple"
                showConfirm = true
            }
            UtilityRow(mark: "MAIL", title: "Email", detail: "Подключить email к этому аккаунту") {
                pendingMethod = "email"
                showConfirm = true
            }
            UtilityRow(mark: "BOT", title: "Telegram-бот", detail: "Связать через код из @vpndirectbot") {
                pendingMethod = "bot"
                showConfirm = true
            }

            if let message {
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.green)
                    .padding(.top, 12)
            }
        }
        .alert("Подтвердить связь?", isPresented: $showConfirm) {
            Button("Продолжить") {
                Task { await prepareLink() }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Сначала подтверждается владение обоими способами входа. Существующие подписки не объединяются автоматически без подтверждения.")
        }
    }

    @MainActor
    private func prepareLink() async {
        DirectBackendRuntime.warmUp()
        do {
            message = try await DirectBackendRuntime.prepareAccountLink(pendingMethod)
            HapticManager.shared.play(.selection)
            switch pendingMethod {
            case "email":
                model.openDetail(.authEmail)
            case "bot":
                model.openDetail(.authBot)
            case "apple":
                await model.signInWithAppleForAuth()
            default:
                break
            }
        } catch {
            message = error.localizedDescription
            HapticManager.shared.play(.error)
        }
    }
}

// MARK: - Force update

struct DirectForceUpdateView: View {
    let currentVersion: String
    let minimumVersion: String
    let updateURL: URL?

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text("DIRECT / REQUIRED").microLabel(color: DS.ink)
                Text("Нужно обновление")
                    .font(.system(size: 34, weight: .semibold))
                    .padding(.top, 9)
                Text("Эта версия VPN Direct больше не поддерживается. Обновите приложение, чтобы продолжить безопасно.")
                    .font(.system(size: 13)).foregroundStyle(DS.muted)
                    .lineSpacing(3)
                    .padding(.top, 8)

                HStack(spacing: 0) {
                    updateFact("ВАША ВЕРСИЯ", currentVersion)
                    updateFact("МИНИМУМ", minimumVersion)
                }
                .padding(.top, 25)

                if let updateURL {
                    Link(destination: updateURL) {
                        HStack {
                            Text("ОБНОВИТЬ VPN DIRECT")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.acid)
                        .padding(.horizontal, 15)
                        .frame(height: 54)
                        .background(DS.ink)
                    }
                    .padding(.top, 18)
                }
                Spacer()
            }
            .padding(.horizontal, 22)
        }
    }

    private func updateFact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).microLabel(color: DS.muted)
            Text(value).font(.system(size: 15, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .leading) { Hairline().frame(width: 1) }
    }
}

#endif
