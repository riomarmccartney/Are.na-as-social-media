import Foundation

extension KeyedDecodingContainer {
    /// Decodes an optional URL without failing the whole object when the
    /// string is empty or not a valid URL.
    func decodeLenientURL(forKey key: Key) throws -> URL? {
        guard let string = try decodeIfPresent(String.self, forKey: key), !string.isEmpty else {
            return nil
        }
        return URL(string: string)
    }
}

/// Wraps a value so one malformed element doesn't fail a whole list.
struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: any Decoder) throws {
        value = try? Value(from: decoder)
    }
}

extension JSONDecoder {
    /// Decoder configured for Are.na's ISO 8601 timestamps, with or without
    /// fractional seconds.
    static var arena: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(string) {
                return date
            }
            if let date = try? Date.ISO8601FormatStyle().parse(string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO 8601 date: \(string)"
            )
        }
        return decoder
    }
}
