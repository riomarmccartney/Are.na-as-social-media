import Foundation

/// Markdown with the renderings Are.na provides (`MarkdownContent` schema).
public struct Markdown: Decodable, Sendable, Hashable {
    public let markdown: String
    public let html: String?
    public let plain: String?
}

/// An Are.na block. The type-specific payload lives in ``content``.
public struct Block: Decodable, Sendable, Hashable, Identifiable {
    public enum State: String, Decodable, Sendable {
        case processing
        case available
        case failed
    }

    public struct Image: Decodable, Sendable, Hashable {
        public struct Version: Decodable, Sendable, Hashable {
            public let src: URL
            public let src2x: URL?
            public let width: Int?
            public let height: Int?

            enum CodingKeys: String, CodingKey {
                case src
                case src2x = "src_2x"
                case width, height
            }
        }

        public let src: URL?
        public let altText: String?
        public let blurhash: String?
        public let width: Int?
        public let height: Int?
        public let aspectRatio: Double?
        public let contentType: String?
        public let filename: String?
        public let small: Version
        public let medium: Version
        public let large: Version
        public let square: Version

        enum CodingKeys: String, CodingKey {
            case src
            case altText = "alt_text"
            case blurhash, width, height
            case aspectRatio = "aspect_ratio"
            case contentType = "content_type"
            case filename, small, medium, large, square
        }
    }

    public struct Attachment: Decodable, Sendable, Hashable {
        public let url: URL
        public let filename: String?
        public let contentType: String?
        public let fileSize: Int?
        public let fileExtension: String?

        public var isVideo: Bool { contentType?.hasPrefix("video/") ?? false }

        enum CodingKeys: String, CodingKey {
            case url, filename
            case contentType = "content_type"
            case fileSize = "file_size"
            case fileExtension = "file_extension"
        }
    }

    public struct Embed: Decodable, Sendable, Hashable {
        public let url: URL?
        public let type: String?
        public let title: String?
        public let sourceURL: URL?
        public let thumbnailURL: URL?

        enum CodingKeys: String, CodingKey {
            case url, type, title
            case sourceURL = "source_url"
            case thumbnailURL = "thumbnail_url"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            url = try container.decodeLenientURL(forKey: .url)
            type = try container.decodeIfPresent(String.self, forKey: .type)
            title = try container.decodeIfPresent(String.self, forKey: .title)
            sourceURL = try container.decodeLenientURL(forKey: .sourceURL)
            thumbnailURL = try container.decodeLenientURL(forKey: .thumbnailURL)
        }
    }

    public struct Source: Decodable, Sendable, Hashable {
        public let url: URL
        public let title: String?
    }

    /// Where the block sits in a channel. Only present in channel contents.
    public struct Connection: Decodable, Sendable, Hashable {
        public let id: Int
        public let position: Int?
        public let connectedAt: Date?
        public let connectedBy: User?

        enum CodingKeys: String, CodingKey {
            case id, position
            case connectedAt = "connected_at"
            case connectedBy = "connected_by"
        }
    }

    public enum Content: Sendable, Hashable {
        case text(Markdown)
        case image(Image)
        case link(preview: Image?)
        case attachment(Attachment, preview: Image?)
        case embed(Embed, thumbnail: Image?)
        /// Are.na is still processing the block; its final type isn't known yet.
        case pending
        /// A block type this client doesn't know.
        case unsupported(type: String)
    }

    public let id: Int
    public let title: String?
    public let description: Markdown?
    public let state: State?
    public let createdAt: Date
    public let user: User
    public let source: Source?
    /// Kept mutable so a refreshed copy (from `GET /v3/blocks/{id}`, which has
    /// no connection) can carry over the one from channel contents.
    public var connection: Connection?
    public let content: Content

    /// The block's page on Are.na.
    public var webURL: URL { URL(string: "https://www.are.na/block/\(id)")! }

    /// `true` while Are.na hasn't finished processing the block.
    public var isProcessing: Bool {
        if case .pending = content { return true }
        return state == .processing
    }

    enum CodingKeys: String, CodingKey {
        case id, type, title, description, state
        case createdAt = "created_at"
        case user, source, connection
        case content, image, attachment, embed
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(Markdown.self, forKey: .description)
        state = try container.decodeIfPresent(String.self, forKey: .state).flatMap(State.init(rawValue:))
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        user = try container.decode(User.self, forKey: .user)
        source = try? container.decodeIfPresent(Source.self, forKey: .source)
        connection = try container.decodeIfPresent(Connection.self, forKey: .connection)

        let type = try container.decode(String.self, forKey: .type)
        // Previews are decorative, so a malformed one never fails the block.
        let preview = try? container.decodeIfPresent(Image.self, forKey: .image)
        switch type {
        case "Text":
            content = .text(try container.decode(Markdown.self, forKey: .content))
        case "Image":
            content = .image(try container.decode(Image.self, forKey: .image))
        case "Link":
            content = .link(preview: preview)
        case "Attachment":
            content = .attachment(try container.decode(Attachment.self, forKey: .attachment), preview: preview)
        case "Embed":
            content = .embed(try container.decode(Embed.self, forKey: .embed), thumbnail: preview)
        case "PendingBlock":
            content = .pending
        default:
            content = .unsupported(type: type)
        }
    }
}

/// An item in a channel's or user's contents: a block or a channel.
public enum ContentItem: Decodable, Sendable, Hashable, Identifiable {
    case block(Block)
    case channel(Channel)

    public var id: String {
        switch self {
        case .block(let block): "block-\(block.id)"
        case .channel(let channel): "channel-\(channel.id)"
        }
    }

    public var block: Block? {
        if case .block(let block) = self { return block }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if try container.decode(String.self, forKey: .type) == "Channel" {
            self = .channel(try Channel(from: decoder))
        } else {
            self = .block(try Block(from: decoder))
        }
    }
}
