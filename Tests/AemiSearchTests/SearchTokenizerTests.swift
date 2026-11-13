import Testing

@testable import AemiSearch

@Suite("Terms are words, lowercased, and identifiers' parts")
struct SearchTokenizerTests {
    private func terms(_ text: String) -> [String] {
        var found: [String] = []
        SearchTokenizer.forEachTerm(in: Array(text.utf8)[...]) { term, _ in
            found.append(String(decoding: term, as: UTF8.self))
        }
        return found
    }

    @Test func `words split on anything but letters, digits and underscores, lowercased`() {
        #expect(terms("Hello, world! v2.0 x-y") == ["hello", "world", "v2", "0", "x", "y"])
    }

    @Test func `an identifier also gives its parts`() {
        #expect(terms("parseHTTPHeader") == ["parsehttpheader", "parse", "httpheader"])
        #expect(terms("snake_case_name") == ["snake_case_name", "snake", "case", "name"])
        #expect(terms("_private") == ["_private", "private"])
    }

    @Test func `non-ASCII stays inside a word, and an overlong run is no term`() {
        #expect(terms("café crème") == ["café", "crème"])
        #expect(terms(String(repeating: "a", count: 65) + " ok") == ["ok"])
    }
}
