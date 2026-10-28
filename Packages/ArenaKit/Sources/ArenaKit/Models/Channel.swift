import Foundation

/// An Are.na channel (`Channel` schema).
public struct Channel: Decodable, Sendable, Hashable, Identifiable {
    public enum Visibility: String, Codable, Sendable, CaseIterable {
        case `public`
        case closed
        case `private`
    }

    public struct Counts: Decodable, Sendable, Hashable {
        public let blocks: Int
        public let contents: Int
    }

    public struct Owner: Decodable, Sendable, Hashable {
        public let id: Int
        /// `User` or `Group`.
        public let type: String
        public let name: String
        public let slug: String
    }

    /// Only present when the channel is returned as a full resource
    /// (`GET /v3/channels/{id}`), not when embedded in a list.
    public struct Abilities: Decodable, Sendable, Hashable {
        public let addTo: Bool
        public let update: Bool

        enum CodingKeys: String, CodingKey {
            case addTo = "add_to"
            case update
        }
    }

    public let id: Int
    public let slug: String
    public let title: String
    /// `nil` when Are.na returns a visibility this client doesn't know yet.
    public let visibility: Visibility?
    public let counts: Counts?
    public let owner: Owner?
    public let can: Abilities?

    enum CodingKeys: String, CodingKey {
        case id, slug, title, visibility, counts, owner, can
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        slug = try container.decode(String.self, forKey: .slug)
        title = try container.decode(String.self, forKey: .title)
        visibility = try container.decodeIfPresent(String.self, forKey: .visibility).flatMap(Visibility.init(rawValue:))
        counts = try container.decodeIfPresent(Counts.self, forKey: .counts)
        owner = try container.decodeIfPresent(Owner.self, forKey: .owner)
        can = try container.decodeIfPresent(Abilities.self, forKey: .can)
    }
}
