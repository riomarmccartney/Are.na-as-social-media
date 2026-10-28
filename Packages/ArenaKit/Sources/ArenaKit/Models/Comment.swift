import Foundation

/// A comment on a block.
public struct Comment: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let body: Markdown?
    public let createdAt: Date
    public let user: User

    enum CodingKeys: String, CodingKey {
        case id, body, user
        case createdAt = "created_at"
    }
}
