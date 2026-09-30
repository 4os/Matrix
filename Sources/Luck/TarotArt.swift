import SwiftUI

/// The picture inside a card's arch window.
struct TarotArt: View {
    let card: LuckCard

    var body: some View {
        GeometryReader { g in
            switch card {
            case .angel:
                if let art = Tarot.angelArt { AngelImage(image: art, size: g.size) } else { AngelArt(size: g.size) }
            case .star: StarArt(size: g.size)
            case .moon: MoonArt(size: g.size)
            case .eye: EyeArt(size: g.size)
            case .blackSun: BlackSunArt(size: g.size)
            }
        }
    }
}

// MARK: - II Star

private struct StarArt: View {
    let size: CGSize

    var body: some View {
        let w = size.width, h = size.height
        let center = CGPoint(x: w / 2, y: h * 0.38)
        ZStack(alignment: .topLeading) {
            EllipticalGradient(stops: [
                .init(color: Color(hex: 0x243b63), location: 0),
                .init(color: Color(hex: 0x0d1830), location: 0.45),
                .init(color: Color(hex: 0x05070f), location: 1),
            ], center: UnitPoint(x: 0.5, y: 0.42), endRadiusFraction: 0.72)

            ForEach(Array(Self.stars.enumerated()), id: \.offset) { _, star in
                Circle().fill(star.2).frame(width: star.3, height: star.3)
                    .position(x: w * star.0, y: h * star.1)
            }
            .opacity(0.85)

            RadialGradient(stops: [
                .init(color: Tarot.goldLight.opacity(0.45), location: 0),
                .init(color: Tarot.goldLight.opacity(0.08), location: 0.4),
                .init(color: .clear, location: 0.68),
            ], center: .center, startRadius: 0, endRadius: 134)
            .frame(width: 190, height: 190)
            .position(center)

            EightPointStar()
                .fill(RadialGradient(stops: [
                    .init(color: Color(hex: 0xfffbea), location: 0),
                    .init(color: Tarot.goldLight, location: 0.45),
                    .init(color: Color(hex: 0xb8873e), location: 1),
                ], center: .center, startRadius: 0, endRadius: 83))
                .frame(width: 118, height: 118)
                .position(center)
            EightPointStar()
                .fill(Color(hex: 0xfffbea).opacity(0.9))
                .frame(width: 54, height: 54)
                .rotationEffect(.degrees(22.5))
                .position(center)

            // Water with the star's reflection.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ZStack {
                    LinearGradient(colors: [Color(hex: 0x0f2240), Color(hex: 0x060b16)], startPoint: .top, endPoint: .bottom)
                    HorizontalLines(spacing: 7).fill(Tarot.goldLight.opacity(0.28))
                        .mask(EllipticalGradient(colors: [.black, .clear], center: .top, endRadiusFraction: 0.55))
                }
                .frame(height: h * 0.26)
            }
        }
        .frame(width: w, height: h)
    }

    /// x, y (fractions), color, diameter
    private static let stars: [(CGFloat, CGFloat, Color, CGFloat)] = [
        (0.18, 0.22, .white, 2.4), (0.78, 0.16, .white, 2), (0.66, 0.34, Color(hex: 0xf3e6c0), 2.8), (0.30, 0.48, .white, 2),
        (0.86, 0.52, .white, 2), (0.12, 0.60, Color(hex: 0xf3e6c0), 2.4), (0.48, 0.12, .white, 2), (0.58, 0.58, .white, 2),
    ]
}

private struct EightPointStar: Shape {
    private static let points: [(CGFloat, CGFloat)] = [
        (0.5, 0), (0.565, 0.343), (0.854, 0.146), (0.657, 0.435), (1, 0.5), (0.657, 0.565), (0.854, 0.854), (0.565, 0.657),
        (0.5, 1), (0.435, 0.657), (0.146, 0.854), (0.343, 0.565), (0, 0.5), (0.343, 0.435), (0.146, 0.146), (0.435, 0.343),
    ]

    func path(in r: CGRect) -> Path {
        Path { p in
            p.addLines(Self.points.map { CGPoint(x: r.minX + $0.0 * r.width, y: r.minY + $0.1 * r.height) })
            p.closeSubpath()
        }
    }
}

