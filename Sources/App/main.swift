import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = SystemMonitor()
    private let notes = NotesStore()
    private let luck = LuckStore()
    private let luckOverlay = LuckOverlayController()
    private var panel: PanelController?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerFonts()
        installEditMenu()
        #if DEBUG
        if let directory = Snapshot.outputDirectory { return Snapshot.run(to: directory, monitor: monitor, luck: luck) }
        if let directory = ReadmeArt.outputDirectory { return ReadmeArt.run(to: directory, monitor: monitor) }
        #endif
        let showLuck = { [luck, luckOverlay] in
            let draw = luck.drawToday()
            luckOverlay.show(draw.card, reveal: draw.isNew)
        }
        let panel = PanelController { [monitor, notes, luck] in
            PanelRoot(monitor: monitor, notes: notes, luck: luck, showLuck: showLuck)
        }
        let statusItem = StatusItemController(monitor: monitor, panel: panel)
        monitor.onUpdate = { statusItem.update() }
        StatusItemController.registerLaunchAtLoginOnFirstRun()
        monitor.start()
        self.panel = panel
        self.statusItem = statusItem
        #if DEBUG || PROFILE
        // `--show-panel` opens the panel at launch, for measuring its cost without clicking.
        if CommandLine.arguments.contains("--show-panel") { statusItem.togglePanel() }
        #endif
    }

    /// A menu bar app shows no main menu, but Cmd+C/V/X/A/Z only reach the note field through one.
    private func installEditMenu() {
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem()
        editItem.submenu = edit
        let main = NSMenu()
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private func registerFonts() {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

struct PanelRoot: View {
    let monitor: SystemMonitor
    let notes: NotesStore
    let luck: LuckStore
    let showLuck: () -> Void
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .systemDefault

    var body: some View {
        CyberPanel(monitor: monitor, notes: notes, luck: luck, language: $language, showLuck: showLuck)
            .environment(\.locale, language.locale)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
