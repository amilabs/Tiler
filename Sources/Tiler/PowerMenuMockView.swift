import SwiftUI

/// Throwaway mockups for the add-power-control UI gate (2.1). Rendered by
/// `--render-shots`; ships nothing. Gives the owner a picture of the menu wording,
/// the two status-item indicator variants, and the Power settings tab before any
/// real menu/settings wiring (owner rule: show pictures first).

// MARK: - Menu + status-item indicator

struct PowerMenuMockView: View {
    private let durations = ["For 10 minutes", "For 30 minutes", "For 1 hour",
                             "For 2 hours", "For 5 hours", "For 10 hours", "For 24 hours"]

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("“Keep Awake” submenu")
                menuPanel
            }
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Status-item indicator (active session)")
                    indicatorVariants
                }
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Header line — state wordings")
                    headerWordings
                }
            }
        }
        .padding(24)
        .frame(width: 640)
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
    }

    // A macOS-menu-like panel.
    private var menuPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            row("On — 27 min left", role: .header)
            divider
            row("On (until stopped)")
            ForEach(durations, id: \.self) { row($0) }
            divider
            row("Keep awake with lid closed  ⚠", role: .checkbox)
            divider
            row("Stop", role: .strong)
        }
        .padding(.vertical, 6)
        .frame(width: 250, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.98)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.black.opacity(0.12)))
    }

    private enum RowRole { case normal, header, checkbox, strong }

    private func row(_ title: String, role: RowRole = .normal) -> some View {
        HStack(spacing: 6) {
            if role == .checkbox {
                Image(systemName: "square").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Text(title)
                .font(.system(size: 13, weight: role == .strong ? .semibold : .regular))
                .foregroundStyle(role == .header ? Color.secondary : Color.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3.5)
    }

    private var divider: some View {
        Divider().padding(.vertical, 4).padding(.horizontal, 8)
    }

    // Two candidate indicators shown on a faux light menu bar.
    private var indicatorVariants: some View {
        VStack(alignment: .leading, spacing: 14) {
            labelledBar("A · “☕” text next to the icon") {
                Image(systemName: "hand.pinch.fill")
                Text("☕").font(.system(size: 13))
            }
            labelledBar("B · SF Symbol cup.and.saucer.fill") {
                Image(systemName: "hand.pinch.fill")
                Image(systemName: "cup.and.saucer.fill")
            }
            labelledBar("either · coexists with the ⚠ permission marker") {
                Image(systemName: "hand.pinch.fill")
                Image(systemName: "cup.and.saucer.fill")
                Text("⚠︎").font(.system(size: 13)).foregroundStyle(.primary)
            }
        }
    }

    private func labelledBar<Content: View>(_ caption: String,
                                            @ViewBuilder _ glyphs: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Spacer()
                glyphs()
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .frame(width: 220, height: 26)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.93)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.black.opacity(0.10)))
            Text(caption).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private var headerWordings: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(["Off",
                     "On — 27 min left",
                     "On (until stopped)",
                     "On — lid-closed ⚠"], id: \.self) { w in
                Text("• \(w)").font(.system(size: 12)).foregroundStyle(.primary)
            }
        }
    }
}

// MARK: - Status-item indicator variants (owner feedback: recolor/encircle, no 2nd icon)

/// Owner direction (gate 2.1, round 2): don't add a second icon — when Keep Awake is
/// active, recolor the existing status glyph red, optionally encircling the (shrunk)
/// icon with a contour coffee-cup / ring. Several variants on both light and dark
/// menu bars (legibility matters).
struct PowerIndicatorMockView: View {
    private let red = Color(nsColor: .systemRed)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Индикатор активной сессии — варианты (иконка hand.pinch.fill)")
                .font(.system(size: 13, weight: .semibold))
            Text("столбцы: светлый бар · тёмный бар")
                .font(.system(size: 11)).foregroundStyle(.secondary)

