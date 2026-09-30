#if DEBUG
import AppKit
import SwiftUI

/// `Matrix --readme-art <dir>` renders the two README images (hero.png, features.png) with live data, then quits.
/// Build with EXCLUDE_LOCAL_ASSETS=YES so no third-party art can end up in them. Debug builds only.
@MainActor
enum ReadmeArt {
    static var outputDirectory: URL? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--readme-art"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1])
    }

    static func run(to directory: URL, monitor: SystemMonitor) {
        let notes = NotesStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "matrix-readme-\(UUID()).json"))
        notes.add("Ship v1.0 to GitHub", date: .now.addingTimeInterval(-5400))
        notes.add("Review the pull request\nbefore standup")
        let luck = starStore()
        monitor.isDetailed = true
        monitor.start()
        Task {
            try? await Task.sleep(for: .seconds(3.2))
            Snapshot.render(Hero(monitor: monitor, notes: notes, luck: luck), to: directory.appending(path: "hero.png"))
            Snapshot.render(Features(), to: directory.appending(path: "features.png"))
            NSApp.terminate(nil)
        }
    }

    /// A store whose card of the day is the Star, so the images are always the same.
    private static func starStore() -> LuckStore {
        while true {
            let store = LuckStore(defaults: UserDefaults(suiteName: "matrix-readme-\(UUID())")!)
            if store.drawToday().card == .star { return store }
        }
    }
}

// MARK: - Shared pieces

private struct ArtBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x020805), Color(hex: 0x03140a)], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Cyber.green.opacity(0.16), .clear], center: UnitPoint(x: 0.72, y: 0.5), startRadius: 0, endRadius: 700)
            Canvas { context, size in
                var y: CGFloat = 0
                while y < size.height {
                    context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(Cyber.green.opacity(0.03)))
                    y += 4
                }
            }
        }
    }
}

private struct Wordmark: View {
    let size: CGFloat

    var body: some View {
        let title = Text(verbatim: "MATRIX").font(Cyber.display(size)).tracking(size * 0.06)
        ZStack {
            title.foregroundStyle(Cyber.cyan.opacity(0.7)).offset(x: -size * 0.05)
            title.foregroundStyle(Cyber.pink.opacity(0.6)).offset(x: size * 0.05)
            title.foregroundStyle(Cyber.green).glow(Cyber.green.opacity(0.45), blur: size * 0.4)
        }
    }
}

private struct Chip: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(Cyber.body(17)).tracking(1.5)
            .foregroundStyle(Cyber.green)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Cyber.green.opacity(0.07))
            .overlay { Slant(inset: 8, leading: true).stroke(Cyber.green.opacity(0.45), lineWidth: 1.5) }
            .clipShape(Slant(inset: 8, leading: true))
    }
}

// MARK: - hero.png

private struct Hero: View {
    let monitor: SystemMonitor
    let notes: NotesStore
    let luck: LuckStore

    var body: some View {
        HStack(alignment: .center, spacing: 70) {
            VStack(alignment: .leading, spacing: 30) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 150, height: 150)
                Wordmark(size: 92)
                Text(verbatim: "A cyberpunk system monitor\nfor your Mac's menu bar.")
                    .font(Cyber.body(32)).foregroundStyle(Cyber.text).lineSpacing(6)
                VStack(alignment: .leading, spacing: 14) {
                    feature("RAM, disk, CPU · GPU · SSD temperatures")
                    feature("Quick notes, one keystroke away")
                    feature("A tarot card of the day")
                    feature("Under 1% CPU while idle")
                }
                HStack(spacing: 10) {
                    Chip(text: "macOS 14+")
                    Chip(text: "APPLE SILICON")
                    Chip(text: "FREE & OPEN SOURCE")
                }
                .padding(.top, 10)
            }
            .frame(width: 720, alignment: .leading)

            VStack(alignment: .trailing, spacing: 10) {
                MenuBarMock(monitor: monitor)
                CyberPanel(monitor: monitor, notes: notes, luck: luck, language: .constant(.en), showLuck: {})
                    .environment(\.locale, AppLanguage.en.locale)
                    .scaleEffect(1.2, anchor: .topTrailing)
                    .frame(width: 432, height: 930, alignment: .topTrailing)
            }
        }
        .padding(.horizontal, 110).padding(.vertical, 70)
        .frame(width: 1760, height: 1150)
        .background(ArtBackground())
    }

    private func feature(_ text: String) -> some View {
        HStack(spacing: 14) {
            Text(verbatim: "▸").foregroundStyle(Cyber.yellow)
            Text(verbatim: text).foregroundStyle(Cyber.textSecondary)
        }
        .font(Cyber.body(23))
    }
}