private struct HorizontalLines: Shape {
    let spacing: CGFloat

    func path(in r: CGRect) -> Path {
        Path { p in
            var y = r.minY
            while y < r.maxY {
                p.addRect(CGRect(x: r.minX, y: y, width: r.width, height: 1))
                y += spacing
            }
        }
    }
}

// MARK: - III Moon

private struct MoonArt: View {
    let size: CGSize

    var body: some View {
        let w = size.width, h = size.height
        let moon = CGPoint(x: w / 2, y: h * 0.32)
        let pale = Color(hex: 0xe8e6ee)
        ZStack(alignment: .topLeading) {
            LinearGradient(stops: [
                .init(color: Color(hex: 0x2c2d42), location: 0),
                .init(color: Color(hex: 0x1a1b29), location: 0.55),
                .init(color: Color(hex: 0x0b0b12), location: 1),
            ], startPoint: .top, endPoint: .bottom)

            RadialGradient(colors: [Color(hex: 0xd6dde8, opacity: 0.28), .clear], center: .center, startRadius: 0, endRadius: 78)
                .frame(width: 170, height: 170)
                .position(moon)

            Crescent()
                .fill(pale)
                .frame(width: 116, height: 92)
                .position(moon)
                .glow(pale.opacity(0.6), blur: 10)

            fog(y: h * 0.56 + 7, height: 14, opacity: 0.12, blur: 6)
            fog(y: h * 0.66 + 5, height: 10, opacity: 0.10, blur: 5)

            pillar(x: w * 0.14 + 15, fill: LinearGradient(colors: [Color(hex: 0x08080c), Color(hex: 0x1a1a24)], startPoint: .leading, endPoint: .trailing), cap: Color(hex: 0x08080c))
            pillar(x: w * 0.86 - 15, fill: LinearGradient(colors: [Color(hex: 0xb9b6c4), pale], startPoint: .leading, endPoint: .trailing), cap: pale)

            LinearGradient(colors: [.clear, Color(hex: 0xd6dde8, opacity: 0.18)], startPoint: .top, endPoint: .bottom)
                .frame(width: w, height: h * 0.12)
                .position(x: w / 2, y: h * 0.94)
        }
        .frame(width: w, height: h)
    }

    private func fog(y: CGFloat, height: CGFloat, opacity: Double, blur: CGFloat) -> some View {
        Color(hex: 0xd6dde8, opacity: opacity)
            .frame(width: size.width, height: height)
            .blur(radius: blur)
            .position(x: size.width / 2, y: y)
    }

    /// A 30 pt column rising 48% of the height with a gold-edged capital.
    private func pillar(x: CGFloat, fill: LinearGradient, cap: Color) -> some View {
        let height = size.height * 0.48
        return VStack(spacing: 0) {
            cap.frame(width: 40, height: 8).overlay(alignment: .bottom) { Tarot.gold.frame(height: 1) }
            fill.frame(width: 30, height: height).overlay(alignment: .top) { Tarot.gold.frame(height: 3) }
        }
        .position(x: x, y: size.height - (height + 8) / 2)
    }
}

/// Right-facing crescent: a 92 pt disc 24 pt to the right, minus the disc it came from.
private struct Crescent: Shape {
    func path(in r: CGRect) -> Path {
        let d = r.height
        let lit = Path(ellipseIn: CGRect(x: r.maxX - d, y: r.minY, width: d, height: d))
        let shadow = Path(ellipseIn: CGRect(x: r.minX, y: r.minY, width: d, height: d))
        return lit.subtracting(shadow)
    }
}

// MARK: - IV Eye

private struct EyeArt: View {
    let size: CGSize