            row("Сейчас — неактивно (шаблон)") { pinch(.primary) }
            Divider()
            row("1 · Красная заливка") { pinch(red) }
            row("2 · Красная, крупнее+жирнее") { pinch(red, size: 17, weight: .bold) }
            row("3 · Иконка в контурном кольце") { ringed }
            row("4 · Контур чашки вокруг иконки") { cupAround }
            row("5 · Иконка + мини-бейдж чашки") { badged }
        }
        .padding(24)
        .frame(width: 520)
        .background(.white)
    }

    private func row<G: View>(_ label: String, @ViewBuilder _ glyph: () -> G) -> some View {
        HStack(spacing: 14) {
            Text(label).font(.system(size: 12)).frame(width: 250, alignment: .leading)
            bar(dark: false, glyph)
            bar(dark: true, glyph)
        }
    }

    private func bar<G: View>(dark: Bool, @ViewBuilder _ glyph: () -> G) -> some View {
        HStack { Spacer(); glyph() }
            .padding(.horizontal, 12)
            .frame(width: 96, height: 28)
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(dark ? Color(white: 0.16) : Color(white: 0.95)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.black.opacity(0.08)))
            .environment(\.colorScheme, dark ? .dark : .light)
    }

    private func pinch(_ color: Color, size: CGFloat = 15, weight: Font.Weight = .regular) -> some View {
        Image(systemName: "hand.pinch.fill")
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color)
    }

    private var ringed: some View {
        ZStack {
            Circle().strokeBorder(red, lineWidth: 1.6).frame(width: 22, height: 22)
            pinch(red, size: 11)
        }
    }

    private var cupAround: some View {
        ZStack {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 22))
                .foregroundStyle(red)
            pinch(red, size: 9)
                .offset(y: -1)
        }
    }

    private var badged: some View {
        pinch(red)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(red)
                    .offset(x: 5, y: 3)
            }
    }
}

// MARK: - Settings → Power tab (hand-drawn reconstruction for the mock)

/// NOTE: the shipping tab (task 2.3) is a real grouped `Form` inside SettingsView's
/// TabView. This mock hand-draws the same layout/wording with plain SwiftUI because a
/// List-backed Form does not rasterize under ImageRenderer in a headless render — the
/// picture is for the owner's layout/wording sign-off, the shipping control is native.
struct PowerSettingsMockView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabStrip
            VStack(alignment: .leading, spacing: 18) {
                section("Keep Awake") {
                    toggleRow("Keep display awake too", on: false)
                    divider
                    valueRow("Stop when battery below", value: "20%  ▾")
                }
                section("Deep Sleep") {
                    toggleRow("Deep Sleep on lid close (battery)", on: false)
                    divider
                    Text("Sleep on battery writes memory to disk and powers it off — "
                         + "near-zero drain, wake takes 10–20 s. Changing this asks for "
                         + "an administrator password.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                }
            }
            .padding(20)
        }
        .frame(width: 460, height: 320, alignment: .top)
        .background(Color(white: 0.95))
    }

    private var tabStrip: some View {
        HStack(spacing: 22) {
            tab("General", "gearshape", selected: false)
            tab("Gestures", "hand.point.up.left", selected: false)
            tab("Power", "bolt", selected: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12).padding(.bottom, 8)
        .background(Color(white: 0.98))
    }

    private func tab(_ title: String, _ symbol: String, selected: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: symbol).font(.system(size: 15))
            Text(title).font(.system(size: 11))
        }
        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
    }

    private func section<Content: View>(_ header: String,
                                        @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(header).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 8).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.black.opacity(0.10)))
        }
    }

    private func toggleRow(_ title: String, on: Bool) -> some View {
        HStack {
            Text(title).font(.system(size: 13))
            Spacer()
            switchGlyph(on: on)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }

    private func valueRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 13))
            Spacer()
            Text(value).font(.system(size: 13)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }

    private func switchGlyph(on: Bool) -> some View {
        Capsule()
            .fill(on ? Color.accentColor : Color(white: 0.82))
            .frame(width: 34, height: 20)
            .overlay(Circle().fill(.white).padding(2).offset(x: on ? 7 : -7))
            .overlay(Capsule().strokeBorder(.black.opacity(0.08)))
    }

    private var divider: some View { Divider().padding(.leading, 12) }
}
