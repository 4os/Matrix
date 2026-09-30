#if DEBUG
import AppKit
import SwiftUI

/// `Matrix --snapshot <dir>` renders the panel, every tarot card and the card overlay with live data to PNGs,
/// then quits. Used to check layout without Screen Recording permission. Debug builds only.
@MainActor
enum Snapshot {
    static var outputDirectory: URL? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1])
    }

    static func run(to directory: URL, monitor: SystemMonitor, luck: LuckStore) {
        let notes = NotesStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "matrix-snapshot-\(UUID()).json"))
        notes.add("Faturayı öde", date: .now.addingTimeInterval(-3600))
        notes.add("PR'ı gözden geçir\nikinci satır")
        let pending = LuckStore(defaults: UserDefaults(suiteName: "matrix-snapshot-\(UUID())")!)
        let drawn = LuckStore(defaults: UserDefaults(suiteName: "matrix-snapshot-\(UUID())")!)
        _ = drawn.drawToday()
        monitor.isDetailed = true
        monitor.start()
        Task {
            // Two samples so the disk and history are populated.
            try? await Task.sleep(for: .seconds(3.2))
            let background = Color(hex: 0x0b1f14)
            for (suffix, store) in [("", pending), ("-drawn", drawn)] {
                let panel = CyberPanel(monitor: monitor, notes: notes, luck: store, language: .constant(.current), showLuck: {})
                render(panel.environment(\.locale, AppLanguage.current.locale).padding(40).background(background), to: directory.appending(path: "panel\(suffix).png"))
            }
            let cards = HStack(spacing: 40) {
                TarotBack().frame(width: Tarot.size.width, height: Tarot.size.height)
                ForEach(LuckCard.allCases, id: \.self) { TarotFront(card: $0).frame(width: Tarot.size.width, height: Tarot.size.height) }
            }
            render(cards.padding(60).background(Color.black), to: directory.appending(path: "cards.png"))
            let overlay = LuckOverlay(card: drawn.card() ?? .star, reveal: false) {}
                .environment(\.locale, AppLanguage.current.locale)
                .frame(width: 900, height: 900)
                .background(background)
            render(overlay, to: directory.appending(path: "overlay.png"))
            NSApp.terminate(nil)
        }
    }

    static func render(_ view: some View, to url: URL) {
        let host = NSHostingView(rootView: view)
        host.frame.size = host.fittingSize
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        host.display()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
