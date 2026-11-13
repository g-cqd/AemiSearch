/// Writes a snapshot's numbers little-endian, and byte strings with their length first.
struct SnapshotWriter {
    var bytes: [UInt8] = []

    mutating func write(_ value: UInt32) {
        for shift in stride(from: 0, to: 32, by: 8) { bytes.append(UInt8(truncatingIfNeeded: value >> UInt32(shift))) }
    }

    mutating func write(_ value: UInt64) {
        for shift in stride(from: 0, to: 64, by: 8) { bytes.append(UInt8(truncatingIfNeeded: value >> UInt64(shift))) }
    }

    mutating func write(bytes more: some Collection<UInt8>) {
        write(UInt64(more.count))
        bytes.append(contentsOf: more)
    }

    mutating func write(_ text: String) { write(bytes: Array(text.utf8)) }
}
