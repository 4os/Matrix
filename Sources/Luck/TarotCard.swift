import AppKit
import SwiftUI

enum Tarot {
    static let gold = Color(hex: 0xd9b574)
    static let goldLight = Color(hex: 0xf3d98a)
    static let parchment = Color(hex: 0xf3dfb0)
    static let ink = Color(hex: 0x0d0b16)
    static let size = CGSize(width: 260, height: 430)

    static func cinzel(_ size: CGFloat) -> Font { .custom("CinzelRoman-Bold", fixedSize: size) }
    static func cormorant(_ size: CGFloat) -> Font { .custom("CormorantGaramond-Italic", fixedSize: size) }
    static func cormorantSemibold(_ size: CGFloat) -> Font { .custom("CormorantGaramond-SemiBoldItalic", fixedSize: size) }

    /// The angel illustration isn't in the public repo (third-party art); without it a drawn card is used.
    static let angelArt: NSImage? = Bundle.main.url(forResource: "tarot-art", withExtension: "jpg").flatMap(NSImage.init(contentsOf:))
}

// MARK: - Flip

/// Card that turns around the Y axis: the back shows up to 90°, the front after.
struct FlippingCard: View, Animatable {
    let card: LuckCard
    var angle: Double

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        Group {
            if angle < 90 {
                TarotBack()
            } else {
                TarotFront(card: card).rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .frame(width: Tarot.size.width, height: Tarot.size.height)
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
    }
}

// MARK: - Faces

struct TarotBack: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        ZStack {
            Circle().strokeBorder(Tarot.gold.opacity(0.6), lineWidth: 1).frame(width: 150, height: 150)
            Rectangle().strokeBorder(Tarot.gold, lineWidth: 1).frame(width: 96, height: 96).rotationEffect(.degrees(45))
            Circle().strokeBorder(Tarot.gold, lineWidth: 1).frame(width: 34, height: 34)
            Circle().fill(Tarot.goldLight).frame(width: 8, height: 8).glow(Tarot.goldLight, blur: 12)
            CornerStars(inset: 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RadialGradient(stops: [
            .init(color: Color(hex: 0x2b2342), location: 0),
            .init(color: Color(hex: 0x120f1d), location: 0.55),
            .init(color: Color(hex: 0x07060b), location: 1),
        ], center: UnitPoint(x: 0.5, y: 0.45), startRadius: 0, endRadius: 250))
        .overlay { shape.strokeBorder(Tarot.gold, lineWidth: 1.5) }
        .overlay { shape.inset(by: 1.5).strokeBorder(Tarot.ink, lineWidth: 7.5) }
        .overlay { shape.inset(by: 9).strokeBorder(Tarot.gold.opacity(0.6), lineWidth: 1) }
        .clipShape(shape)
        .glow(Tarot.gold.opacity(0.25), blur: 40)
        .shadow(color: .black.opacity(0.7), radius: 30, y: 30)
    }
}

struct TarotFront: View {
    let card: LuckCard

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                GoldRule(fadesLeft: true)
                Text(verbatim: card.numeral).font(Tarot.cinzel(18)).tracking(2).foregroundStyle(Tarot.goldLight)
                GoldRule(fadesLeft: false)
            }
            TarotArt(card: card)
                .clipShape(ArchShape())
                .overlay { ArchShape().strokeBorder(Tarot.gold, lineWidth: 1) }
                .overlay { ArchShape().inset(by: 1).strokeBorder(Color(hex: 0x0c0a10), lineWidth: 3) }
                .overlay { ArchShape().inset(by: 4).strokeBorder(Tarot.gold.opacity(0.5), lineWidth: 1) }
                .overlay {
                    EllipticalGradient(stops: [
                        .init(color: .clear, location: 0.45),
                        .init(color: Color(hex: 0x08060a, opacity: 0.75), location: 1),
                    ], center: UnitPoint(x: 0.5, y: 0.4), endRadiusFraction: 0.72)
                    .clipShape(ArchShape())
                    .allowsHitTesting(false)
                }
            HStack(spacing: 10) {
                Text(verbatim: "◆").font(.system(size: 7)).foregroundStyle(Tarot.gold)
                Text(verbatim: card.name).font(Tarot.cinzel(16)).tracking(4).foregroundStyle(Tarot.parchment).lineLimit(1)
                Text(verbatim: "◆").font(.system(size: 7)).foregroundStyle(Tarot.gold)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 12, bottom: 14, trailing: 12))
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Tarot.gold.opacity(0.7), lineWidth: 1) }
        .overlay { CornerStars(inset: 5) }
        .padding(12)
        .background(LinearGradient(colors: [Color(hex: 0x17131d), Color(hex: 0x0c0a10)], startPoint: .top, endPoint: .bottom))
        .overlay { shape.strokeBorder(Tarot.gold, lineWidth: 1.5) }
        .clipShape(shape)
        .glow(card.color.opacity(0.33), blur: 50)
        .shadow(color: .black.opacity(0.7), radius: 30, y: 30)
    }
}

