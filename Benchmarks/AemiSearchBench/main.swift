import AemiSearch
import Foundation

// AEMISEARCH_DEV=1 swift run -c release AemiSearchBench CORPUS [QUERY...]: one document per line of CORPUS (`\n` written as `\\n`);
// prints the time to index it, the snapshot's size and the time to read it back, and each query's time and top hit.
let arguments = CommandLine.arguments.dropFirst()
guard let path = arguments.first, let data = FileManager.default.contents(atPath: path) else {
    print("usage: AemiSearchBench CORPUS [QUERY...]")
    exit(2)
}
let clock = ContinuousClock()
let lines = String(decoding: data, as: UTF8.self).split(separator: "\n")
let index = SearchIndex()
let built = clock.measure {
    for line in lines { index.add(SearchDocument(text: line.replacingOccurrences(of: "\\n", with: "\n"))) }
}
print("indexed \(index.count) documents, \(data.count / 1_000_000) MB, \(index.termCount) terms, in \(built)")
var bytes: [UInt8] = []
let written = clock.measure { bytes = index.serialized() }
let read = clock.measure { _ = try? SearchIndex(serialized: bytes) }
print("snapshot \(bytes.count / 1_000_000) MB, written in \(written), read in \(read)")
for query in arguments.dropFirst() {
    var hits: [SearchHit] = []
    let took = clock.measure { for _ in 0 ..< 10 { hits = index.search(SearchQuery(query)) } }
    print("\(query): \(took / 10), \(hits.count) hits; first: \(hits.first?.snippet.prefix(90) ?? "-")")
}