/// The right end of a dark menu bar with Matrix's item in it, as macOS draws it.
private struct MenuBarMock: View {
    let monitor: SystemMonitor

    var body: some View {
        let ram = monitor.memory.map { Format.percent($0.usedFraction) } ?? "62"
        let cpu = Format.temperature(monitor.thermal.cpu)
        HStack(spacing: 22) {
            HStack(spacing: 7) {
                StatusGlyph().stroke(.white, lineWidth: 1.4).frame(width: 16, height: 16)
                Text(verbatim: "\(ram)% │ \(cpu)°").font(Cyber.body(15))
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text(verbatim: "Wed 30 Sep  14:32")
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 18).padding(.vertical, 8)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// The menu bar icon (rounded square with three bars) as a stroked shape.
private struct StatusGlyph: Shape {
    func path(in r: CGRect) -> Path {
        let s = r.width / 14
        return Path { p in
            p.addRoundedRect(in: r.insetBy(dx: 0.6 * s, dy: 0.6 * s), cornerSize: CGSize(width: 3 * s, height: 3 * s))
            for bar in [CGRect(x: 3, y: 7, width: 1.6, height: 4), CGRect(x: 6.2, y: 4, width: 1.6, height: 7), CGRect(x: 9.4, y: 5.5, width: 1.6, height: 5.5)] {
                p.addRect(CGRect(x: r.minX + bar.minX * s, y: r.minY + bar.minY * s, width: bar.width * s, height: bar.height * s))
            }
        }
    }
}

// MARK: - features.png

private struct Features: View {
    var body: some View {
        HStack(alignment: .center, spacing: 110) {
            VStack(spacing: 26) {
                HStack(spacing: 14) {
                    LinearGradient(colors: [.clear, Tarot.gold], startPoint: .leading, endPoint: .trailing).frame(width: 60, height: 1)
                    Text(verbatim: "CARD OF THE DAY").font(Tarot.cinzel(16)).tracking(7).foregroundStyle(Tarot.gold)
                    LinearGradient(colors: [Tarot.gold, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 60, height: 1)
                }
                TarotFront(card: .star).frame(width: Tarot.size.width, height: Tarot.size.height)
                VStack(spacing: 8) {
                    Text(verbatim: LuckCard.star.status).font(Tarot.cinzel(30)).foregroundStyle(LuckCard.star.color)
                        .glow(LuckCard.star.color.opacity(0.4), blur: 18)
                    Text(verbatim: LuckCard.star.message).font(Tarot.cormorant(21)).foregroundStyle(Color(hex: 0xe8dcc4))
                }
            }
            .environment(\.locale, AppLanguage.en.locale)

            VStack(alignment: .leading, spacing: 34) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(verbatim: "BUILT TO STAY\nOUT OF YOUR WAY").font(Cyber.display(44)).lineSpacing(8)
                        .foregroundStyle(Cyber.green).glow(Cyber.green.opacity(0.35), blur: 16)
                    Text(verbatim: "Measured with Instruments on a MacBook Air M5.")
                        .font(Cyber.body(20)).foregroundStyle(Cyber.textSecondary)
                }
                HStack(spacing: 18) {
                    Stat(value: "~0.5%", label: "CPU WHILE IDLE\n(ONE CORE)", color: Cyber.green)
                    Stat(value: "18 MB", label: "MEMORY", color: Cyber.cyan)
                    Stat(value: "0", label: "NETWORK\nREQUESTS", color: Cyber.yellow)
                }
                VStack(alignment: .leading, spacing: 14) {
                    point("Reads only RAM and CPU temperature while the panel is closed")
                    point("Redraws the menu bar only when a value really changes")
                    point("No background animations, no network, nothing leaves your Mac")
                }
            }
            .frame(width: 720, alignment: .leading)
        }
        .padding(.horizontal, 110).padding(.vertical, 80)
        .frame(width: 1760, height: 1000)
        .background(ArtBackground())
    }

    private func point(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(verbatim: "▸").foregroundStyle(Cyber.yellow)
            Text(verbatim: text).foregroundStyle(Cyber.text)
        }
        .font(Cyber.body(21))
    }
}

private struct Stat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: value).font(Cyber.display(42)).foregroundStyle(color).glow(color.opacity(0.35), blur: 14)
            Text(verbatim: label).font(Cyber.body(15)).tracking(1.5).foregroundStyle(Cyber.textSecondary).lineSpacing(4)
        }
        .padding(22)
        .frame(width: 228, height: 170, alignment: .topLeading)
        .background(color.opacity(0.07))
        .overlay(alignment: .leading) { color.opacity(0.7).frame(width: 3) }
        .clipShape(CutCorners(topRight: 16))
    }
}
#endif
