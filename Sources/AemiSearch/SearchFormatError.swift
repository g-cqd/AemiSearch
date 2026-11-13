/// Why bytes are no index: they end early, they are not one, or what they say does not hold together.
public enum SearchFormatError: Error, Equatable, Sendable {
    /// Not an AemiSearch snapshot, or one of a version this one does not read.
    case notAnIndex
    /// The bytes end before what they announce.
    case truncated
    /// A count, an offset or a document number that does not fit the rest.
    case inconsistent(String)
}
