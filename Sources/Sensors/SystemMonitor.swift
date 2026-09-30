import Foundation
import Observation

/// Samples the sensors on a fixed interval and publishes the latest values to the UI. While the panel is closed
/// only what the menu bar shows (RAM and CPU temperature) is read.
@MainActor @Observable
final class SystemMonitor {
    static let interval: Duration = .milliseconds(1500)
    /// ~45 s of RAM history at the default interval.
    static let historyLength = 30

    private(set) var memory: MemoryReading?
    /// Used RAM in bytes, oldest first.
    private(set) var memoryHistory: [Double] = []
    private(set) var disk: DiskReading?
    private(set) var thermal = ThermalReading()
    private(set) var thermalState = ProcessInfo.processInfo.thermalState
    /// Whole minutes: the panel shows no finer unit, and a per-second change would re-render the header.
    private(set) var uptime: TimeInterval = 0

    @ObservationIgnored var onUpdate: (() -> Void)?
    /// Set while the panel is visible: also reads GPU/SSD/power/fan and the disk. Turning it on samples at once.
    @ObservationIgnored var isDetailed = false {
        didSet { if isDetailed && !oldValue { sample(refreshDisk: true) } }
    }
    @ObservationIgnored private let memorySampler = MemorySampler()
    @ObservationIgnored private let thermalSampler = ThermalSampler()
    @ObservationIgnored private var tick = 0

    func start() {
        Task { [weak self] in
            while let self {
                self.sample()
                // The tolerance lets macOS coalesce this wake-up with others.
                try? await Task.sleep(for: Self.interval, tolerance: .milliseconds(300))
            }
        }
    }

    private func sample(refreshDisk: Bool = false) {
        // Assigning an unchanged value still invalidates every view that reads it, hence the comparisons.
        if let reading = memorySampler.sample() {
            if memory != reading { memory = reading }
            if memoryHistory.isEmpty {
                memoryHistory = Array(repeating: reading.used, count: Self.historyLength)
            } else {
                memoryHistory = memoryHistory.dropFirst() + [reading.used]
            }
        }
        // Free space barely moves, and the "important usage" query (~20–40 ms) is the most expensive read:
        // once when the panel opens, then about once a minute while it stays open.
        if isDetailed && (refreshDisk || tick % 40 == 0) {
            let reading = DiskSampler.sample()
            if disk != reading { disk = reading }
        }
        let thermalReading = thermalSampler.sample(detailed: isDetailed)
        if thermal != thermalReading { thermal = thermalReading }
        let state = ProcessInfo.processInfo.thermalState
        if thermalState != state { thermalState = state }
        let minutes = (SystemInfo.uptime() / 60).rounded(.down) * 60
        if uptime != minutes { uptime = minutes }
        tick += 1
        onUpdate?()
    }
}
