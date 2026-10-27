import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import ArenaKit

@Suite struct ArenaClientTests {
    private func client(_ transport: StubTransport) -> ArenaClient {
        ArenaClient(token: "secret", userAgent: "ArenaPost/1.0 (+test)", transport: transport)
    }

    @Test func sendsAuthAndUserAgent() async throws {
        let transport = StubTransport(body: Fixtures.me)
        _ = try await client(transport).me()

        let request = try #require(transport.requests.first?.request)
        #expect(request.url?.absoluteString == "https://api.are.na/v3/me")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "ArenaPost/1.0 (+test)")
    }

    @Test func listsUserChannels() async throws {
        let transport = StubTransport(body: Fixtures.page([Fixtures.channel]))
        let page = try await client(transport).channels(ofUser: 42, page: 2)

        let request = try #require(transport.requests.first?.request)
        #expect(request.url?.path == "/v3/users/42/contents")
        #expect(request.queryItems == ["type": "Channel", "sort": "updated_at_desc", "page": "2", "per": "24"])
        #expect(page.data.first?.id == 123)
    }

    @Test func channelContentsFiltersByUser() async throws {
        let transport = StubTransport(body: Fixtures.page([Fixtures.textBlock]))
        _ = try await client(transport).channelContents(channelID: 123, userID: 42)

        let request = try #require(transport.requests.first?.request)
        #expect(request.url?.path == "/v3/channels/123/contents")
        #expect(request.queryItems == ["sort": "created_at_desc", "page": "1", "per": "24", "user_id": "42"])
    }

    @Test func channelContentsWithoutUserFilter() async throws {
        let transport = StubTransport(body: Fixtures.page([]))
        _ = try await client(transport).channelContents(channelID: 123)
        #expect(transport.requests.first?.request.queryItems["user_id"] == nil)
    }

    @Test func createsChannel() async throws {
        let transport = StubTransport(status: 201, body: Fixtures.channel)
        _ = try await client(transport).createChannel(title: "my feed", visibility: .private)

        let request = try #require(transport.requests.first?.request)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/v3/channels")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.jsonBody?["title"] as? String == "my feed")
        #expect(request.jsonBody?["visibility"] as? String == "private")
    }

    @Test func createBlockUsesChannelsForm() async throws {
        let transport = StubTransport(status: 201, body: Fixtures.textBlock)
        _ = try await client(transport).createBlock(NewBlock(value: "hi", title: "T", description: "D", channelID: 123))

        let body = try #require(transport.requests.first?.request.jsonBody)
        #expect(body["value"] as? String == "hi")
        #expect(body["title"] as? String == "T")
        #expect(body["description"] as? String == "D")
        #expect((body["channels"] as? [[String: Any]])?.first?["id"] as? Int == 123)
        #expect(body["channel_ids"] == nil)
    }

    @Test func createBlockOmitsEmptyOptionalFields() async throws {
        let transport = StubTransport(status: 201, body: Fixtures.textBlock)
        _ = try await client(transport).createBlock(NewBlock(value: "hi", channelID: 1))

        let body = try #require(transport.requests.first?.request.jsonBody)
        #expect(Set(body.keys) == ["value", "channels"])
    }

    @Test func removesConnection() async throws {
        let transport = StubTransport(status: 204, body: "")
        try await client(transport).removeConnection(id: 1001)

        let request = try #require(transport.requests.first?.request)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.path == "/v3/connections/1001")
    }

    @Test func presignsAndUploads() async throws {
        let transport = StubTransport { request in
            if request.url?.host == "s3.amazonaws.com" { return (200, "") }
            return (201, """
            { "files": [{ "upload_url": "https://s3.amazonaws.com/arena_images-temp/uploads/u1/photo.jpg?sig=1",
                          "key": "uploads/u1/photo.jpg", "content_type": "image/jpeg" }], "expires_in": 3600 }
            """)
        }
        let client = client(transport)
        let presigned = try await client.presignUpload(filename: "photo.jpg", contentType: "image/jpeg")
        #expect(presigned.blockValue == "https://s3.amazonaws.com/arena_images-temp/uploads/u1/photo.jpg")

        let presignBody = try #require(transport.requests.first?.request.jsonBody)
        let files = try #require(presignBody["files"] as? [[String: String]])
        #expect(files == [["filename": "photo.jpg", "content_type": "image/jpeg"]])

        let file = URL(fileURLWithPath: "/tmp/photo.jpg")
        try await client.upload(fileAt: file, to: presigned)
        let upload = try #require(transport.requests.last)
        #expect(upload.request.httpMethod == "PUT")
        #expect(upload.request.value(forHTTPHeaderField: "Content-Type") == "image/jpeg")
        #expect(upload.request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(upload.uploadedFile == file)
    }

    @Test(arguments: [
        (401, "{}", ArenaError.unauthorized),
        (403, #"{ "error": "Forbidden", "code": 403, "details": { "message": "Read-only token" } }"#,
         ArenaError.forbidden(message: "Read-only token")),
        (404, #"{ "error": "Not Found", "code": 404 }"#, ArenaError.notFound),
        (429, #"{ "error": { "type": "rate_limit_exceeded", "message": "slow down", "tier": "free", "limit": 120, "retry_after": 65, "suggestions": [] } }"#,
         ArenaError.rateLimited(retryAfter: 65)),
        (500, #"{ "error": "Internal", "code": 500, "details": { "message": "Oops" } }"#,
         ArenaError.server(status: 500, message: "Oops")),
    ])
    func mapsErrors(status: Int, body: String, expected: ArenaError) async {
        let transport = StubTransport(status: status, body: body)
        await #expect(throws: expected) {
            _ = try await client(transport).me()
        }
    }

    @Test func decodingFailureIsReported() async {
        let transport = StubTransport(body: "{}")
        await #expect {
            _ = try await client(transport).me()
        } throws: { error in
            if case ArenaError.decoding = error { return true }
            return false
        }
    }
}