private struct GoldRule: View {
    let fadesLeft: Bool

    var body: some View {
        LinearGradient(colors: fadesLeft ? [.clear, Tarot.gold] : [Tarot.gold, .clear], startPoint: .leading, endPoint: .trailing)
            .frame(width: 34, height: 1)
    }
}

private struct CornerStars: View {
    let inset: CGFloat

    var body: some View {
        ZStack {
            star.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            star.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            star.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            star.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .padding(inset)
        .allowsHitTesting(false)
    }

    private var star: some View {
        Text(verbatim: "✦").font(.system(size: 10)).foregroundStyle(Tarot.gold)
    }
}

/// Picture window: semicircular top, slightly rounded bottom corners.
struct ArchShape: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let top = min(r.width / 2, 105)
        let bottom = max(0, 4 - inset)
        return Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY + top))
            p.addArc(center: CGPoint(x: r.minX + top, y: r.minY + top), radius: top, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.addLine(to: CGPoint(x: r.maxX - top, y: r.minY))
            p.addArc(center: CGPoint(x: r.maxX - top, y: r.minY + top), radius: top, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - bottom))
            p.addArc(center: CGPoint(x: r.maxX - bottom, y: r.maxY - bottom), radius: bottom, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: CGPoint(x: r.minX + bottom, y: r.maxY))
            p.addArc(center: CGPoint(x: r.minX + bottom, y: r.maxY - bottom), radius: bottom, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            p.closeSubpath()
        }
    }

    func inset(by amount: CGFloat) -> ArchShape { ArchShape(inset: inset + amount) }
}

// MARK: - Mini card (panel header)

/// "DAILY LUCK / Draw your card" plus a 30×46 card: the back until today's card is drawn, then its thumbnail.
struct LuckWidget: View {
    let luck: LuckStore
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let card = luck.card()
        HStack(spacing: 10) {
            VStack(alignment: .trailing, spacing: 3) {
                Text("DAILY LUCK").font(Tarot.cinzel(9)).tracking(2)
                    .foregroundStyle(Tarot.gold)
                Group {
                    if let card { Text(verbatim: card.shortTitle) } else { Text("Draw your card") }
                }
                .font(Tarot.cormorantSemibold(12.5))
                .foregroundStyle(Tarot.parchment)
                .lineLimit(1)
            }
            if let card {
                CardThumbnail(card: card)
                    .frame(width: 30, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(Tarot.gold, lineWidth: 1) }
                    .overlay {
                        RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.8), lineWidth: 6).blur(radius: 3)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .glow(card.color.opacity(0.4), blur: 10)
                    .shadow(color: .black.opacity(0.6), radius: 5, y: 4)
            } else {
                MiniBack(highlighted: hovering)
                    .rotationEffect(.degrees(hovering ? 0 : 7))
                    .offset(y: hovering ? -2 : 0)
                    .animation(.easeOut(duration: 0.25), value: hovering)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: action)
    }
}

