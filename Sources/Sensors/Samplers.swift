import Foundation

// MARK: - Memory

enum MemoryPressure: Equatable {
    case normal, warning, critical
}

struct MemoryReading: Equatable {
    /// All sizes in bytes.
    var total: Double
    var app: Double
    var wired: Double
    var compressed: Double
    var pressure: MemoryPressure

    var used: Double { app + wired + compressed }
    var usedFraction: Double { total > 0 ? used / total : 0 }
}

/// Same breakdown as Activity Monitor: App = internal − purgeable, Wired, Compressed.
struct MemorySampler {
    private let host = mach_host_self()
    private let pageSize = Double(getpagesize())

    func sample() -> MemoryReading? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }
        let appPages = Double(stats.internal_page_count) - Double(stats.purgeable_count)
        return MemoryReading(
            total: Double(ProcessInfo.processInfo.physicalMemory),
            app: max(0, appPages) * pageSize,
            wired: Double(stats.wire_count) * pageSize,
            compressed: Double(stats.compressor_page_count) * pageSize,
            pressure: Self.pressure()
        )
    }

    /// Kernel pressure level, the same signal Activity Monitor's pressure graph uses: 1 normal, 2 warn, 4 critical.
    private static func pressure() -> MemoryPressure {
        switch sysctlInt32("kern.memorystatus_vm_pressure_level") {
        case 4: .critical
        case 2: .warning
        default: .normal
        }
    }
}

// MARK: - Disk

struct DiskReading: Equatable {
    var name: String
    /// Bytes.
    var total: Double
    var free: Double

    var used: Double { total - free }
    var usedFraction: Double { total > 0 ? used / total : 0 }
}

enum DiskSampler {
    static func sample() -> DiskReading? {
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let free = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return DiskReading(name: values.volumeName ?? "Macintosh HD", total: Double(total), free: Double(free))
    }
}

// MARK: - Thermal (SMC)

struct ThermalReading: Equatable {
    /// °C
    var cpu: Double?
    var gpu: Double?
    var ssd: Double?
    var watts: Double?
    var fanRPM: Double?
}

/// Reads Apple Silicon SMC sensors. CPU = performance (Tp*) + efficiency (Te*) cores, GPU = Tg*,
/// SSD = NAND (TH0x), power = total system power (PSTR). Fanless Macs report no fans.
final class ThermalSampler {
    private let smc: SMC?
    private let cpuKeys: [String]
    private let gpuKeys: [String]
    private let hasFan: Bool

    init() {
        let smc = SMC()
        let floatKeys = smc?.allKeys().filter { smc?.float($0) != nil } ?? []
        self.smc = smc
        cpuKeys = floatKeys.filter { $0.hasPrefix("Tp") || $0.hasPrefix("Te") }
        gpuKeys = floatKeys.filter { $0.hasPrefix("Tg") }
        hasFan = (smc?.uint32("FNum") ?? 0) > 0
    }

    /// Without `detailed`, only the CPU temperature (shown in the menu bar) is read.
    func sample(detailed: Bool) -> ThermalReading {
        guard let smc else { return ThermalReading() }
        guard detailed else { return ThermalReading(cpu: average(cpuKeys)) }
        return ThermalReading(
            cpu: average(cpuKeys),
            gpu: average(gpuKeys),
            ssd: smc.float("TH0x").flatMap(Self.plausible),
            watts: smc.float("PSTR").flatMap { $0 > 0 ? $0 : nil },
            fanRPM: hasFan ? smc.float("F0Ac") : nil
        )
    }

    /// Unused sensor slots read 0, so only plausible die temperatures are averaged.
    private func average(_ keys: [String]) -> Double? {
        let values = keys.compactMap { smc?.float($0).flatMap(Self.plausible) }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    private static func plausible(_ celsius: Double) -> Double? {
        (1...150).contains(celsius) ? celsius : nil
    }
}

// MARK: - System info

enum SystemInfo {
    /// "Apple M5" → "M5"
    static let chip: String = {
        let brand = sysctlString("machdep.cpu.brand_string") ?? "Mac"
        return brand.hasPrefix("Apple ") ? String(brand.dropFirst(6)) : brand
    }()

    static func uptime(now: Date = .now) -> TimeInterval {
        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &boot, &size, nil, 0) == 0 else { return 0 }
        return now.timeIntervalSince1970 - Double(boot.tv_sec)
    }
}

private func sysctlInt32(_ name: String) -> Int32? {
    var value: Int32 = 0
    var size = MemoryLayout<Int32>.size
    return sysctlbyname(name, &value, &size, nil, 0) == 0 ? value : nil
}

private func sysctlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
    var buffer = [UInt8](repeating: 0, count: size)
    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
    return String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
}
