import Foundation

/// A release title, as written on the sites and in file names:
///
/// ```
/// NAME (DETAILS) SUFFIX
/// Count-Down (Gottlieb 1978) JP v5.5 DT-FS-VR-MR Ext2k Conversion 2.0
/// ```
///
/// - `DETAILS` is usually `Manufacturer Year` (or `Manufacturer, Year`, just
///   one of them, or something else entirely, e.g. `Remastered`)
/// - `SUFFIX` is anything after the parens -- the version is its last
///   version-like token
/// - without parens: `NAME [VERSION]`, e.g. `Close Encounters 1.4.3`
///
/// Site specific cleanup (e.g. VPF's ` wheel`, `.png`) is up to the caller.
public struct ReleaseTitle: Equatable, Sendable {
    /// The name without the parens, e.g. `Count-Down`.  If the parens aren't
    /// recognizable as a manufacturer / year they are kept, e.g. `Name (Remastered)`.
    public var name: String

    /// The name with the parens, e.g. `Count-Down (Gottlieb 1978)`.
    public var title: String

    /// The raw text in the parens, e.g. `Gottlieb 1978`.
    public var details: String?

    public var manufacturer: Manufacturer?
    public var year: Int?

    /// Text after the parens, e.g. `JP v5.5 DT-FS-VR-MR Ext2k Conversion 2.0`.
    public var suffix: String

    /// The last version-like token after the name, e.g. `2.0` -- `nil` if none.
    public var version: String?

    public init(_ string: String) {
        let text = string.split(whereSeparator: \.isWhitespace).joined(separator: " ")

        // the first group of parens with a manufacturer / year, else the first group
        let groups = text.matches(of: /\(([^()]*)\)/)
        let parsedGroups = groups.map { (match: $0, details: Self.parseDetails(String($0.1))) }
        let chosen =
            parsedGroups.first { $0.details.manufacturer != nil || $0.details.year != nil }
            ?? parsedGroups.first

        guard let chosen else {
            // NAME [VERSION]
            var tokens = text.split(separator: " ").map(String.init)
            if tokens.count > 1, let last = tokens.last, Self.isVersion(last) {
                version = last
                tokens.removeLast()
            }
            name = tokens.joined(separator: " ")
            title = name
            suffix = ""
            return
        }

        let prefix = text[..<chosen.match.range.lowerBound]
            .trimmingCharacters(in: .whitespaces)
        let parens = String(text[chosen.match.range])
        let recognized = chosen.details.manufacturer != nil || chosen.details.year != nil

        details = String(chosen.match.1)
        manufacturer = chosen.details.manufacturer
        year = chosen.details.year
        title = prefix.isEmpty ? parens : "\(prefix) \(parens)"
        name = recognized ? prefix : title
        suffix = text[chosen.match.range.upperBound...].trimmingCharacters(in: .whitespaces)
        version = suffix.split(separator: " ").map(String.init).last(where: Self.isVersion)
    }

    /// `2.0`, `1.4.3`, `v5.5`, `v2`, `1.2b` -- but not `2010`, `Ext2k`, `VR2`.
    static func isVersion(_ token: String) -> Bool {
        token.wholeMatch(of: /[vV]\d+(\.\d+)*[a-z]?|\d+(\.\d+)+[a-z]?/) != nil
    }

    /// `Gottlieb 1978`, `Williams, 1991`, `1985`, `Stern` -> manufacturer / year.
    private static func parseDetails(_ details: String) -> (manufacturer: Manufacturer?, year: Int?)
    {
        var details = details
        var year: Int?
        if let match = details.firstMatch(of: /\b(19|20)\d\d\b/) {
            year = Int(details[match.range])
            details.removeSubrange(match.range)
        }
        let manufacturer = Manufacturer(
            fuzzy: details.trimmingCharacters(
                in: .whitespacesAndNewlines.union(.punctuationCharacters)))
        return (manufacturer, year)
    }
}

/// A game name as typically written in release titles:
///
/// - `NAME`
/// - `NAME (Manufacturer Year)`, e.g. `Medieval Madness (Williams 1997)`
/// - `NAME (Manufacturer, Year)`, `NAME (Year)`, `NAME (Manufacturer)`
/// - anything after the parens is ignored, e.g. `Tron (Stern 2011) Mod`
///
/// The manufacturer is only set if it is a known ``Manufacturer``.
public struct ParsedGameName: Equatable, Sendable {
    public var name: String
    public var manufacturer: Manufacturer?
    public var year: Int?

    public init(name: String, manufacturer: Manufacturer? = nil, year: Int? = nil) {
        self.name = name
        self.manufacturer = manufacturer
        self.year = year
    }

    public init(_ string: String) {
        let title = ReleaseTitle(string)
        self.init(name: title.name, manufacturer: title.manufacturer, year: title.year)
    }
}

extension Manufacturer {

    init?(fuzzy name: String) {
        guard !name.isEmpty else { return nil }
        if let exact = Manufacturer(string: name), exact != .missing, exact != .unknown {
            self = exact
            return
        }
        guard
            let match = Manufacturer.allCases.first(where: {
                $0 != .missing && $0 != .unknown
                    && $0.rawValue.caseInsensitiveCompare(name) == .orderedSame
            })
        else { return nil }
        self = match
    }
}
