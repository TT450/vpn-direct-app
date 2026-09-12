import SwiftUI

#if os(iOS)

// MARK: - Shared utility shell

private struct UtilityShell<Content: View>: View {
    let kicker: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(kicker: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.kicker = kicker
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(kicker: kicker, title: title, subtitle: subtitle)
                    .padding(.bottom, 22)
                content
                Spacer(minLength: 28)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(DS.paper.ignoresSafeArea())
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
    @State private var showRevoke = false

    var body: some View {
        UtilityShell(kicker: "ACCOUNT / DEVICES", title: "Устройства", subtitle: "Контроль активных подключений аккаунта") {
            UtilityHeader(number: "01", title: "ЛИМИТ", detail: deviceLimitLabel)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Text("01")
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DS.acid)
                        .frame(width: 58, height: 58)
                        .background(DS.ink)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("ЭТО УСТРОЙСТВО").microLabel(color: DS.ink)
                        Text("iPhone · VPN Direct").font(.system(size: 14, weight: .semibold))
                        Text(model.isProtected ? "Подключено сейчас" : "Не подключено")
                            .font(.system(size: 10)).foregroundStyle(model.isProtected ? DS.green : DS.muted)
                    }
                    Spacer()
                    Text("АКТИВНО").microLabel(color: DS.green)
                }
                .padding(.vertical, 15)
                .overlay(alignment: .bottom) { Hairline() }

                Text("В этом разделе будет показан каждый сеанс, которому выдали доступ к подписке. Отозванный сеанс больше не сможет подключаться.")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.muted)
                    .lineSpacing(3)
                    .padding(.top, 14)

                Button {
                    showRevoke = true
                } label: {
                    HStack {
                        Text("ЗАВЕРШИТЬ СЕАНС")
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
            }

            UtilityHeader(number: "02", title: "БЕЗОПАСНОСТЬ", detail: "СЕССИИ")
                .padding(.top, 24)
            Text("При смене пароля или подозрении на чужой доступ завершите все остальные сеансы. Управление серверной сессией подключается к аккаунтному API без изменения дизайна этого экрана.")
                .font(.system(size: 10))
                .foregroundStyle(DS.muted)
                .lineSpacing(3)
                .padding(.top, 12)
        }
        .alert("Завершить сеанс?", isPresented: $showRevoke) {
            Button("Завершить", role: .destructive) { HapticManager.shared.play(.selection) }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Текущее устройство будет отключено от аккаунта при следующем обновлении сессии.")
        }
    }

    private var deviceLimitLabel: String {
        let limit = model.hasPremiumEntitlement ? model.premiumDeviceLimit : model.selectedPlan.devices
        return "01 / \(limit)"
    }
}

// MARK: - Promo

struct DirectPromoView: View {
    @State private var code = ""
    @State private var appliedCode: String?
    @State private var message: String?

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

                Button {
                    let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    guard !normalized.isEmpty else {
                        message = "Введите промокод."
                        return
                    }
                    appliedCode = normalized
                    message = "Код сохранён для проверки."
                    HapticManager.shared.play(.selection)
                } label: {
                    HStack {
                        Text("ПРОВЕРИТЬ КОД")
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

                if let message {
                    Text(message)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(appliedCode == nil ? DS.danger : DS.green)
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
                        Text("КОД ПРИНЯТ В ПРИЛОЖЕНИИ").microLabel(color: DS.ink)
                        Text("Финальная проверка выполняется сервером перед применением скидки или бонуса.")
                            .font(.system(size: 10)).foregroundStyle(DS.muted)
                    }
                }
                .padding(.top, 13)
            }
        }
    }
}

// MARK: - Payment history

struct DirectPaymentHistoryView: View {
    @ObservedObject var model: VPNConnectionModel

    var body: some View {
        UtilityShell(kicker: "ACCOUNT / PAYMENTS", title: "Платежи", subtitle: "Оплаты, продления и возвраты") {
            UtilityHeader(number: "01", title: "ИСТОРИЯ", detail: "ВСЕ ОПЕРАЦИИ")
            if model.subscriptions.isEmpty {
                emptyState
            } else {
                ForEach(Array(model.subscriptions.prefix(6).enumerated()), id: \.offset) { index, subscription in
                    HStack(spacing: 12) {
                        Text(String(format: "%02d", index + 1)).microLabel(color: DS.acid)
                            .frame(width: 42, height: 42)
                            .background(DS.ink)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(subscription.name).font(.system(size: 13, weight: .semibold))
                            Text("Подписка · статус по аккаунту")
                                .font(.system(size: 10)).foregroundStyle(DS.muted)
                        }
                        Spacer()
                        Text(subscription.expiry).microLabel(color: DS.ink)
                    }
                    .frame(minHeight: 62)
                    .overlay(alignment: .bottom) { Hairline() }
                }
            }

            UtilityHeader(number: "02", title: "ВОЗВРАТЫ", detail: "SUPPORT")
                .padding(.top, 24)
            Text("Если операция отменена банком, зависла или требуется возврат, откройте поддержку и приложите номер операции из банковского приложения.")
                .font(.system(size: 10)).foregroundStyle(DS.muted).lineSpacing(3)
                .padding(.top, 12)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("ПОКА НЕТ ОПЕРАЦИЙ").microLabel(color: DS.ink)
            Text("История платежей появится после первой оплаты через аккаунт.")
                .font(.system(size: 12)).foregroundStyle(DS.muted)
        }
        .padding(.vertical, 18)
    }
}

// MARK: - Support

struct DirectSupportView: View {
    @State private var selectedIssue = "Оплата"
    @State private var details = ""
    @State private var sent = false

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
            }
            .padding(.top, 16)

            Button {
                sent = true
                HapticManager.shared.play(.selection)
            } label: {
                HStack {
                    Text(sent ? "ЗАПРОС СОХРАНЁН" : "ОТПРАВИТЬ В ПОДДЕРЖКУ")
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
            .padding(.top, 14)

            UtilityHeader(number: "02", title: "БЫСТРАЯ ПОМОЩЬ", detail: "ОПЛАТА / AUTH")
                .padding(.top, 24)
            supportRow("Оплата не активировалась", "Не повторяйте платёж. Сначала обновите статус операции.")
            supportRow("Не получается войти", "Проверьте способ входа: Apple, Google, email, телефон или Telegram.")
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
}

// MARK: - Account linking

struct DirectAccountLinkingView: View {
    @State private var showConfirm = false

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

            UtilityHeader(number: "02", title: "СКЛЕЙКА", detail: "ПОДТВЕРЖДЕНИЕ")
                .padding(.top, 24)
            UtilityRow(mark: "APPLE", title: "Apple ID", detail: "Проверить текущий способ входа", accent: true) {
                showConfirm = true
            }
            UtilityRow(mark: "MAIL", title: "Email", detail: "Подключить к этому аккаунту") {
                showConfirm = true
            }
            UtilityRow(mark: "TG", title: "Telegram", detail: "Связать через подтверждение в боте") {
                showConfirm = true
            }
        }
        .alert("Подтвердить связь?", isPresented: $showConfirm) {
            Button("Продолжить") { HapticManager.shared.play(.selection) }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Сначала подтверждается владение обоими способами входа. Существующие подписки не объединяются автоматически без подтверждения.")
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
