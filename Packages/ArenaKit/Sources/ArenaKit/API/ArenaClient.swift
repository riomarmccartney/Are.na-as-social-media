import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Typed access to the Are.na v3 API for one signed-in account.
public struct ArenaClient: Sendable {
    public static let baseURL = URL(string: "https://api.are.na/v3/")!

    public let token: String
    private let userAgent: String
    private let transport: any HTTPTransport

    public init(token: String, userAgent: String, transport: any HTTPTransport = URLSessionTransport()) {
        self.token = token
        self.userAgent = userAgent
        self.transport = transport
    }

    // MARK: Users

    /// `GET /v3/me`
    public func me() async throws -> User {
        try await send(.get("me"))
    }

    // MARK: Channels

    /// Channels the user created, most recently updated first.
    /// `GET /v3/users/{id}/contents?type=Channel`
    public func channels(ofUser userID: Int, page: Int = 1, per: Int = 24) async throws -> Page<Channel> {
        try await send(.get("users/\(userID)/contents", query: [
            "type": "Channel",
            "sort": "updated_at_desc",
            "page": String(page),
            "per": String(per),
        ]))
    }

    /// `GET /v3/channels/{id}` — accepts a numeric id or a slug.
    public func channel(_ idOrSlug: String) async throws -> Channel {
        try await send(.get("channels/\(idOrSlug)"))
    }

    /// `POST /v3/channels`
    public func createChannel(title: String, visibility: Channel.Visibility = .closed) async throws -> Channel {
        try await send(.post("channels", body: NewChannel(title: title, visibility: visibility)))
    }

    /// Newest first. Pass `userID` to only get what that user added.
    /// `GET /v3/channels/{id}/contents`
    public func channelContents(
        channelID: Int,
        userID: Int? = nil,
        page: Int = 1,
        per: Int = 24
    ) async throws -> Page<ContentItem> {
        var query = [
            "sort": "created_at_desc",
            "page": String(page),
            "per": String(per),
        ]
        if let userID {
            query["user_id"] = String(userID)
        }
        return try await send(.get("channels/\(channelID)/contents", query: query))
    }

    // MARK: Blocks

    /// `GET /v3/blocks/{id}`
    public func block(id: Int) async throws -> Block {
        try await send(.get("blocks/\(id)"))
    }

    /// `POST /v3/blocks`
    public func createBlock(_ newBlock: NewBlock) async throws -> Block {
        try await send(.post("blocks", body: newBlock))
    }

    /// Removes a block from a channel; the block itself is kept.
    /// `DELETE /v3/connections/{id}`
    public func removeConnection(id: Int) async throws {
        _ = try await perform(.delete("connections/\(id)"))
    }

    // MARK: Uploads

    /// `POST /v3/uploads/presign` for a single file.
    public func presignUpload(filename: String, contentType: String) async throws -> PresignedUpload {
        let body = PresignRequest(files: [.init(filename: filename, contentType: contentType)])
        let response: PresignResponse = try await send(.post("uploads/presign", body: body))
        guard let file = response.files.first else { throw ArenaError.invalidResponse }
        return file
    }

    /// PUTs the file's bytes to the presigned S3 URL.
    public func upload(
        fileAt fileURL: URL,
        to presigned: PresignedUpload,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws {
        var request = URLRequest(url: presigned.uploadURL)
        request.httpMethod = "PUT"
        request.setValue(presigned.contentType, forHTTPHeaderField: "Content-Type")
        let (data, response) = try await transport.upload(request, fromFile: fileURL, progress: progress)
        guard (200..<300).contains(response.statusCode) else {
            throw ArenaError.server(status: response.statusCode, message: String(data: data, encoding: .utf8))
        }
    }

    // MARK: Plumbing

    private func send<Response: Decodable>(_ endpoint: Endpoint) async throws -> Response {
        let data = try await perform(endpoint)
        do {
            return try JSONDecoder.arena.decode(Response.self, from: data)
        } catch {
            throw ArenaError.decoding(String(describing: error))
        }
    }

    private func perform(_ endpoint: Endpoint) async throws -> Data {
        let request = try endpoint.request(baseURL: Self.baseURL, token: token, userAgent: userAgent)
        let (data, response) = try await transport.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw ArenaError.from(status: response.statusCode, body: data, headers: response)
        }
        return data
    }
}

// MARK: - Request bodies

/// Body for `POST /v3/blocks`, connected to a single channel.
public struct NewBlock: Encodable, Sendable, Equatable {
    /// Text/markdown, a URL, or an uploaded file's S3 URL.
    public var value: String
    public var title: String?
    public var description: String?
    public var altText: String?
    public var channelID: Int

    public init(value: String, title: String? = nil, description: String? = nil, altText: String? = nil, channelID: Int) {
        self.value = value
        self.title = title
        self.description = description
        self.altText = altText
        self.channelID = channelID
    }

    private struct ChannelTarget: Encodable {
        let id: Int
    }

    enum CodingKeys: String, CodingKey {
        case value, title, description
        case altText = "alt_text"
        case channels
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(altText, forKey: .altText)
        try container.encode([ChannelTarget(id: channelID)], forKey: .channels)
    }
}

struct NewChannel: Encodable {
    let title: String
    let visibility: Channel.Visibility
}

struct PresignRequest: Encodable {
    struct File: Encodable {
        let filename: String
        let contentType: String

        enum CodingKeys: String, CodingKey {
            case filename
            case contentType = "content_type"
        }
    }

    let files: [File]
}

struct PresignResponse: Decodable {
    let files: [PresignedUpload]
}

/// A presigned S3 upload slot returned by `POST /v3/uploads/presign`.
public struct PresignedUpload: Decodable, Sendable, Equatable {
    public let uploadURL: URL
    public let key: String
    public let contentType: String

    /// The value to pass to `POST /v3/blocks` once the file is uploaded.
    public var blockValue: String {
        "https://s3.amazonaws.com/arena_images-temp/\(key)"
    }

    public init(uploadURL: URL, key: String, contentType: String) {
        self.uploadURL = uploadURL
        self.key = key
        self.contentType = contentType
    }

    enum CodingKeys: String, CodingKey {
        case uploadURL = "upload_url"
        case key
        case contentType = "content_type"
    }
}

// MARK: - Endpoint

struct Endpoint {
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case delete = "DELETE"
    }

    let method: Method
    let path: String
    var query: [String: String] = [:]
    var body: (any Encodable)?

    static func get(_ path: String, query: [String: String] = [:]) -> Endpoint {
        Endpoint(method: .get, path: path, query: query)
    }

    static func post(_ path: String, body: any Encodable) -> Endpoint {
        Endpoint(method: .post, path: path, body: body)
    }

    static func delete(_ path: String) -> Endpoint {
        Endpoint(method: .delete, path: path)
    }

    func request(baseURL: URL, token: String, userAgent: String) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw ArenaError.invalidResponse
        }
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw ArenaError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        return request
    }
}
