import SwiftUI

struct CyberPanel: View {
    let monitor: SystemMonitor
    let notes: NotesStore
    let luck: LuckStore
    @Binding var language: AppLanguage
    let showLuck: () -> Void

    private let shape = CutCorners(topRight: 18, bottomLeft: 18)

    var body: some View {
        VStack(spacing: 0) {
            header
            memory
            storage
            temperature
            CyberNotes(notes: notes)
            footer
        }
        .font(Cyber.body(12))
        .foregroundStyle(Cyber.text)
        .frame(width: 360)
        .background { Scanlines().background(Cyber.panel) }
        .overlay(alignment: .topLeading) { accents }
        .clipShape(shape)
        .overlay { shape.stroke(Cyber.green.opacity(0.35), lineWidth: 1) }
        .overlay { cutEdgeHighlights }
        .background {
            // The glow and drop shadow sit on their own static layer, so a changing number inside the panel
            // doesn't re-blur a 440×800 pt area every sample.
            shape.fill(Cyber.panel)
                .glow(Cyber.green.opacity(0.25), blur: 24)
                .glow(Cyber.green.opacity(0.10), blur: 80)
                .shadow(color: .black.opacity(0.6), radius: 30, y: 30)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    ChromaticTitle()
                    Text(verbatim: "SYS.07")
                        .font(Cyber.body(9)).tracking(1.5)
                        .foregroundStyle(Cyber.ink)
                        .padding(EdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 7))
                        .background(Cyber.yellow)
                        .clipShape(Slant(inset: 5))
                        .glow(Cyber.yellow.opacity(0.6), blur: 8)
                }
                HStack(spacing: 8) {
                    Barcode().fill(Cyber.greenLight).frame(width: 34, height: 9).opacity(0.7)
                    Text("\(SystemInfo.chip) · uptime \(Format.uptime(monitor.uptime))")
                        .font(Cyber.body(10)).tracking(1)
                        .foregroundStyle(Cyber.greenLight)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            LuckWidget(luck: luck, action: showLuck)
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 16))
        .bottomDivider(Cyber.green.opacity(0.15))
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                Circle().fill(Cyber.green).frame(width: 7, height: 7)
                    .glow(Cyber.green, blur: 6).glow(Cyber.green, blur: 12)
                Text(verbatim: "ONLINE")
            }
            .font(Cyber.body(10)).tracking(1.5)
            .foregroundStyle(Cyber.green)
            .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 10))
            .background(Cyber.green.opacity(0.06))
            .overlay { Slant(inset: 6, leading: true).stroke(Cyber.green.opacity(0.4), lineWidth: 1) }
            .clipShape(Slant(inset: 6, leading: true))
            Spacer()
            HStack(spacing: 2) {
                CyberChip(title: "TR", isOn: language == .tr) { language = .tr }
                CyberChip(title: "EN", isOn: language == .en) { language = .en }
            }
        }
        .padding(EdgeInsets(top: 10, leading: 22, bottom: 14, trailing: 16))
        .background(Color.black.opacity(0.25))
        .overlay(alignment: .top) { Cyber.green.opacity(0.15).frame(height: 1) }
    }

    // MARK: 01 Memory

    private var memory: some View {
        let reading = monitor.memory
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    CyberSectionTitle(number: "01", title: "MEMORY", color: Cyber.greenLight)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: reading.map { Format.memory($0.used) } ?? "—")
                            .font(Cyber.display(30))
                            .foregroundStyle(Cyber.green)
                            .glow(Cyber.green.opacity(0.3), blur: 12)
                        Text(verbatim: "/ \(reading.map { Format.memoryTotal($0.total) } ?? "—") GB")
                            .font(Cyber.body(12))
                            .foregroundStyle(Cyber.textSecondary)
                    }
                }
                Spacer()
                ZStack {
                    Sparkline(values: monitor.memoryHistory, minimumSpan: 1_073_741_824, closed: true)
                        .fill(Cyber.green.opacity(0.12))
                    Sparkline(values: monitor.memoryHistory, minimumSpan: 1_073_741_824)
                        .stroke(Cyber.green, lineWidth: 1.5)
                        .glow(Cyber.green, blur: 3)
                }
                .frame(width: 130, height: 40)
            }
            AsciiMeter(cells: memoryCells(reading), bracket: Cyber.green.opacity(0.6), size: 16)
            HStack {
                LegendItem(color: Cyber.green, text: "Apps \(reading.map { Format.memory($0.app) } ?? "—")")
                Spacer()
                LegendItem(color: Cyber.greenDark, text: "Wired \(reading.map { Format.memory($0.wired) } ?? "—")")
                Spacer()
                LegendItem(color: Cyber.greenDeep, text: "Compressed \(reading.map { Format.memory($0.compressed) } ?? "—")")
            }
            .font(Cyber.body(10))
            .foregroundStyle(Cyber.textSecondary)
            HStack {
                Text("MEMORY PRESSURE").tracking(1).foregroundStyle(Cyber.greenLight)
                Spacer()
                let pressure = reading?.pressure ?? .normal
                (Text(verbatim: "■ ") + Text(pressure.label))
                    .tracking(1.5)
                    .foregroundStyle(pressure.color)
                    .glow(pressure.color.opacity(0.25), blur: 5)
            }
            .font(Cyber.body(10))
        }
        .sectionPadding()
        .bottomDivider(Cyber.green.opacity(0.1))
    }

    private func memoryCells(_ reading: MemoryReading?) -> [Color?] {
        guard let reading, reading.total > 0 else { return Array(repeating: nil, count: 24) }
        let cells = { (bytes: Double) in Int((bytes / reading.total * 24).rounded()) }
        let app = cells(reading.app), wired = cells(reading.wired), compressed = cells(reading.compressed)
        return (0..<24).map { i in
            i < app ? Cyber.green : i < app + wired ? Cyber.greenDark : i < app + wired + compressed ? Cyber.greenDeep : nil
        }
    }

    // MARK: 02 Storage

    private var storage: some View {
        let disk = monitor.disk
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                CyberSectionTitle(number: "02", title: "STORAGE · \(disk?.name ?? "Macintosh HD")", color: Cyber.cyanLight)
                Spacer()
                (Text(verbatim: "\(disk.map { Format.disk($0.free) } ?? "—") GB").foregroundStyle(Cyber.cyan)
                    + Text(verbatim: " ") + Text("free"))
                    .font(Cyber.body(11))
            }
            AsciiMeter(cells: diskCells(disk), bracket: Cyber.cyan.opacity(0.6), size: 16)
            HStack {
                Text("\(disk.map { Format.disk($0.used) } ?? "—") / \(disk.map { Format.disk($0.total) } ?? "—") GB used")
                Spacer()
                Text(verbatim: "\(disk.map { Format.percent($0.usedFraction) } ?? "—")%")
            }
            .font(Cyber.body(10))
            .foregroundStyle(Cyber.textSecondary)
        }
        .sectionPadding()
        .bottomDivider(Cyber.cyan.opacity(0.1))
    }

    private func diskCells(_ disk: DiskReading?) -> [Color?] {
        let filled = disk.map { Int(($0.usedFraction * 24).rounded()) } ?? 0
        return (0..<24).map { i in i < filled ? (i < filled - 4 ? Cyber.cyanDeep : Cyber.cyan) : nil }
    }

    // MARK: 03 Temperature

    private var temperature: some View {
        let thermal = monitor.thermal
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                CyberSectionTitle(number: "03", title: "TEMPERATURE", color: Cyber.orangeLight)
                Spacer()
                let state = monitor.thermalState
                (Text("THERMAL: ") + Text(state.label))
                    .font(Cyber.body(10)).tracking(1.5)
                    .foregroundStyle(state.color)
                    .glow(state.color.opacity(0.25), blur: 5)
            }
            HStack(spacing: 8) {
                TemperatureCard(label: "CPU", celsius: thermal.cpu)
                TemperatureCard(label: "GPU", celsius: thermal.gpu)
                TemperatureCard(label: "SSD", celsius: thermal.ssd)
            }
            HStack {
                if let rpm = thermal.fanRPM { Text("Fan \(Format.rpm(rpm)) rpm") }
                Spacer()
                Text("Power \(Format.watts(thermal.watts)) W")
            }
            .font(Cyber.body(10))
            .foregroundStyle(Cyber.textSecondary)
        }
        .sectionPadding()
        .bottomDivider(Cyber.orange.opacity(0.1))
    }

    // MARK: Decoration

    private var accents: some View {
        ZStack(alignment: .topLeading) {
            Cyber.yellow.frame(width: 96, height: 3)
                .clipShape(Slant(inset: 3))
                .glow(Cyber.yellow.opacity(0.7), blur: 10)
            Cyber.yellow.frame(width: 3, height: 40)
                .glow(Cyber.yellow.opacity(0.7), blur: 8)
            HStack(spacing: 3) {
                Cyber.cyan.frame(width: 14, height: 3).glow(Cyber.cyan.opacity(0.7), blur: 6)
                Cyber.cyan.opacity(0.6).frame(width: 6, height: 3)
                Cyber.cyan.opacity(0.35).frame(width: 3, height: 3)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 30)
            BottomRightBracket()
                .stroke(Cyber.yellow, lineWidth: 2)
                .frame(width: 14, height: 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .allowsHitTesting(false)
    }

    /// Yellow and cyan highlights along the two cut corners.
    private var cutEdgeHighlights: some View {
        GeometryReader { g in
            Path { p in
                p.move(to: CGPoint(x: g.size.width - 18, y: 0))
                p.addLine(to: CGPoint(x: g.size.width, y: 18))
            }
            .stroke(Cyber.yellow, lineWidth: 1.5)
            .glow(Cyber.yellow.opacity(0.8), blur: 4)
            Path { p in
                p.move(to: CGPoint(x: 0, y: g.size.height - 18))
                p.addLine(to: CGPoint(x: 18, y: g.size.height))
            }
            .stroke(Cyber.cyan, lineWidth: 1.5)
            .glow(Cyber.cyan.opacity(0.8), blur: 4)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 04 Notes

private struct CyberNotes: View {
    @Bindable var notes: NotesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                CyberSectionTitle(number: "04", title: "QUICK NOTE", color: Cyber.greenLight)
                Spacer()
                Text("⏎ save · ⇧⏎ newline").font(Cyber.body(9.5)).foregroundStyle(Cyber.greenDim)
            }
            HStack(alignment: .top, spacing: 6) {
                Text(verbatim: "$")
                    .font(Cyber.body(12)).frame(height: 18)
                    .foregroundStyle(Cyber.green)
                    .glow(Cyber.green.opacity(0.35), blur: 4)
                NoteEditor(
                    text: $notes.draft,
                    font: NSFont(name: "ShareTechMono-Regular", size: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .regular),
                    textColor: NSColor(Cyber.text),
                    caretColor: NSColor(Cyber.green),
                    lineHeight: 18,
                    onSubmit: submit
                )
                .frame(height: 36)
                .overlay(alignment: .topLeading) {
                    if notes.draft.isEmpty {
                        Text("type something...").font(Cyber.body(12)).frame(height: 18)
                            .foregroundStyle(Cyber.greenDim).allowsHitTesting(false)
                    }
                }
            }
            .padding(.vertical, 8).padding(.horizontal, 10)
            .background(Color.black.opacity(0.5))
            .overlay { Rectangle().strokeBorder(Cyber.green.opacity(0.4), lineWidth: 1) }
            .overlay(alignment: .leading) { Cyber.green.frame(width: 3) }
            .clipShape(CutCorners(topRight: 10))

            if notes.notes.isEmpty {
                Text("// no notes yet").font(Cyber.body(10.5)).foregroundStyle(Cyber.greenDim)
                    .padding(.vertical, 4).padding(.horizontal, 2)
            } else {
                CappedScrollView(maxHeight: 132) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(notes.notes) { note in
                            NoteRow(note: note) { notes.remove(note.id) }
                        }
                    }
                }
            }
        }
        .sectionPadding()
    }

    private func submit() {
        notes.add(notes.draft)
        notes.draft = ""
    }

    private struct NoteRow: View {
        let note: Note
        let delete: () -> Void
        @State private var hovering = false
        @State private var hoveringDelete = false

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: Format.time(note.date)).font(Cyber.body(10)).foregroundStyle(Cyber.greenDim)
                Text(verbatim: note.text).font(Cyber.body(11.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Text(verbatim: "✕").font(Cyber.body(11))
                    .foregroundStyle(hoveringDelete ? Cyber.critical : Cyber.greenDim)
                    .onHover { hoveringDelete = $0 }
                    .onTapGesture(perform: delete)
            }
            .lineSpacing(3)
            .padding(.vertical, 6).padding(.horizontal, 8)
            .background(Cyber.green.opacity(hovering ? 0.1 : 0.04), in: RoundedRectangle(cornerRadius: 6))
            .onHover { hovering = $0 }
        }
    }
}

