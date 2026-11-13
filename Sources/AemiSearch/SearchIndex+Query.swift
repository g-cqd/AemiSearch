#if canImport(Darwin)
    internal import Darwin
#elseif canImport(Glibc)
    internal import Glibc
#endif

/// Searching (BM25, k1 1.2 and b 0.75): each word of the query is a group of terms, itself and, when the query expands, the terms it
/// is part of and its typos at a lower weight; a document's score sums its groups', and one that holds more of the query's words ranks
/// above one that holds fewer. Equal scores rank the newer first.
extension SearchIndex {
    static let k1 = 1.2
    static let b = 0.75

    public func search(_ query: SearchQuery) -> [SearchHit] {
        let words = SearchTokenizer.words(of: query.text)
        let groups = words.map { group(for: $0.word, parts: $0.parts, expands: query.expands) }.filter { !$0.isEmpty }
        guard !groups.isEmpty, count > 0, query.limit > 0 else { return [] }
        let (scores, matched) = accumulate(groups)
        let order = ranked(scores, matched, groups: groups.count, query: query)
        let found = groups.flatMap { $0.map { bytes(of: $0.symbol) } }
        return order.map { number, score in
            SearchHit(
                document: UInt32(number),
                score: score,
                fields: documentFields[number],
                time: times[number],
                snippet: snippet(of: number, around: found)
            )
        }
    }

    /// A word's terms and their weights: itself when the index holds it, its expansions, then an identifier's parts at 0.4.
    private func group(for word: [UInt8], parts: [[UInt8]], expands: Bool) -> [(symbol: UInt32, weight: Double)] {
        var group: [(symbol: UInt32, weight: Double)] = []
        if let exact = symbol(of: word) { group.append((exact, 1)) }
        if expands, word.count >= 3 { group += expansions(of: word) }
        for part in parts {
            if let symbol = symbol(of: part), !group.contains(where: { $0.symbol == symbol }) {
                group.append((symbol, 0.4))
            }
        }
        return group
    }

    /// Each document's score, and which of the groups it matched (the first 64). A word counts once per document: the best of its
    /// terms there, so a document full of a word's near misses does not outrank the one holding the word.
    private func accumulate(_ groups: [[(symbol: UInt32, weight: Double)]]) -> (scores: [Double], matched: [UInt64]) {
        var scores = [Double](repeating: 0, count: count)
        var matched = [UInt64](repeating: 0, count: count)
        var best = [Double](repeating: 0, count: count)
        var touched: [Int] = []
        for (index, group) in groups.enumerated() {
            for (symbol, weight) in group { score(symbol, weight: weight, into: &best, touched: &touched) }
            let bit: UInt64 = index < 64 ? 1 << UInt64(index) : 0
            for number in touched {
                scores[number] += best[number]
                matched[number] |= bit
                best[number] = 0
            }
            touched.removeAll(keepingCapacity: true)
        }
        return (scores, matched)
    }

    /// The BM25 score of the term `symbol` in each of its documents, at `weight`, kept where it beats the word's best so far.
    private func score(_ symbol: UInt32, weight: Double, into best: inout [Double], touched: inout [Int]) {
        let list = postings[Int(symbol)]
        let documents = Double(count)
        let average = Swift.max(1, Double(totalLength) / documents)
        let rarity = log(1 + (documents - Double(list.count) + 0.5) / (Double(list.count) + 0.5))
        for posting in list {
            let number = Int(posting.document)
            let frequency = Double(posting.frequency)
            let norm = 1 - Self.b + Self.b * Double(lengths[number]) / average
            let value = weight * rarity * frequency * (Self.k1 + 1) / (frequency + Self.k1 * norm)
            if best[number] == 0 { touched.append(number) }
            if value > best[number] { best[number] = value }
        }
    }

    /// The best `query.limit` documents that pass its filters, with their final scores.
    private func ranked(
        _ scores: [Double],
        _ matched: [UInt64],
        groups: Int,
        query: SearchQuery
    ) -> [(number: Int, score: Double)] {
        var found: [(number: Int, score: Double)] = []
        for number in 0 ..< count where scores[number] > 0 && passes(number, query) {
            let coverage = Double(matched[number].nonzeroBitCount) / Double(Swift.min(groups, 64))
            found.append((number, scores[number] * (1 + 2 * coverage)))
        }
        found.sort { $0.score != $1.score ? $0.score > $1.score : times[$0.number] > times[$1.number] }
        return Array(found.prefix(query.limit))
    }

    private func passes(_ number: Int, _ query: SearchQuery) -> Bool {
        if let since = query.since, times[number] < since { return false }
        if let until = query.until, times[number] > until { return false }
        let fields = documentFields[number]
        return query.fields.allSatisfy { fields[$0.key] == $0.value }
    }
}
