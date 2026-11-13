# AemiSearch

Full-text search over UTF-8 documents, on the Aemi kernels: terms interned by `AemiInterner` (keyed hashing, since text comes from
anywhere), BM25 ranking, identifiers split into their parts, typo and part-of-word expansion through trigrams (`AemiText`'s bounded
edit distance, `AemiKernel`'s SIMD substring search), field and time filters, snippets, and a checked binary snapshot.

```swift
let index = SearchIndex()
index.add(SearchDocument(text: "The cache key is the request's URL.", fields: ["kind": "reply"], time: 1_700_000_000))
let hits = index.search(SearchQuery("cache key", fields: ["kind": "reply"], limit: 10))
let bytes = index.serialized()            // keep it; encrypt it if the documents are
let again = try SearchIndex(serialized: bytes)
```

Made for ask's session search (t209). Measured on 130,738 real session entries (151 MB of text): indexed in 3.4 s, queries in
1–7 ms, a 231 MB snapshot read back in 0.2 s (`AEMISEARCH_DEV=1 swift run -c release AemiSearchBench CORPUS QUERY...`).
