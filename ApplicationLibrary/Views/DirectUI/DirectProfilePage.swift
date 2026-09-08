import Library
import SwiftUI

#if os(iOS)

struct DirectProfilePage: View {
    @ObservedObject var model: VPNConnectionModel

    private var settings: [(String, String, String, DetailPage)] {
        [
            ("Безопасность", "Автоподключение, DNS и российские сайты", "shield", .security),
            ("Подключение", "Протокол, failover и 5G", "point.3.connected.trianglepath.dotted", .connection),
            ("Диагностика", "Проверка и автоматическое исправление", "waveform.path.ecg", .diagnostics),
            ("Мои серверы", "Избранное и история подключений", "star", .activity),
            ("Системные настройки", "Ядро, туннель и служебные параметры", "slider.horizontal.3", .systemWarning),
        ]
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(kicker: "АККАУНТ / ALD–0248", title: "Профиль", subtitle: "Управление приложением и безопасностью")

                HStack(spacing: 16) {
                    Text("A")
                        .font(.system(size: 30, weight: .medium, design: .monospaced))
                        .foregroundStyle(DS.acid)
                        .frame(width: 62, height: 62)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.25)))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ").microLabel(color: .white.opacity(0.45))
                        Text("Ваш профиль").font(.system(size: 19, weight: .semibold))
                        Text(model.isProtected ? "Статус: Подключено" : "Статус: Отключено")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "arrow.up.right").foregroundStyle(DS.acid)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 116)
                .background(DS.ink)
                .foregroundStyle(.white)
                .padding(.top, 28)

                HStack(spacing: 0) {
                    ProfileStat(label: "ПОДПИСОК", value: String(format: "%02d", model.subscriptions.count))
                    ProfileStat(label: "УСТРОЙСТВ", value: "01")
                    ProfileStat(label: "ЗАЩИЩЕНО", value: model.isProtected ? model.runtimeText : "00:00")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 76)
                .overlay(alignment: .bottom) { Hairline() }

                VStack(spacing: 0) {
                    ForEach(Array(settings.enumerated()), id: \.offset) { index, item in
                        Button {
                            model.openDetail(item.3)
                        } label: {
                            HStack(spacing: 13) {
                                Text(String(format: "%02d", index + 1)).microLabel()
                                Image(systemName: item.2).frame(width: 23)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.0).font(.system(size: 14, weight: .semibold))
                                        .lineLimit(1)
                                    Text(item.1).font(.system(size: 10)).foregroundStyle(DS.muted)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "arrow.right").font(.system(size: 11))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 67)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(HapticButtonStyle())
                        .overlay(alignment: .bottom) { Hairline() }
                    }
                }
                .padding(.top, 15)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ProfileStat: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).microLabel()
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 12)
        .overlay(alignment: .leading) { Hairline().frame(width: 1) }
    }
}

#endif
