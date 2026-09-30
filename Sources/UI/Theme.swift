import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: opacity
        )
    }
}

/// Neon palette (design README §5).
enum Cyber {
    static let green = Color(hex: 0x39ff88)
    static let greenLight = Color(hex: 0x4fd488)
    static let greenDim = Color(hex: 0x3a9e63)
    static let greenDark = Color(hex: 0x1fbf66)
    static let greenDeep = Color(hex: 0x0f7a40)
    static let cyan = Color(hex: 0x3ff0ff)
    static let cyanLight = Color(hex: 0x8af5ff)
    static let cyanDeep = Color(hex: 0x1fb8c9)
    static let orange = Color(hex: 0xff7a3d)
    static let orangeLight = Color(hex: 0xffb08a)
    static let yellow = Color(hex: 0xffc247)
    static let pink = Color(hex: 0xff3b6b)
    static let text = Color(hex: 0xb6ffd2)
    static let textSecondary = Color(hex: 0x7fdca4)
    static let warning = Color(hex: 0xe6ff4d)
    static let critical = Color(hex: 0xff5c7a)
    static let ink = Color(hex: 0x0a0a00)
    static let panel = Color(.sRGB, red: 1 / 255, green: 12 / 255, blue: 5 / 255, opacity: 0.9)
    static let meterOff = Color(hex: 0xb6ffd2, opacity: 0.22)

    static func body(_ size: CGFloat) -> Font { .custom("ShareTechMono-Regular", fixedSize: size) }
    static func display(_ size: CGFloat) -> Font { .custom("Orbitron-Medium", fixedSize: size) }

    /// Temperature color: theme accent below 65°, yellow up to 80°, red above.
    static func heat(_ celsius: Double?) -> Color {
        guard let celsius else { return orange }
        return celsius < 65 ? orange : celsius < 80 ? warning : critical
    }
}

extension MemoryPressure {
    var label: LocalizedStringKey {
        switch self {
        case .normal: "NORMAL"
        case .warning: "WARNING"
        case .critical: "CRITICAL"
        }
    }

    var color: Color {
        switch self {
        case .normal: Cyber.green
        case .warning: Cyber.warning
        case .critical: Cyber.critical
        }
    }
}

extension ProcessInfo.ThermalState {
    var label: LocalizedStringKey {
        switch self {
        case .nominal: "NOMINAL"
        case .fair: "MODERATE"
        default: "HIGH"
        }
    }

    var color: Color {
        switch self {
        case .nominal: Cyber.green
        case .fair: Cyber.warning
        default: Cyber.critical
        }
    }
}

// MARK: - Shapes

/// Rectangle with the top-right and bottom-left corners cut at 45°.
struct CutCorners: Shape {
    var topRight: CGFloat
    var bottomLeft: CGFloat = 0

    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - topRight, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + topRight))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + bottomLeft, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY - bottomLeft))
            p.closeSubpath()
        }
    }
}

/// Tag shape: the bottom-right corner is slanted by `inset`; `leading` also slants the top-left (parallelogram).
struct Slant: Shape {
    var inset: CGFloat
    var leading = false

    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX + (leading ? inset : 0), y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - inset, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }
}

/// RAM history line. Values are normalised to a padded min/max window so small changes stay visible.
struct Sparkline: Shape {
    var values: [Double]
    var minimumSpan: Double
    var closed = false

    func path(in r: CGRect) -> Path {
        guard values.count > 1, let lo = values.min(), let hi = values.max() else { return Path() }
        let span = max(hi - lo, minimumSpan) * 1.3
        let floor = (lo + hi) / 2 - span / 2
        let step = r.width / CGFloat(values.count - 1)
        let points = values.enumerated().map { i, v in
            CGPoint(x: r.minX + CGFloat(i) * step, y: r.maxY - CGFloat((v - floor) / span) * r.height)
        }
        return Path { p in
            p.addLines(points)
            if closed {
                p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
                p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
                p.closeSubpath()
            }
        }
    }
}

// MARK: - Formatting

enum Format {
    private static let gib = 1_073_741_824.0

    /// Memory in GiB with one decimal, as Activity Monitor shows it.
    static func memory(_ bytes: Double) -> String { String(format: "%.1f", bytes / gib) }
    static func memoryTotal(_ bytes: Double) -> String { String(Int((bytes / gib).rounded())) }
    /// Disk in decimal GB, as Finder shows it.
    static func disk(_ bytes: Double) -> String { String(Int((bytes / 1e9).rounded())) }
    static func percent(_ fraction: Double) -> String { String(Int((fraction * 100).rounded())) }
    static func temperature(_ celsius: Double?) -> String { celsius.map { String(Int($0.rounded())) } ?? "—" }
    static func watts(_ watts: Double?) -> String { watts.map { String(format: "%.1f", $0) } ?? "—" }
    static func rpm(_ rpm: Double) -> String { Int(rpm.rounded()).formatted(.number.locale(AppLanguage.current.locale)) }

    /// Always 24-hour "HH:mm", whatever the region's clock setting.
    static func time(_ date: Date) -> String {
        date.formatted(.verbatim(
            "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
            timeZone: .current, calendar: .current
        ))
    }

    /// "3d 14h", "5h 12m" or "42m" (localized).
    static func uptime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let (days, hours, mins) = (minutes / 1440, minutes / 60 % 24, minutes % 60)
        if days > 0 { return localized("\(days)d \(hours)h") }
        if hours > 0 { return localized("\(hours)h \(mins)m") }
        return localized("\(mins)m")
    }
}

// MARK: - Helpers

extension View {
    /// CSS-style `0 0 <blur> color` glow. SwiftUI's shadow radius is roughly half a CSS blur.
    func glow(_ color: Color, blur: CGFloat) -> some View {
        shadow(color: color, radius: blur / 2)
    }

    func bottomDivider(_ color: Color) -> some View {
        overlay(alignment: .bottom) { color.frame(height: 1) }
    }
}

/// Scroll view that grows with its content up to `maxHeight`.
struct CappedScrollView<Content: View>: View {
    var maxHeight: CGFloat
    @ViewBuilder var content: Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            content.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollIndicators(.never)
        .frame(height: min(contentHeight, maxHeight))
    }
}
