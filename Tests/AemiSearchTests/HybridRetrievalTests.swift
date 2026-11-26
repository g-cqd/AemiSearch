import AemiSearch
import Testing

@Suite("HybridRankFusion & BinaryVectorScorer")
struct HybridRetrievalTests {
    @Test func `fuses weighted ranked lists with score awareness and selects diverse MMR items`() {
        let fused = HybridRankFusion.fuse([
            HybridRankFusion.RankedList(keys: ["a", "b"], weight: 1.0, scores: ["a": 10.0, "b": 4.0]),
            HybridRankFusion.RankedList(keys: ["b", "c"], weight: 0.6, scores: ["b": 0.9, "c": 0.8])
        ])
        #expect((fused["a"] ?? 0) > (fused["c"] ?? 0))
        #expect((fused["b"] ?? 0) > (fused["c"] ?? 0))

        struct Item {
            let id: String
            let vec: [UInt8]
        }
        let v1 = BinaryVectorScorer.quantizeBinary([1, 1, 1, 1, -1, -1, -1, -1])
        let v2 = BinaryVectorScorer.quantizeBinary([-1, -1, -1, -1, 1, 1, 1, 1])
        let items = [Item(id: "a", vec: v1), Item(id: "dup", vec: v1), Item(id: "diverse", vec: v2)]
        let reranked = HybridRankFusion.selectMMR(
            items,
            lambda: 0.5,
            limit: 2,
            vector: \.vec,
            similarity: BinaryVectorScorer.binarySimilarity
        )
        #expect(reranked.prefix(2).map(\.id) == ["a", "diverse"])
    }

    @Test func `quantizes binary codes, shortlists via bounded max-heap, and rescores int8 payloads`() {
        let q = BinaryVectorScorer.quantizeBinary([1, -1, 1, -1, 1, -1, 1, -1])
        let exact = BinaryVectorScorer.quantizeBinary([1, -1, 1, -1, 1, -1, 1, -1])
        let opposite = BinaryVectorScorer.quantizeBinary([-1, 1, -1, 1, -1, 1, -1, 1])
        let near = BinaryVectorScorer.quantizeBinary([1, -1, 1, -1, 1, -1, 1, 1])

        let top2 = BinaryVectorScorer.shortlist(
            query: q,
            packedCodes: opposite + near + exact,
            codeByteWidth: 1,
            topK: 2
        )
        #expect(top2.map(\.index) == [2, 1])
        #expect(top2.map(\.distance) == [0, 1])

        let scaleBits = Float(0.5).bitPattern
        let payload: [UInt8] = [
            UInt8(bitPattern: Int8(10)),
            UInt8(bitPattern: Int8(-20)),
            UInt8(truncatingIfNeeded: scaleBits),
            UInt8(truncatingIfNeeded: scaleBits >> 8),
            UInt8(truncatingIfNeeded: scaleBits >> 16),
            UInt8(truncatingIfNeeded: scaleBits >> 24)
        ]
        #expect(BinaryVectorScorer.dotInt8(query: [2.0, -1.0], quantizedPayload: payload) == 20.0)
    }
}