    var body: some View {
        let w = size.width, h = size.height
        let center = CGPoint(x: w / 2, y: h * 0.46)
        let rays = Color(hex: 0xe59a5e, opacity: 0.35)
        ZStack(alignment: .topLeading) {
            RadialGradient(stops: [
                .init(color: Color(hex: 0x4a220e), location: 0),
                .init(color: Color(hex: 0x1c0c06), location: 0.5),
                .init(color: Color(hex: 0x0a0504), location: 1),
            ], center: UnitPoint(x: 0.5, y: 0.46), startRadius: 0, endRadius: farthestCorner(from: UnitPoint(x: 0.5, y: 0.46), in: size))

            Rays(count: 24, width: .degrees(3))
                .fill(rays)
                .mask(RadialGradient(stops: [
                    .init(color: .clear, location: 0.22),
                    .init(color: .black, location: 0.26),
                    .init(color: .clear, location: 0.62),
                ], center: .center, startRadius: 0, endRadius: 212))
                .frame(width: 300, height: 300)
                .position(center)

            Almond()
                .fill(RadialGradient(stops: [
                    .init(color: Color(hex: 0xf4e2c8), location: 0),
                    .init(color: Color(hex: 0xd9b98f), location: 0.7),
                ], center: .center, startRadius: 0, endRadius: 68))
                .overlay { Almond().stroke(Tarot.gold, lineWidth: 4).clipShape(Almond()) }
                .frame(width: 96, height: 96)
                .rotationEffect(.degrees(45))
                .glow(Color(hex: 0xe59a5e, opacity: 0.7), blur: 24)
                .position(center)

            Circle()
                .fill(RadialGradient(stops: [
                    .init(color: Color(hex: 0xffb46e), location: 0),
                    .init(color: Color(hex: 0xe0602a), location: 0.45),
                    .init(color: Color(hex: 0x5a2008), location: 1),
                ], center: .center, startRadius: 0, endRadius: 33))
                .frame(width: 46, height: 46)
                .glow(Color(hex: 0xff8c3c, opacity: 0.8), blur: 12)
                .position(center)
            Ellipse().fill(Color(hex: 0x0a0504)).frame(width: 7, height: 32).position(center)

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    Tarot.gold.frame(width: 4, height: 4).rotationEffect(.degrees(45))
                }
            }
            .position(x: w / 2, y: h * 0.9 - 2)
        }
        .frame(width: w, height: h)
    }
}

/// Square with the top-right and bottom-left corners rounded at 80% (CSS `border-radius: 0 80%`).
private struct Almond: Shape {
    func path(in r: CGRect) -> Path {
        let radius = r.width * 0.8
        return Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - radius, y: r.minY))
            p.addArc(center: CGPoint(x: r.maxX - radius, y: r.minY + radius), radius: radius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + radius, y: r.maxY))
            p.addArc(center: CGPoint(x: r.minX + radius, y: r.maxY - radius), radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            p.closeSubpath()
        }
    }
}

private struct Rays: Shape {
    let count: Int
    let width: Angle

    func path(in r: CGRect) -> Path {
        let center = CGPoint(x: r.midX, y: r.midY)
        let radius = max(r.width, r.height)
        return Path { p in
            for i in 0..<count {
                let start = Angle.degrees(Double(i) * 360 / Double(count) - 90)
                p.move(to: center)
                p.addArc(center: center, radius: radius, startAngle: start, endAngle: start + width, clockwise: false)
                p.closeSubpath()
            }
        }
    }
}

// MARK: - V Black sun

private struct BlackSunArt: View {
    let size: CGSize

    var body: some View {
        let w = size.width, h = size.height
        let center = CGPoint(x: w / 2, y: h * 0.36)
        let rose = Color(hex: 0xd77a92)
        ZStack(alignment: .topLeading) {
            RadialGradient(stops: [
                .init(color: Color(hex: 0x4a0f20), location: 0),
                .init(color: Color(hex: 0x1d0610), location: 0.5),
                .init(color: Color(hex: 0x070205), location: 1),
            ], center: UnitPoint(x: 0.5, y: 0.36), startRadius: 0, endRadius: farthestCorner(from: UnitPoint(x: 0.5, y: 0.36), in: size))

            RadialGradient(stops: [
                .init(color: .clear, location: 0.30),
                .init(color: rose.opacity(0.95), location: 0.32),
                .init(color: rose.opacity(0.35), location: 0.38),
                .init(color: rose.opacity(0.08), location: 0.52),
                .init(color: .clear, location: 0.66),
            ], center: .center, startRadius: 0, endRadius: 155)
            .frame(width: 220, height: 220)
            .position(center)

            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x1a0a0e), Color(hex: 0x030102)], center: UnitPoint(x: 0.4, y: 0.38), startRadius: 0, endRadius: 58))
                .overlay { Circle().strokeBorder(rose.opacity(0.8), lineWidth: 1) }
                .frame(width: 96, height: 96)
                .position(center)

            // Slanted light shafts below the eclipse.
            SlantedLines(spacing: 17, slope: 0.18)
                .fill(rose.opacity(0.18))
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                .frame(width: w, height: h * 0.42)
                .position(x: w / 2, y: h * 0.79)

            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(width: w, height: h * 0.18)
                .position(x: w / 2, y: h * 0.91)

            Mountains()
                .fill(Color(hex: 0x050203))
                .frame(width: w, height: 30)
                .position(x: w / 2, y: h * 0.88 - 15)
        }
        .frame(width: w, height: h)
    }
}

