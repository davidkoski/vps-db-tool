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

public enum TableFormat: String, Codable, Hashable, Sendable, Equatable {
    case FP
    case FX
    case FX2
    case FX3
    case M
    case VP9
    case VPX
    case PM5
}

public enum Kind: String, Codable, Hashable, Sendable, Equatable {
    case EM
    case SS
    case PM
    case DG
}
