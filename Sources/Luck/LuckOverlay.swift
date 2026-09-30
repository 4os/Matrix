import AppKit
import Combine
import SwiftUI

/// Full-screen "card of the day": dims the screen, flips a new card open, and shows its reading with a
/// countdown to the next card. Clicking outside the card or pressing Esc closes it.
@MainActor
final class LuckOverlayController {
    private let window: KeyablePanel
    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))

    init() {
        window = KeyablePanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.onCancel = { [weak self] in self?.close() }
    }

    /// `reveal` plays the flip (a card drawn just now); otherwise the card is shown face up.
    func show(_ card: LuckCard, reveal: Bool) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        hostingView.rootView = AnyView(
            LuckOverlay(card: card, reveal: reveal) { [weak self] in self?.close() }
                .environment(\.locale, AppLanguage.current.locale)
                .id(UUID())
        )
        window.setFrame(screen.frame, display: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.orderOut(nil)
        hostingView.rootView = AnyView(EmptyView())
    }
}

struct LuckOverlay: View {
    let card: LuckCard
    let reveal: Bool
    let close: () -> Void

    @State private var angle: Double
    @State private var showsReading: Bool

    init(card: LuckCard, reveal: Bool, close: @escaping () -> Void) {
        self.card = card
        self.reveal = reveal
        self.close = close
        _angle = State(initialValue: reveal ? 0 : 180)
        _showsReading = State(initialValue: !reveal)
    }

    var body: some View {
        VStack(spacing: 26) {
            HStack(spacing: 14) {
                LinearGradient(colors: [.clear, Tarot.gold], startPoint: .leading, endPoint: .trailing).frame(width: 50, height: 1)
                Text("CARD OF THE DAY").font(Tarot.cinzel(13)).tracking(7).foregroundStyle(Tarot.gold)
                LinearGradient(colors: [Tarot.gold, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 50, height: 1)
            }
            FlippingCard(card: card, angle: angle)
                .contentShape(Rectangle())
                .onTapGesture {}
            VStack(spacing: 8) {
                Text(verbatim: card.status)
                    .font(Tarot.cinzel(28)).tracking(1)
                    .foregroundStyle(card.color)
                    .glow(card.color.opacity(0.4), blur: 18)
                Text(verbatim: card.message)
                    .font(Tarot.cormorant(19))
                    .foregroundStyle(Color(hex: 0xe8dcc4))
                    .frame(maxWidth: 340)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("NEW CARD · \(Self.countdown(from: context.date))")
                        .font(Cyber.body(11)).tracking(2).monospacedDigit()
                        .foregroundStyle(Color(hex: 0xa08a5e))
                }
                .padding(.top, 10)
            }
            .multilineTextAlignment(.center)
            .opacity(showsReading ? 1 : 0)
        }
        .padding(.vertical, 60).padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                BehindWindowBlur().opacity(0.6)
                EllipticalGradient(stops: [
                    .init(color: Color(.sRGB, red: 40 / 255, green: 30 / 255, blue: 20 / 255, opacity: 0.55), location: 0),
                    .init(color: .black.opacity(0.88), location: 0.6),
                ], center: UnitPoint(x: 0.5, y: 0.45), endRadiusFraction: 0.72)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: close)
        }
        // The reading and countdown belong to the day the card was drawn.
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in close() }
        .task {
            guard reveal else { return }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.timingCurve(0.2, 0.75, 0.2, 1, duration: 1.2)) { angle = 180 }
            withAnimation(.easeInOut(duration: 0.6).delay(0.7)) { showsReading = true }
        }
    }

    /// Time left until local midnight, "HH:MM:SS".
    static func countdown(from now: Date) -> String {
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        let left = max(0, Int(midnight.timeIntervalSince(now)))
        return String(format: "%02d:%02d:%02d", left / 3600, left / 60 % 60, left % 60)
    }
}

/// Blurs whatever is behind the window (the panel and desktop under the dimmed overlay).
private struct BehindWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
