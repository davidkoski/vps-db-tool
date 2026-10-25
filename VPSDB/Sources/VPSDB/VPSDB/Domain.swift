import Foundation

public struct Author: Codable, Sendable, Hashable, Comparable {
    public let name: String

    public init(name: String) {
        self.name = name
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.name = try container.decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.name)
    }

    public static func < (lhs: Author, rhs: Author) -> Bool {
        lhs.name < rhs.name
    }
}

private let authorMap = [
    "pinballprimer.github.io": "Pinball Primer",
    "animusan2": "Animusan",
    "flyingdutchman": "Flying Dutchman",
    "xfl": "PinRich",
    "francisco pozo robles": "Francisco",
    "francisco pozo": "Francisco",
    "franciscopozo": "Francisco",
    "francisco666": "Francisco",
    "fpozo45": "Francisco",
    "conrado": "Francisco",
]

public func canonicalizeAuthor(_ author: String?) -> String {
    guard let author else { return "unknown" }

    let trimmedAuthor =
        author
        .replacingOccurrences(of: "&nbsp;", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    if let replacement = authorMap[trimmedAuthor.lowercased()] {
        return replacement
    } else {
        return trimmedAuthor
    }
}

public enum TableFormat: String, Codable, Hashable, Sendable, Equatable, CaseIterable {
    case FP
    case FX
    case FX2
    case FX3
    case M
    case VP9
    case VPX
    case PM5
}

public enum Kind: String, Codable, Hashable, Sendable, Equatable, CaseIterable {
    case EM
    case SS
    case PM
    case DG
}
