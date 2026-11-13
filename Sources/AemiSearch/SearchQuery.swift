/// A search: its words, the fields a document must have, a time window, how many hits, and whether to forgive typos.
public struct SearchQuery: Sendable, Equatable {
    public var text: String
    /// Each field must equal its value.
    public var fields: [String: String]
    public var since: Int64?
    public var until: Int64?
    public var limit: Int
    /// Whether a word also finds the terms it is part of, and those one or two edits away.
    public var expands: Bool

    public init(
        _ text: String,
        fields: [String: String] = [:],
        since: Int64? = nil,
        until: Int64? = nil,
        limit: Int = 20,
        expands: Bool = true
    ) {
        self.text = text
        self.fields = fields
        self.since = since
        self.until = until
        self.limit = limit
        self.expands = expands
    }
}