private struct MiniBack: View {
    let highlighted: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 3)
        let edge = highlighted ? Tarot.goldLight : Tarot.gold
        ZStack {
            Rectangle().strokeBorder(Tarot.gold, lineWidth: 1).frame(width: 11, height: 11).rotationEffect(.degrees(45))
            Circle().fill(Tarot.goldLight).frame(width: 3, height: 3).glow(Tarot.goldLight, blur: 4)
        }
        .frame(width: 30, height: 46)
        .background(RadialGradient(colors: [Color(hex: 0x2b2342), Tarot.ink], center: UnitPoint(x: 0.5, y: 0.45), startRadius: 0, endRadius: 20))
        .overlay { shape.strokeBorder(edge, lineWidth: 1) }
        .overlay { shape.inset(by: 3).strokeBorder(edge.opacity(highlighted ? 0.7 : 0.55), lineWidth: 0.6) }
        .clipShape(shape)
        .glow(edge.opacity(highlighted ? 0.6 : 0.4), blur: highlighted ? 20 : 12)
        .shadow(color: .black.opacity(0.6), radius: highlighted ? 7 : 5, y: highlighted ? 6 : 4)
    }
}

/// Small picture of a card: the art's centre as a hard-edged radial dot.
private struct CardThumbnail: View {
    let card: LuckCard

    var body: some View {
        GeometryReader { g in
            if card == .angel, let art = Tarot.angelArt {
                AngelImage(image: art, size: g.size)
            } else {
                let spec = thumbnail
                let radius = farthestCorner(from: spec.center, in: g.size)
                RadialGradient(
                    stops: spec.stops.map { .init(color: $0.0, location: $0.1 < 0 ? -$0.1 : $0.1 / radius) },
                    center: spec.center, startRadius: 0, endRadius: radius
                )
            }
        }
    }

    /// Positive locations are points from the centre, negative ones fractions of the radius.
    private var thumbnail: (center: UnitPoint, stops: [(Color, CGFloat)]) {
        switch card {
        case .angel:
            (UnitPoint(x: 0.5, y: 0.4), [(Tarot.goldLight, 0), (Tarot.goldLight, 4), (Color(hex: 0x3a3020), 5), (Color(hex: 0x0c0a10), -0.8)])
        case .star:
            (UnitPoint(x: 0.5, y: 0.4), [(Tarot.goldLight, 0), (Tarot.goldLight, 3), (Color(hex: 0x243b63), 4), (Color(hex: 0x05070f), -0.8)])
        case .moon:
            (UnitPoint(x: 0.5, y: 0.38), [(Color(hex: 0xe8e6ee), 0), (Color(hex: 0xe8e6ee), 4), (Color(hex: 0x2c2d42), 5), (Color(hex: 0x0b0b12), -0.8)])
        case .eye:
            (UnitPoint(x: 0.5, y: 0.46), [(Color(hex: 0xe0602a), 0), (Color(hex: 0xe0602a), 4), (Color(hex: 0x4a220e), 5), (Color(hex: 0x0a0504), -0.8)])
        case .blackSun:
            (UnitPoint(x: 0.5, y: 0.36), [(Color(hex: 0x030102), 0), (Color(hex: 0x030102), 5), (Color(hex: 0xd77a92), 6), (Color(hex: 0x4a0f20), 8), (Color(hex: 0x070205), -0.8)])
        }
    }
}

func farthestCorner(from center: UnitPoint, in size: CGSize) -> CGFloat {
    let x = max(center.x, 1 - center.x) * size.width
    let y = max(center.y, 1 - center.y) * size.height
    return (x * x + y * y).squareRoot()
}

/// The illustration scaled to 125% of the box height and positioned at 52% / 42%, like CSS `background-position`.
struct AngelImage: View {
    let image: NSImage
    let size: CGSize

    var body: some View {
        let height = size.height * 1.25
        let width = height * image.size.width / max(image.size.height, 1)
        Image(nsImage: image)
            .resizable()
            .frame(width: width, height: height)
            .offset(x: (size.width - width) * 0.52, y: (size.height - height) * 0.42)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
    }
}