// MARK: - Components

struct CyberSectionTitle: View {
    let number: String
    let title: LocalizedStringKey
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: number)
                .font(Cyber.body(9)).tracking(1)
                .foregroundStyle(Cyber.ink)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(color)
                .clipShape(Slant(inset: 3))
            (Text(verbatim: "// ") + Text(title))
                .font(Cyber.body(10)).tracking(2)
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }
}

/// `[▮▮▮▯▯▯]` fill gauge; a `nil` cell is empty.
/// Gauges here update without animation: an animated change re-renders the whole panel at 60 fps for its duration.
struct AsciiMeter: View {
    let cells: [Color?]
    let bracket: Color
    let size: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Text(verbatim: "[").foregroundStyle(bracket)
            ForEach(cells.indices, id: \.self) { i in
                Spacer(minLength: 0)
                if let color = cells[i] {
                    Text(verbatim: "▮").foregroundStyle(color).glow(color.opacity(0.6), blur: 5)
                } else {
                    Text(verbatim: "▯").foregroundStyle(Cyber.meterOff)
                }
            }
            Spacer(minLength: 0)
            Text(verbatim: "]").foregroundStyle(bracket)
        }
        .font(Cyber.body(size))
    }
}

private struct LegendItem: View {
    let color: Color
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 5) {
            color.frame(width: 6, height: 6)
            Text(text)
        }
    }
}

