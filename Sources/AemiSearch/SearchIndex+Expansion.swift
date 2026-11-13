internal import AemiKernel
internal import AemiText

/// What a word also finds (ask's t209): the terms it is part of (`cache` finds `cachekey`; a prefix weighs more than a middle; both less than the word) and the
/// terms one edit away (two for words of five bytes or more), through the trigrams they share. At most ``limit`` terms per word, the
/// closest first, so a short, common word does not pull in the whole vocabulary.
extension SearchIndex {
    static let expansionLimit = 32
    static let candidateLimit = 400

    func expansions(of word: [UInt8]) -> [(symbol: UInt32, weight: Double)] {
        let grams = Trigrams.of(word)
        var shared: [UInt32: Int] = [:]
        for gram in grams {
            for symbol in gramTerms[gram] ?? [] { shared[symbol, default: 0] += 1 }
        }
        let needed = Swift.max(1, grams.count - 2)
        let candidates = shared.filter { $0.value >= needed }
            .map { (symbol: $0.key, shared: $0.value, length: postings.isEmpty ? 0 : bytes(of: $0.key).count) }
            .sorted { $0.shared != $1.shared ? $0.shared > $1.shared : $0.length < $1.length }
            .prefix(Self.candidateLimit)
        var found: [(symbol: UInt32, weight: Double)] = []
        let edits = word.count >= 5 ? 2 : 1
        for candidate in candidates where found.count < Self.expansionLimit {
            if let weight = weight(of: bytes(of: candidate.symbol), for: word, edits: edits) {
                found.append((candidate.symbol, weight))
            }
        }
        return found
    }

    /// How much `term` counts for `word`: a term that starts with it 0.6, holds it 0.45, is a typo of it 0.4; nil otherwise.
    private func weight(of term: [UInt8], for word: [UInt8], edits: Int) -> Double? {
        guard term != word else { return nil }
        if term.count > word.count {
            if term.starts(with: word) { return 0.6 }
            if ByteSearch.firstRange(of: word, in: term[...]) != nil { return 0.45 }
        }
        guard abs(term.count - word.count) <= edits else { return nil }
        return AemiText.editDistance(word, term, maxDistance: edits) <= edits ? 0.4 : nil
    }
}
