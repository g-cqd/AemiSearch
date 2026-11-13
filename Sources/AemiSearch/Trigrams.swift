/// The three-byte windows of a term, packed in a `UInt32`: what a typo or a part of a word shares with the term it means.
enum Trigrams {
    static func of(_ term: some Collection<UInt8>) -> Set<UInt32> {
        let bytes = Array(term)
        guard bytes.count >= 3 else { return [] }
        var grams: Set<UInt32> = []
        for start in 0 ... bytes.count - 3 {
            grams.insert(UInt32(bytes[start]) << 16 | UInt32(bytes[start + 1]) << 8 | UInt32(bytes[start + 2]))
        }
        return grams
    }
}
