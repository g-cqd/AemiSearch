import Testing

@testable import AemiSearch

@Suite("BM25 search with typos, parts of words, filters and snippets")
struct SearchIndexTests {
    private func index() -> SearchIndex {
        let index = SearchIndex()
        index.add(
            SearchDocument(
                text: "The cache key is the request's URL and its headers.",
                fields: ["kind": "reply"],
                time: 10
            )
        )
        index.add(
            SearchDocument(
                text: "Fixed the flaky test in CacheKeyTests by sorting headers.",
                fields: ["kind": "reply"],
                time: 20
            )
        )
        index.add(
            SearchDocument(
                text: "error: no such file or directory: Package.resolved",
                fields: ["kind": "tool"],
                time: 30
            )
        )
        index.add(SearchDocument(text: "Lunch is at noon.", fields: ["kind": "user"], time: 40))
        return index
    }

    @Test func `a document with every word ranks above one with some, and the rarest word counts most`() {
        let hits = index().search(SearchQuery("cache key headers", expands: false))
        #expect(hits.first?.document == 0)
        #expect(hits.map(\.document).contains(1))
        #expect(!hits.map(\.document).contains(3))
    }

    @Test func `a word finds the identifiers it is part of, and its typos`() {
        let index = index()
        #expect(index.search(SearchQuery("cachekey")).map(\.document).contains(1))
        #expect(index.search(SearchQuery("resolvd")).first?.document == 2)
        #expect(index.search(SearchQuery("directry")).first?.document == 2)
        #expect(index.search(SearchQuery("resolvd", expands: false)).isEmpty)
    }

    @Test func `fields and times filter, and the limit holds`() {
        let index = index()
        #expect(index.search(SearchQuery("headers", fields: ["kind": "tool"])).isEmpty)
        #expect(index.search(SearchQuery("headers", since: 15)).map(\.document) == [1])
        #expect(index.search(SearchQuery("headers", until: 15)).map(\.document) == [0])
        #expect(index.search(SearchQuery("headers", limit: 1)).count == 1)
        #expect(index.search(SearchQuery("")).isEmpty)
    }

    @Test func `the snippet shows the text around the first word found`() throws {
        let index = SearchIndex()
        index.add(
            SearchDocument(
                text: String(repeating: "filler ", count: 30) + "the needle is here\nand more "
                    + String(repeating: "x ", count: 100)
            )
        )
        let hit = try #require(index.search(SearchQuery("needle")).first)
        #expect(hit.snippet.hasPrefix("…") && hit.snippet.hasSuffix("…"))
        #expect(hit.snippet.contains("the needle is here and more"))
    }

    @Test func `a snapshot reads back the same index, and damaged bytes are refused`() throws {
        let original = index()
        let bytes = original.serialized()
        let copy = try SearchIndex(serialized: bytes)
        #expect(copy.count == original.count && copy.termCount == original.termCount)
        for query in ["cache key headers", "resolvd", "noon"] {
            #expect(copy.search(SearchQuery(query)) == original.search(SearchQuery(query)))
        }
        #expect(throws: SearchFormatError.notAnIndex) { try SearchIndex(serialized: Array("nope".utf8)) }
        #expect(throws: SearchFormatError.self) { try SearchIndex(serialized: Array(bytes.dropLast(3))) }
        #expect(throws: SearchFormatError.self) { try SearchIndex(serialized: bytes + [0]) }
    }

    @Test func `a word counts once per document, so near misses do not outrank the word itself`() {
        let index = SearchIndex()
        index.add(SearchDocument(text: "cached caches cacher cachedkey cachekeys cash catch caches"))
        index.add(SearchDocument(text: "the cache was cold this morning, then warm, then cold again"))
        #expect(index.search(SearchQuery("cache")).first?.document == 1)
        let parts = SearchIndex()
        parts.add(SearchDocument(text: "local local local source source control control"))
        parts.add(SearchDocument(text: "the pin is localSourceControl in the lock file, which SwiftPM refuses"))
        #expect(parts.search(SearchQuery("localSourceControl")).first?.document == 1)
    }
}
