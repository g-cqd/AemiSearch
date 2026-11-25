# AemiSearch

In-memory full-text search index for Swift 6 built on [Aemi](https://github.com/Aemi-Studio/aemi): keyed term interning, identifier splitting, BM25 ranking, trigram typo and substring expansion, field/time filtering, snippet extraction, and checksummed binary snapshots.

```swift
import AemiSearch

let index = SearchIndex()
index.add(SearchDocument(text: "The cache key is the request's URL.", fields: ["kind": "reply"], time: 1_700_000_000))
let hits = index.search(SearchQuery("cache key", fields: ["kind": "reply"], limit: 10))
let bytes = index.serialized()
let restored = try SearchIndex(serialized: bytes)
```

## Requirements

- Swift 6.4+ (Swift 6 language mode)
- macOS 15+, iOS 18+, tvOS 18+, watchOS 11+, visionOS 2+, or Linux

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/g-cqd/AemiSearch.git", branch: "main")
]
```

## Documentation

- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)

## License

[MIT](LICENSE)