private struct TemperatureCard: View {
    let label: String
    let celsius: Double?

    var body: some View {
        let celsius = celsius?.rounded()
        let color = Cyber.heat(celsius)
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: label).font(Cyber.body(9.5)).tracking(1.5).foregroundStyle(Cyber.orangeLight)
            Text(verbatim: "\(Format.temperature(celsius))°")
                .font(Cyber.display(21))
                .foregroundStyle(color)
                .glow(color.opacity(0.25), blur: 8)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Cyber.orange.opacity(0.1)
                    color.frame(width: g.size.width * min(1, (celsius ?? 0) / 100))
                        .glow(color, blur: 6)
                }
            }
            .frame(height: 3)
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Cyber.orange.opacity(0.07))
        .overlay(alignment: .leading) { Cyber.orange.opacity(0.6).frame(width: 2) }
        .clipShape(CutCorners(topRight: 10))
    }
}

private struct ChromaticTitle: View {
    var body: some View {
        let title = Text(verbatim: "MATRIX").font(Cyber.display(18)).tracking(1)
        ZStack {
            title.foregroundStyle(Cyber.cyan.opacity(0.7)).offset(x: -1.5)
            title.foregroundStyle(Cyber.pink.opacity(0.6)).offset(x: 1.5)
            title.foregroundStyle(Cyber.green).glow(Cyber.green.opacity(0.35), blur: 10)
        }
    }
}

