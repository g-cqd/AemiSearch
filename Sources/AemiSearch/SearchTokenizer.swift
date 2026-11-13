/// Splits text into the terms an index holds: runs of ASCII letters, digits and `_`, and of any byte of a non-ASCII character,
/// lowercased. An identifier also yields its parts (`parseHTTPHeader` is `parsehttpheader`, `parse`, `httpheader`; `snake_case` is
/// `snake_case`, `snake`, `case`), so a search finds either. A run longer than ``maximumLength`` (a hash, base64) is no term.
public enum SearchTokenizer {
    /// The longest term kept, in bytes.
    public static let maximumLength = 64

    /// Calls `body` with each term of `text`, in order, a term as often as it appears; `isPart` is true for an identifier's parts.
    public static func forEachTerm(
        in text: ArraySlice<UInt8>,
        _ body: (_ term: ArraySlice<UInt8>, _ isPart: Bool) -> Void
    ) {
        var word: [UInt8] = []
        word.reserveCapacity(maximumLength)
        var parts: [Int] = []
        var previous: UInt8 = 0
        for byte in text {
            if isWordByte(byte) {
                if !word.isEmpty, startsPart(byte, after: previous) { parts.append(word.count) }
                if word.count < maximumLength + 1 { word.append(lowercase(byte)) }
                previous = byte
                continue
            }
            emit(word, parts: parts, body)
            word.removeAll(keepingCapacity: true)
            parts.removeAll(keepingCapacity: true)
            previous = 0
        }
        emit(word, parts: parts, body)
    }

    /// The words of a query, each once, in order, with their parts.
    public static func words(of text: String) -> [(word: [UInt8], parts: [[UInt8]])] {
        var words: [(word: [UInt8], parts: [[UInt8]])] = []
        forEachTerm(in: Array(text.utf8)[...]) { term, isPart in
            let owned = Array(term)
            if isPart, !words.isEmpty {
                if !words[words.count - 1].parts.contains(owned) { words[words.count - 1].parts.append(owned) }
            } else if !isPart, !words.contains(where: { $0.word == owned }) {
                words.append((owned, []))
            }
        }
        return words
    }

    @inline(__always)
    static func isWordByte(_ byte: UInt8) -> Bool {
        byte >= 0x80 || (byte >= 0x30 && byte <= 0x39) || (byte | 0x20 >= 0x61 && byte | 0x20 <= 0x7A) || byte == 0x5F
    }

    @inline(__always)
    static func lowercase(_ byte: UInt8) -> UInt8 { byte >= 0x41 && byte <= 0x5A ? byte | 0x20 : byte }

    /// A part starts at an underscore's next byte, and at an upper-case letter after a lower-case one.
    @inline(__always)
    private static func startsPart(_ byte: UInt8, after previous: UInt8) -> Bool {
        previous == 0x5F || (byte >= 0x41 && byte <= 0x5A && previous >= 0x61 && previous <= 0x7A)
    }

    private static func emit(_ word: [UInt8], parts: [Int], _ body: (ArraySlice<UInt8>, Bool) -> Void) {
        guard !word.isEmpty, word.count <= maximumLength else { return }
        body(word[...], false)
        guard !parts.isEmpty else { return }
        var start = 0
        for end in parts + [word.count] {
            var part = word[start ..< end]
            while part.last == 0x5F { part = part.dropLast() }
            while part.first == 0x5F { part = part.dropFirst() }
            if part.count >= 2 { body(part, true) }
            start = end
        }
    }
}
