internal import AemiInterner

/// A full-text index of documents (ask's t209): each term's documents and how often it appears in each (BM25 ranks them), the terms'
/// trigrams (a word also finds the terms it is part of and its typos), and the documents' text, fields and times (filters, snippets).
/// Terms are interned by Aemi's interner under this process's hash key, as text read from anywhere must be.
///
/// One owner: not `Sendable`. ``serialized()`` and ``init(serialized:)`` keep it in a file.
public final class SearchIndex {
    let terms: Interner
    /// By term symbol: the documents holding it, in the order added.
    var postings: [[Posting]] = []
    /// By trigram: the symbols of the terms holding it.
    var gramTerms: [UInt32: [UInt32]] = [:]
    /// By document: its length in terms, its fields and time, and where its text starts in ``text``.
    var lengths: [UInt32] = []
    var documentFields: [[String: String]] = []
    var times: [Int64] = []
    var textStarts: [Int] = [0]
    var text: [UInt8] = []
    var totalLength = 0

    /// How many documents it holds.
    public var count: Int { lengths.count }
    /// How many distinct terms.
    public var termCount: Int { postings.count }

    public init() { terms = Interner(hashing: .keyedForProcess) }

    init(terms: Interner) { self.terms = terms }

    /// Adds `document`; returns its number, the order it was added in.
    @discardableResult
    public func add(_ document: SearchDocument) -> UInt32 {
        let number = UInt32(count)
        let bytes = Array(document.text.utf8)
        var frequencies: [UInt32: UInt32] = [:]
        var length: UInt32 = 0
        SearchTokenizer.forEachTerm(in: bytes[...]) { term, _ in
            frequencies[symbol(interning: term), default: 0] += 1
            length += 1
        }
        for (symbol, frequency) in frequencies {
            postings[Int(symbol)].append(Posting(document: number, frequency: frequency))
        }
        lengths.append(length)
        totalLength += Int(length)
        documentFields.append(document.fields)
        times.append(document.time)
        text.append(contentsOf: bytes)
        textStarts.append(text.count)
        return number
    }

    /// The fields and time of document `number`.
    public func document(_ number: UInt32) -> (fields: [String: String], time: Int64, text: String)? {
        let index = Int(number)
        guard index < count else { return nil }
        return (
            documentFields[index], times[index],
            String(decoding: text[textStarts[index] ..< textStarts[index + 1]], as: UTF8.self)
        )
    }

    /// The symbol of `term`, interned (and given its posting list and trigrams) when new.
    private func symbol(interning term: ArraySlice<UInt8>) -> UInt32 {
        let symbol = term.withUnsafeBytes { unsafe terms.intern($0) }.rawValue
        if Int(symbol) == postings.count {
            postings.append([])
            for gram in Trigrams.of(term) { gramTerms[gram, default: []].append(symbol) }
        }
        return symbol
    }

    /// The symbol of `term`, if the index holds it.
    func symbol(of term: [UInt8]) -> UInt32? {
        term.withUnsafeBytes { unsafe terms.symbol(for: $0) }?.rawValue
    }

    /// The bytes of the term `symbol`.
    func bytes(of symbol: UInt32) -> [UInt8] {
        unsafe terms.withBytes(of: Symbol(rawValue: symbol)) { unsafe Array($0) }
    }

    /// Rebuilds the trigram table from the terms: a snapshot does not keep it.
    func rebuildTrigrams() {
        gramTerms = [:]
        for symbol in 0 ..< UInt32(postings.count) {
            for gram in Trigrams.of(bytes(of: symbol)) { gramTerms[gram, default: []].append(symbol) }
        }
    }
}

/// A term's appearance in a document.
struct Posting: Equatable {
    var document: UInt32
    var frequency: UInt32
}
