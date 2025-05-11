import Foundation

struct Author: Codable, Sendable, Hashable, Comparable {
    let name: String

    internal init(name: String) {
        self.name = name
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.name = try container.decode(String.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.name)
    }

    static func < (lhs: Author, rhs: Author) -> Bool {
        lhs.name < rhs.name
    }
}

enum TableFormat: String, Codable, Hashable, Sendable, Equatable {
    case FP
    case FX
    case FX2
    case FX3
    case M
    case VP9
    case VPX
    case PM5
}

enum Kind: String, Codable, Hashable, Sendable, Equatable {
    case EM
    case SS
    case PM
    case DG
}
