import Foundation

/// A page of a paginated list response (`data` + `meta`).
public struct Page<Item: Decodable & Sendable>: Decodable, Sendable {
    public struct Meta: Decodable, Sendable, Hashable {
        public let currentPage: Int
        public let nextPage: Int?
        public let perPage: Int
        public let totalPages: Int
        public let totalCount: Int
        public let hasMorePages: Bool

        enum CodingKeys: String, CodingKey {
            case currentPage = "current_page"
            case nextPage = "next_page"
            case perPage = "per_page"
            case totalPages = "total_pages"
            case totalCount = "total_count"
            case hasMorePages = "has_more_pages"
        }
    }

    /// Items that decoded successfully. Malformed items are dropped instead of
    /// failing the whole page.
    public let data: [Item]
    public let meta: Meta

    enum CodingKeys: String, CodingKey {
        case data, meta
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode([Lossy<Item>].self, forKey: .data).compactMap(\.value)
        meta = try container.decode(Meta.self, forKey: .meta)
    }
}
