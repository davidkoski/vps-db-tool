import Foundation
import ReerCodable

extension Decoder {

    public func valueIfPresent<Value: Decodable>(forKeys keys: [String]) throws -> Value? {
        let container = try container(keyedBy: AnyCodingKey.self)
        for key in keys {
            guard let key = AnyCodingKey(stringValue: key) else { continue }
            if let value = try container.decodeIfPresent(Value.self, forKey: key) {
                return value
            }
        }
        return nil
    }

    public func dateValueIfPresent(forKeys keys: [String], strategy: DateCodingStrategy) throws
        -> Date?
    {
        let container = try container(keyedBy: AnyCodingKey.self)

        var found = false
        for key in keys {
            guard let key = AnyCodingKey(stringValue: key) else { continue }
            if container.contains(key) {
                found = true
                break
            }
        }

        if found {
            return try container.decodeDate(type: Date.self, keys: keys, strategy: strategy)
        }

        return nil
    }

}

struct OmitEmpty<Container: Codable & Collection & ExpressibleByArrayLiteral>: CodingCustomizable {

    static func decode(by decoder: any Decoder, keys: [String]) throws -> Container {
        try decoder.valueIfPresent(forKeys: keys) ?? []
    }

    static func encode(by encoder: any Encoder, key: String, value: Container) throws {
        if !value.isEmpty {
            try value.encode(to: encoder)
        }
    }

}

struct OmitIfFalse: CodingCustomizable {

    static func decode(by decoder: any Decoder, keys: [String]) throws -> Bool {
        try decoder.valueIfPresent(forKeys: keys) ?? false
    }

    static func encode(by encoder: any Encoder, key: String, value: Bool) throws {
        if value {
            try value.encode(to: encoder)
        }
    }

}

struct OmitDateUnixEpoch: CodingCustomizable {

    static func decode(by decoder: any Decoder, keys: [String]) throws -> Date {
        // TODO: ideally a "createdAt": null would not exist, but until that is fixed
        (try? decoder.dateValueIfPresent(forKeys: keys, strategy: .millisecondsSince1970))
            ?? Date.distantPast
    }

    static func encode(by encoder: any Encoder, key: String, value: Date) throws {
        if value != Date.distantPast {
            try value.encode(to: encoder)
        }
    }

}
