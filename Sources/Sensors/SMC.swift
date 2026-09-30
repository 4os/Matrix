import IOKit

/// Minimal read-only client for the AppleSMC user client. Reading needs no root and no sandbox exceptions.
///
/// The kernel expects the 80-byte `SMCKeyData_t` C struct. Swift doesn't guarantee C layout for nested
/// structs, so the buffer is built by hand at the C offsets.
final class SMC {
    private enum Offset {
        static let key = 0
        static let dataSize = 28
        static let dataType = 32
        static let result = 40
        static let command = 42
        static let data32 = 44
        static let bytes = 48
    }
    private enum Command: UInt8 {
        case readKey = 5
        case keyAtIndex = 8
        case keyInfo = 9
    }
    private struct KeyInfo {
        let size: UInt32
        let type: String
    }

    private var connection: io_connect_t = 0
    private var infoCache: [UInt32: KeyInfo] = [:]

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, task_self_trap(), 0, &connection) == KERN_SUCCESS else { return nil }
    }

    deinit { IOServiceClose(connection) }

    /// Every key the SMC exposes (a few thousand on Apple Silicon).
    func allKeys() -> [String] {
        guard let count = uint32("#KEY") else { return [] }
        return (0..<count).compactMap { index in
            var input = request(key: 0, command: .keyAtIndex)
            put(index, at: Offset.data32, in: &input)
            guard let output = call(input) else { return nil }
            return Self.string(from: load(UInt32.self, at: Offset.key, in: output))
        }
    }

    /// Value of a key stored as a little-endian `flt ` (the format Apple Silicon uses for sensors).
    func float(_ key: String) -> Double? {
        guard let (info, bytes) = read(key), info.type == "flt ", bytes.count == 4 else { return nil }
        return Double(bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) })
    }

    func uint32(_ key: String) -> UInt32? {
        guard let (info, bytes) = read(key) else { return nil }
        switch info.type {
        case "ui8 ": return UInt32(bytes[0])
        case "ui16": return UInt32(bytes.withUnsafeBytes { UInt16(bigEndian: $0.loadUnaligned(as: UInt16.self)) })
        case "ui32": return bytes.withUnsafeBytes { UInt32(bigEndian: $0.loadUnaligned(as: UInt32.self)) }
        default: return nil
        }
    }

    private func read(_ name: String) -> (KeyInfo, [UInt8])? {
        let key = Self.fourCC(name)
        guard let info = info(key) else { return nil }
        var input = request(key: key, command: .readKey)
        put(info.size, at: Offset.dataSize, in: &input)
        guard let output = call(input) else { return nil }
        let end = Offset.bytes + min(Int(info.size), 32)
        return (info, Array(output[Offset.bytes..<end]))
    }

    private func info(_ key: UInt32) -> KeyInfo? {
        if let cached = infoCache[key] { return cached }
        guard let output = call(request(key: key, command: .keyInfo)) else { return nil }
        let info = KeyInfo(
            size: load(UInt32.self, at: Offset.dataSize, in: output),
            type: Self.string(from: load(UInt32.self, at: Offset.dataType, in: output))
        )
        infoCache[key] = info
        return info
    }

    private func request(key: UInt32, command: Command) -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: 80)
        put(key, at: Offset.key, in: &buffer)
        buffer[Offset.command] = command.rawValue
        return buffer
    }

    private func call(_ input: [UInt8]) -> [UInt8]? {
        var output = [UInt8](repeating: 0, count: 80)
        var outputSize = output.count
        let status = input.withUnsafeBytes { inputPtr in
            IOConnectCallStructMethod(connection, 2, inputPtr.baseAddress, input.count, &output, &outputSize)
        }
        guard status == KERN_SUCCESS, output[Offset.result] == 0 else { return nil }
        return output
    }

    private func put(_ value: UInt32, at offset: Int, in buffer: inout [UInt8]) {
        withUnsafeBytes(of: value) { buffer.replaceSubrange(offset..<offset + 4, with: $0) }
    }

    private func load<T>(_: T.Type, at offset: Int, in buffer: [UInt8]) -> T {
        buffer.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: T.self) }
    }

    static func fourCC(_ s: String) -> UInt32 {
        s.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    static func string(from code: UInt32) -> String {
        String(decoding: [24, 16, 8, 0].map { UInt8((code >> $0) & 0xff) }, as: UTF8.self)
    }
}
