import AppKit
import ServiceManagement

/// Menu bar item: icon + `62% │ 58°` (RAM usage and CPU temperature), drawn in the system menu bar color
/// like Apple's own items. Left click toggles the panel, right click opens the app menu.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let monitor: SystemMonitor
    private let panel: PanelController
    private var shownRAM = Hysteresis()
    private var shownCPU = Hysteresis()

    init(monitor: SystemMonitor, panel: PanelController) {
        self.monitor = monitor
        self.panel = panel
        super.init()
        guard let button = item.button else { return }
        button.image = Self.icon()
        button.imagePosition = .imageLeading
        button.font = NSFont(name: "ShareTechMono-Regular", size: 11.5) ?? .monospacedSystemFont(ofSize: 11.5, weight: .regular)
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        panel.onVisibilityChange = { [weak self] visible in
            self?.item.button?.highlight(visible)
            monitor.isDetailed = visible
        }
        update()
    }

    func update() {
        // Redrawing the menu bar is the app's main idle cost, so the shown values only move once the reading
        // is a full point away. Without this the CPU average flickers by a degree nearly every sample.
        let ram = shownRAM.update(monitor.memory.map { $0.usedFraction * 100 }).map { "\($0)%" } ?? "—"
        let cpu = shownCPU.update(monitor.thermal.cpu).map { "\($0)°" } ?? "—°"
        let title = " \(ram) │ \(cpu)"
        guard let button = item.button, button.title != title else { return }
        button.title = title
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            togglePanel()
        }
    }

    func togglePanel() {
        guard let button = item.button, let window = button.window else { return }
        panel.toggle(anchor: window.convertToScreen(button.convert(button.bounds, to: nil)))
    }

    private func showMenu() {
        panel.close()
        let menu = NSMenu()
        let login = NSMenuItem(title: localized("Launch at Login"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: localized("Quit Matrix"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    /// Turns on Launch at Login the first time the installed app runs. Only once, so switching it off from the
    /// menu sticks, and only from /Applications, so development builds never register themselves.
    static func registerLaunchAtLoginOnFirstRun(defaults: UserDefaults = .standard) {
        let key = "didRegisterLaunchAtLogin"
        guard !defaults.bool(forKey: key), Bundle.main.bundlePath.hasPrefix("/Applications/") else { return }
        do {
            try SMAppService.mainApp.register()
            defaults.set(true, forKey: key)
        } catch {
            NSLog("Matrix: launch at login failed: \(error)")
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Matrix: launch at login failed: \(error)")
        }
    }

    /// Rounded square with three bars. A template image, so the system tints it like its own icons.
    private static func icon() -> NSImage {
        let image = NSImage(size: NSSize(width: 14, height: 14), flipped: true) { _ in
            NSColor.black.set()
            let frame = NSBezierPath(roundedRect: NSRect(x: 0.6, y: 0.6, width: 12.8, height: 12.8), xRadius: 3, yRadius: 3)
            frame.lineWidth = 1.2
            frame.stroke()
            for bar in [NSRect(x: 3, y: 7, width: 1.6, height: 4), NSRect(x: 6.2, y: 4, width: 1.6, height: 7), NSRect(x: 9.4, y: 5.5, width: 1.6, height: 5.5)] {
                bar.fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// A whole-number reading that changes only when the raw value moves at least 1 away from what's shown.
struct Hysteresis {
    private(set) var shown: Int?

    mutating func update(_ value: Double?) -> Int? {
        guard let value else { shown = nil; return nil }
        if let current = shown, abs(value - Double(current)) < 1 { return current }
        shown = Int(value.rounded())
        return shown
    }
}
