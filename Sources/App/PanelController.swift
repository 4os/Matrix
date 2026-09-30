import AppKit
import SwiftUI

/// Borderless, transparent panel below the status item. A custom window (rather than `MenuBarExtra`) is needed
/// for the cut-corner shape and the glow, which the system popover chrome would cover.
@MainActor
final class PanelController {
    /// Transparent room around the panel for its glow and drop shadow.
    private static let margin = NSEdgeInsets(top: 0, left: 40, bottom: 60, right: 40)
    /// Gap between the menu bar and the panel.
    private static let gap: CGFloat = 6

    var onVisibilityChange: ((Bool) -> Void)?
    var isVisible: Bool { panel.isVisible }

    private let panel: KeyablePanel
    private let hostingView = SizeTrackingHostingView(rootView: AnyView(EmptyView()))
    private let content: () -> AnyView
    private var anchor: NSRect = .zero
    private var clickMonitor: Any?
    private var marginClickMonitor: Any?

    init<Content: View>(content: @escaping () -> Content) {
        let margin = Self.margin
        self.content = {
            AnyView(content().padding(EdgeInsets(top: margin.top, leading: margin.left, bottom: margin.bottom, trailing: margin.right)))
        }
        panel = KeyablePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.contentView = hostingView
        panel.onCancel = { [weak self] in self?.close() }
        hostingView.onSizeChange = { [weak self] in
            guard let self, self.panel.isVisible else { return }
            self.layout()
        }
    }

    /// `anchor` is the status item button's frame in screen coordinates.
    func toggle(anchor: NSRect) {
        isVisible ? close() : show(anchor: anchor)
    }

    func show(anchor: NSRect) {
        self.anchor = anchor
        hostingView.rootView = content()
        layout()
        panel.makeKeyAndOrderFront(nil)
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
        // The glow around the panel isn't fully transparent, so clicks on it land in our window rather than
        // reaching the global monitor. Treat them as outside clicks.
        marginClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            let window = event.window
            let location = event.locationInWindow
            let inMargin = MainActor.assumeIsolated {
                guard let self, window === self.panel, !self.contentRect.contains(location) else { return false }
                self.close()
                return true
            }
            return inMargin ? nil : event
        }
        onVisibilityChange?(true)
    }

    func close() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        // A hidden hosting view keeps re-rendering on every sample; detaching it keeps the idle app near 0% CPU.
        hostingView.rootView = AnyView(EmptyView())
        for monitor in [clickMonitor, marginClickMonitor].compactMap({ $0 }) { NSEvent.removeMonitor(monitor) }
        clickMonitor = nil
        marginClickMonitor = nil
        onVisibilityChange?(false)
    }

    /// The panel itself, in window coordinates, without the glow margin.
    private var contentRect: NSRect {
        let m = Self.margin
        let bounds = hostingView.bounds
        return NSRect(x: m.left, y: m.bottom, width: bounds.width - m.left - m.right, height: bounds.height - m.top - m.bottom)
    }

    /// Right edge aligned with the status item, top edge `gap` below the menu bar, kept on screen.
    private func layout() {
        let size = hostingView.fittingSize
        let margin = Self.margin
        let screen = NSScreen.screens.first { $0.frame.contains(anchor.origin) } ?? NSScreen.main
        var x = anchor.maxX - size.width + margin.right
        if let visible = screen?.visibleFrame {
            x = min(max(x, visible.minX - margin.left), visible.maxX - size.width + margin.right)
        }
        let top = anchor.minY - Self.gap + margin.top
        panel.setFrame(NSRect(x: x, y: top - size.height, width: size.width, height: size.height), display: true)
    }
}

final class KeyablePanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

private final class SizeTrackingHostingView<Content: View>: NSHostingView<Content> {
    var onSizeChange: (() -> Void)?

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        onSizeChange?()
    }
}