/// Footer toggle chip: yellow when selected, green outline (filled on hover) otherwise.
private struct CyberChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Text(verbatim: title)
            .font(Cyber.body(9)).tracking(1.5)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(isOn || hovering ? Cyber.ink : Cyber.greenLight)
            .background(isOn ? Cyber.yellow : hovering ? Cyber.green : .clear)
            .overlay { if !isOn { Slant(inset: 4, leading: true).stroke(Cyber.green.opacity(0.3), lineWidth: 1) } }
            .clipShape(Slant(inset: 4, leading: true))
            .contentShape(Rectangle())
            .onHover { hovering = $0 && !isOn }
            .onTapGesture { if !isOn { action() } }
    }
}

/// Repeating 9 px barcode strip next to the device line.
private struct Barcode: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            var x = r.minX
            while x < r.maxX {
                for (start, width) in [(0.0, 1.0), (3, 2), (6, 1)] {
                    p.addRect(CGRect(x: x + start, y: r.minY, width: width, height: r.height))
                }
                x += 9
            }
        }
    }
}

private struct BottomRightBracket: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.maxX - 1, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - 1, y: r.maxY - 1))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY - 1))
        }
    }
}

/// 1 px line every 3 px — the CRT scanline texture.
private struct Scanlines: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(Cyber.green.opacity(0.035)))
                y += 3
            }
        }
    }
}

private extension View {
    func sectionPadding() -> some View {
        padding(.vertical, 14).padding(.horizontal, 16).frame(maxWidth: .infinity, alignment: .leading)
    }
}
