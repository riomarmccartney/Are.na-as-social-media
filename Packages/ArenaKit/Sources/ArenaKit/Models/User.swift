import Foundation

/// An Are.na user. Decodes `EmbeddedUser`, `User` and `Me` (`GET /v3/me`);
/// fields that only some of those carry are optional.
public struct User: Codable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String
    public let slug: String
    public let avatar: URL?
    public let initials: String?

    public init(id: Int, name: String, slug: String, avatar: URL? = nil, initials: String? = nil) {
        self.id = id
        self.name = name
        self.slug = slug
        self.avatar = avatar
        self.initials = initials
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decode(String.self, forKey: .slug)
        avatar = try container.decodeLenientURL(forKey: .avatar)
        initials = try container.decodeIfPresent(String.self, forKey: .initials)
    }
}
