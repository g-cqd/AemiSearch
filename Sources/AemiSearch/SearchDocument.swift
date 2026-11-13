/// What is indexed: its text, the fields a query filters on (`session`, `kind`, `tool`, …), and when it was written.
public struct SearchDocument: Sendable, Equatable {
    public var text: String
    public var fields: [String: String]
    /// Seconds since 1970, for `since` and `until` and to rank the newer of two equal hits first.
    public var time: Int64

    public init(text: String, fields: [String: String] = [:], time: Int64 = 0) {
        self.text = text
        self.fields = fields
        self.time = time
    }
}
