/// Reads what ``SnapshotWriter`` wrote, refusing anything that would read past the end.
struct SnapshotReader {
    let bytes: [UInt8]
    var offset = 0

    var atEnd: Bool { offset == bytes.count }

    mutating func readUInt32() throws(SearchFormatError) -> UInt32 {
        guard bytes.count - offset >= 4 else { throw .truncated }
        var value: UInt32 = 0
        for index in 0 ..< 4 { value |= UInt32(bytes[offset + index]) << UInt32(index * 8) }
        offset += 4
        return value
    }

    mutating func readUInt64() throws(SearchFormatError) -> UInt64 {
        guard bytes.count - offset >= 8 else { throw .truncated }
        var value: UInt64 = 0
        for index in 0 ..< 8 { value |= UInt64(bytes[offset + index]) << UInt64(index * 8) }
        offset += 8
        return value
    }

    /// A count that must fit in what is left, `unit` bytes each.
    mutating func readCount(unit: Int) throws(SearchFormatError) -> Int {
        let count = try readUInt64()
        guard count <= UInt64(bytes.count - offset) / UInt64(Swift.max(1, unit)) else { throw .truncated }
        return Int(count)
    }

    mutating func readBytes() throws(SearchFormatError) -> ArraySlice<UInt8> {
        let count = try readCount(unit: 1)
        defer { offset += count }
        return bytes[offset ..< offset + count]
    }

    mutating func readString() throws(SearchFormatError) -> String {
        String(decoding: try readBytes(), as: UTF8.self)
    }
}
