internal import AemiKernel

/// The part of a document's text a hit shows: about 200 bytes around the first term found, cut on character boundaries, its lines
/// joined, `…` where it was cut.
extension SearchIndex {
    static let snippetBefore = 60
    static let snippetAfter = 140

    func snippet(of number: Int, around terms: [[UInt8]]) -> String {
        let base = textStarts[number]
        let whole = text[base ..< textStarts[number + 1]]
        let lower = whole.map(SearchTokenizer.lowercase)
        var first: Int?
        for term in terms {
            if let range = ByteSearch.firstRange(of: term, in: lower[...]) {
                first = Swift.min(first ?? range.lowerBound, range.lowerBound)
            }
        }
        let center = first ?? 0
        var start = Swift.max(0, center - Self.snippetBefore)
        var end = Swift.min(lower.count, center + Self.snippetAfter)
        while start > 0, lower[start] & 0xC0 == 0x80 { start -= 1 }
        while end < lower.count, lower[end] & 0xC0 == 0x80 { end += 1 }
        let shown = String(decoding: whole[(base + start) ..< (base + end)], as: UTF8.self)
            .split(whereSeparator: \.isNewline).joined(separator: " ")
        return (start > 0 ? "…" : "") + shown + (end < lower.count ? "…" : "")
    }
}
