import SwiftUI

#if os(iOS)
struct AuthPageShell<Content: View>: View {
    let kicker: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(kicker: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.kicker = kicker; self.title = title; self.subtitle = subtitle; self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(kicker: kicker, title: title, subtitle: subtitle)
                    .padding(.top, DS.pageTop).padding(.bottom, 24)
                content
                Spacer(minLength: 28)
            }.padding(.horizontal, 20)
        }.background(DS.paper.ignoresSafeArea())
    }
}

struct AuthField: View {
    let title: String; let placeholder: String; @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).microLabel(color: DS.ink)
            TextField(placeholder, text: $text)
                .font(.system(size: 14)).textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(.horizontal, 13).frame(height: 50)
                .background(Color.white.opacity(0.45)).overlay(Rectangle().stroke(DS.line))
        }
    }
}

struct AuthPasswordField: View {
    let title: String; let placeholder: String; @Binding var text: String; @Binding var revealed: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).microLabel(color: DS.ink)
            HStack(spacing: 10) {
                if revealed { TextField(placeholder, text: $text) } else { SecureField(placeholder, text: $text) }
                Button { revealed.toggle() } label: { Image(systemName: revealed ? "eye.slash" : "eye").foregroundStyle(DS.muted) }.buttonStyle(.plain)
            }.font(.system(size: 14)).padding(.horizontal, 13).frame(height: 50)
                .background(Color.white.opacity(0.45)).overlay(Rectangle().stroke(DS.line))
        }
    }
}

struct AuthPrimaryButton: View {
    let title: String; let icon: String?; let action: () -> Void
    var body: some View {
        Button(action: action) { HStack { Text(title); Spacer(); if let icon { Image(systemName: icon) } }
            .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(DS.acid)
            .padding(.horizontal, 14).frame(height: 50).background(DS.ink) }.buttonStyle(HapticButtonStyle())
    }
}

struct AuthSecondaryButton: View {
    let title: String; let icon: String?; let action: () -> Void
    var body: some View {
        Button(action: action) { HStack(spacing: 10) { if let icon { Image(systemName: icon).frame(width: 18) }; Text(title); Spacer() }
            .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(DS.ink)
            .padding(.horizontal, 13).frame(height: 48).background(Color.white.opacity(0.45)).overlay(Rectangle().stroke(DS.line))
        }.buttonStyle(HapticButtonStyle())
    }
}
#endif
