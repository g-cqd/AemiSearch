/// A document a search found: its number in the index, its score, its fields and time, and the part of its text around the first
/// word found.
public struct SearchHit: Sendable, Equatable {
    public let document: UInt32
    public let score: Double
    public let fields: [String: String]
    public let time: Int64
    public let snippet: String
}