private struct SlantedLines: Shape {
    let spacing: CGFloat
    /// Horizontal shift per point of height.
    let slope: CGFloat

    func path(in r: CGRect) -> Path {
        Path { p in
            var x = r.minX - r.height * slope
            while x < r.maxX {
                p.move(to: CGPoint(x: x + r.height * slope, y: r.minY))
                p.addLine(to: CGPoint(x: x + r.height * slope + 1, y: r.minY))
                p.addLine(to: CGPoint(x: x + 1, y: r.maxY))
                p.addLine(to: CGPoint(x: x, y: r.maxY))
                p.closeSubpath()
                x += spacing
            }
        }
    }
}

private struct Mountains: Shape {
    private static let ridge: [(CGFloat, CGFloat)] = [
        (0, 1), (0, 0.6), (0.12, 0.4), (0.22, 0.62), (0.34, 0.3), (0.46, 0.55), (0.58, 0.2), (0.70, 0.58),
        (0.82, 0.36), (0.92, 0.6), (1, 0.45), (1, 1),
    ]

    func path(in r: CGRect) -> Path {
        Path { p in
            p.addLines(Self.ridge.map { CGPoint(x: r.minX + $0.0 * r.width, y: r.minY + $0.1 * r.height) })
            p.closeSubpath()
        }
    }
}

// MARK: - I Angel (drawn stand-in when the illustration isn't bundled)

private struct AngelArt: View {
    let size: CGSize

    var body: some View {
        let w = size.width, h = size.height
        let center = CGPoint(x: w / 2, y: h * 0.4)
        ZStack(alignment: .topLeading) {
            RadialGradient(stops: [
                .init(color: Color(hex: 0x4a4030), location: 0),
                .init(color: Color(hex: 0x1d1a16), location: 0.5),
                .init(color: Color(hex: 0x0c0a10), location: 1),
            ], center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: farthestCorner(from: UnitPoint(x: 0.5, y: 0.4), in: size))

            RadialGradient(colors: [Tarot.goldLight.opacity(0.5), .clear], center: .center, startRadius: 0, endRadius: 110)
                .frame(width: 220, height: 220)
                .position(center)

            ForEach([-1.0, 1.0], id: \.self) { side in
                Wing()
                    .fill(LinearGradient(colors: [Color(hex: 0xfffbea).opacity(0.9), Tarot.gold.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 80, height: 130)
                    .scaleEffect(x: side, y: 1)
                    .position(x: center.x + side * 44, y: center.y + 20)
            }

            Ellipse()
                .stroke(Tarot.goldLight, lineWidth: 2.5)
                .frame(width: 54, height: 16)
                .glow(Tarot.goldLight, blur: 14)
                .position(x: center.x, y: center.y - 44)
        }
        .frame(width: w, height: h)
    }
}

/// Five overlapping feathers fanning out from the wing's root on the left.
private struct Wing: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        for i in 0..<5 {
            let t = CGFloat(i) / 4
            let tip = CGPoint(x: r.minX + r.width * (1 - t * 0.35), y: r.minY + r.height * t * 0.85)
            var feather = Path()
            feather.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.35))
            feather.addQuadCurve(to: tip, control: CGPoint(x: r.minX + r.width * 0.55, y: r.minY + r.height * (t * 0.85 - 0.2)))
            feather.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.45), control: CGPoint(x: r.minX + r.width * 0.6, y: r.minY + r.height * (t * 0.85 + 0.15)))
            feather.closeSubpath()
            path.addPath(feather)
        }
        return path
    }
}
