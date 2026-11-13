internal import AemiInterner

/// The index as bytes, to keep in a file (encrypted by its owner when the documents are): a magic and version, the interned terms,
/// each term's postings, then each document's length, time, fields and text. The trigram table is rebuilt on reading. Reading checks
/// every count and number against the rest, so damaged bytes are refused, never trusted.
extension SearchIndex {
    static let magic: [UInt8] = Array("AESI".utf8)
    static let version: UInt32 = 1

    public func serialized() -> [UInt8] {
        var writer = SnapshotWriter()
        writer.bytes = Self.magic
        writer.write(Self.version)
        writer.write(bytes: terms.serialized())
        writer.write(UInt64(postings.count))
        for list in postings {
            writer.write(UInt64(list.count))
            for posting in list {
                writer.write(posting.document)
                writer.write(posting.frequency)
            }
        }
        writer.write(UInt64(count))
        for number in 0 ..< count { writeDocument(number, to: &writer) }
        return writer.bytes
    }

    private func writeDocument(_ number: Int, to writer: inout SnapshotWriter) {
        writer.write(lengths[number])
        writer.write(UInt64(bitPattern: times[number]))
        let fields = documentFields[number].sorted { $0.key < $1.key }
        writer.write(UInt64(fields.count))
        for (key, value) in fields {
            writer.write(key)
            writer.write(value)
        }
        writer.write(bytes: text[textStarts[number] ..< textStarts[number + 1]])
    }

    public convenience init(serialized bytes: [UInt8]) throws(SearchFormatError) {
        guard bytes.starts(with: Self.magic) else { throw .notAnIndex }
        var reader = SnapshotReader(bytes: bytes, offset: Self.magic.count)
        guard try reader.readUInt32() == Self.version else { throw .notAnIndex }
        let interned: Interner
        do { interned = try Interner(serialized: Array(try reader.readBytes()), hashing: .keyedForProcess) } catch {
            throw .inconsistent("the terms")
        }
        self.init(terms: interned)
        let termCount = try reader.readCount(unit: 8)
        guard termCount == interned.count else {
            throw .inconsistent("\(termCount) posting lists for \(interned.count) terms")
        }
        postings = []
        postings.reserveCapacity(termCount)
        for _ in 0 ..< termCount { postings.append(try Self.readPostings(&reader)) }
        let documents = try reader.readCount(unit: 28)
        for _ in 0 ..< documents { try readDocument(&reader) }
        guard reader.atEnd else { throw .inconsistent("bytes after the last document") }
        guard postings.allSatisfy({ $0.allSatisfy { Int($0.document) < documents } }) else {
            throw .inconsistent("a posting names a document the index does not hold")
        }
        rebuildTrigrams()
    }

    private static func readPostings(_ reader: inout SnapshotReader) throws(SearchFormatError) -> [Posting] {
        let count = try reader.readCount(unit: 8)
        var list: [Posting] = []
        list.reserveCapacity(count)
        for _ in 0 ..< count {
            list.append(Posting(document: try reader.readUInt32(), frequency: try reader.readUInt32()))
        }
        return list
    }

    private func readDocument(_ reader: inout SnapshotReader) throws(SearchFormatError) {
        let length = try reader.readUInt32()
        let time = Int64(bitPattern: try reader.readUInt64())
        var fields: [String: String] = [:]
        for _ in 0 ..< (try reader.readCount(unit: 16)) {
            let key = try reader.readString()
            fields[key] = try reader.readString()
        }
        let bytes = try reader.readBytes()
        lengths.append(length)
        totalLength += Int(length)
        times.append(time)
        documentFields.append(fields)
        text.append(contentsOf: bytes)
        textStarts.append(text.count)
    }
}
