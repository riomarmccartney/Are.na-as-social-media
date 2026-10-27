import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import ArenaKit

@Suite struct DraftClassifierTests {
    @Test func emptyDraftIsNothing() {
        #expect(DraftClassifier.classify(text: "  \n ", hasAttachment: false) == nil)
    }

    @Test func textIsTrimmedMarkdown() {
        #expect(DraftClassifier.classify(text: "  hello **you**\n", hasAttachment: false) == .text("hello **you**"))
    }

    @Test(arguments: [
        ("https://example.com/a?b=c", "https://example.com/a?b=c"),
        ("  http://example.com  ", "http://example.com"),
        ("www.example.com/x", "https://www.example.com/x"),
        ("HTTPS://Example.com", "HTTPS://Example.com"),
    ])
    func loneURLIsLink(input: String, expected: String) {
        #expect(DraftClassifier.classify(text: input, hasAttachment: false) == .link(URL(string: expected)!))
    }

    @Test(arguments: ["look https://example.com", "example.com", "https://localhost", "ftp://example.com", "https://"])
    func otherTextIsNotLink(input: String) {
        #expect(DraftClassifier.classify(text: input, hasAttachment: false) == .text(input.trimmingCharacters(in: .whitespaces)))
    }

    @Test func attachmentTextBecomesDescription() {
        #expect(DraftClassifier.classify(text: " caption ", hasAttachment: true) == .media(description: "caption"))
        #expect(DraftClassifier.classify(text: "https://example.com", hasAttachment: true) == .media(description: "https://example.com"))
        #expect(DraftClassifier.classify(text: "", hasAttachment: true) == .media(description: nil))
    }
}

@Suite struct AttachmentNamingTests {
    let utc = TimeZone(identifier: "UTC")!
    let date = Date(timeIntervalSince1970: 1_793_111_525) // 2026-10-27 14:32:05 UTC

    @Test func keepsBaseNameAndUsesUploadedExtension() {
        #expect(AttachmentNaming.uploadFilename(originalFilename: "IMG_4821.HEIC", fileExtension: "jpg") == "IMG_4821.jpg")
        #expect(AttachmentNaming.uploadFilename(originalFilename: "trip.MOV", fileExtension: ".mp4") == "trip.mp4")
        #expect(AttachmentNaming.uploadFilename(originalFilename: "zine.pdf", fileExtension: "pdf") == "zine.pdf")
        #expect(AttachmentNaming.uploadFilename(originalFilename: "my.photo.v2.png", fileExtension: "jpg") == "my.photo.v2.jpg")
    }

    @Test func fallsBackToTimestamp() {
        #expect(AttachmentNaming.uploadFilename(originalFilename: nil, fileExtension: "jpg", date: date, timeZone: utc) == "IMG_20261027_143205.jpg")
        #expect(AttachmentNaming.uploadFilename(originalFilename: "  ", fileExtension: "mp4", date: date, timeZone: utc) == "IMG_20261027_143205.mp4")
    }

    @Test func usesLocalTimeZone() {
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        #expect(AttachmentNaming.fallbackBaseName(date: date, timeZone: tokyo) == "IMG_20261027_233205")
    }

    @Test func sanitizesUnsafeCharacters() {
        #expect(AttachmentNaming.uploadFilename(originalFilename: "a:b|c?.jpg", fileExtension: "jpg") == "a_b_c_.jpg")
        #expect(AttachmentNaming.uploadFilename(originalFilename: "dir/写真.jpg", fileExtension: "jpg") == "写真.jpg")
    }

    @Test func mimeTypes() {
        #expect(MIMEType.forFileExtension("JPG") == "image/jpeg")
        #expect(MIMEType.forFileExtension("mp4") == "video/mp4")
        #expect(MIMEType.forFileExtension("pdf") == "application/pdf")
        #expect(MIMEType.forFileExtension("xyz") == "application/octet-stream")
    }
}

@Suite struct ChannelLinkTests {
    @Test(arguments: [
        ("https://www.are.na/rio/my-feed-abc", "my-feed-abc"),
        ("are.na/rio/my-feed-abc", "my-feed-abc"),
        ("www.are.na/rio/my-feed-abc/", "my-feed-abc"),
        ("https://are.na/channel/my-feed-abc?tab=x", "my-feed-abc"),
        ("  my-feed-abc ", "my-feed-abc"),
    ])
    func parsesChannelReferences(input: String, slug: String) {
        #expect(ChannelLink.slug(from: input) == slug)
    }

    @Test(arguments: ["", "https://example.com/rio/feed", "https://www.are.na/rio", "https://www.are.na/block/123/x", "my feed", "fe/ed"])
    func rejectsOtherInput(input: String) {
        #expect(ChannelLink.slug(from: input) == nil)
    }
}

@Suite struct PostServiceTests {
    private func makeService(_ transport: StubTransport) -> PostService {
        PostService(client: ArenaClient(token: "t", userAgent: "UA", transport: transport))
    }

    @Test func postsTextBlock() async throws {
        let transport = StubTransport(status: 201, body: Fixtures.textBlock)
        let block = try await makeService(transport).post(text: " hello ", attachment: nil, channelID: 123)
        #expect(block?.id == 1)

        let body = try #require(transport.requests.first?.request.jsonBody)
        #expect(body["value"] as? String == "hello")
        #expect(body["title"] == nil)
        #expect(transport.requests.count == 1)
    }

    @Test func postsLinkBlock() async throws {
        let transport = StubTransport(status: 201, body: Fixtures.linkBlock)
        try await makeService(transport).post(text: "www.example.com", attachment: nil, channelID: 123)
        #expect(transport.requests.first?.request.jsonBody?["value"] as? String == "https://www.example.com")
    }

    @Test func emptyDraftSendsNothing() async throws {
        let transport = StubTransport(body: "")
        let block = try await makeService(transport).post(text: "", attachment: nil, channelID: 123)
        #expect(block == nil)
        #expect(transport.requests.isEmpty)
    }

    @Test func mediaPostUploadsThenCreatesBlockWithTitleAndDescription() async throws {
        let transport = StubTransport { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/v3/uploads/presign"):
                return (201, """
                { "files": [{ "upload_url": "https://s3.amazonaws.com/arena_images-temp/uploads/u1/IMG_4821.jpg?sig=1",
                              "key": "uploads/u1/IMG_4821.jpg", "content_type": "image/jpeg" }], "expires_in": 3600 }
                """)
            case ("PUT", _):
                return (200, "")
            default:
                return (201, Fixtures.imageBlock)
            }
        }
        let progressLog = ProgressLog()
        let file = UploadFile(fileURL: URL(fileURLWithPath: "/tmp/IMG_4821.jpg"), filename: "IMG_4821.jpg", contentType: "image/jpeg")
        let block = try await makeService(transport).post(text: "sunset", attachment: file, channelID: 123) {
            progressLog.append($0)
        }
        #expect(block?.id == 2)

        let methods = transport.requests.map { "\($0.request.httpMethod!) \($0.request.url!.path)" }
        #expect(methods == ["POST /v3/uploads/presign", "PUT /arena_images-temp/uploads/u1/IMG_4821.jpg", "POST /v3/blocks"])

        let create = try #require(transport.requests.last?.request.jsonBody)
        #expect(create["value"] as? String == "https://s3.amazonaws.com/arena_images-temp/uploads/u1/IMG_4821.jpg")
        #expect(create["title"] as? String == "IMG_4821.jpg")
        #expect(create["description"] as? String == "sunset")

        #expect(progressLog.values == [.uploading(fraction: 0), .uploading(fraction: 0.5), .uploading(fraction: 1), .creatingBlock])
    }

    @Test func mediaWithoutTextHasNoDescription() async throws {
        let transport = StubTransport { request in
            if request.url?.path == "/v3/uploads/presign" {
                return (201, #"{ "files": [{ "upload_url": "https://s3.amazonaws.com/x?s", "key": "k/trip.mp4", "content_type": "video/mp4" }], "expires_in": 3600 }"#)
            }
            return request.httpMethod == "PUT" ? (200, "") : (201, Fixtures.videoAttachmentBlock)
        }
        let file = UploadFile(fileURL: URL(fileURLWithPath: "/tmp/trip.mp4"), filename: "trip.mp4", contentType: "video/mp4")
        try await makeService(transport).post(text: "  ", attachment: file, channelID: 1)

        let create = try #require(transport.requests.last?.request.jsonBody)
        #expect(create["title"] as? String == "trip.mp4")
        #expect(create["description"] == nil)
    }

    @Test func failedUploadDoesNotCreateBlock() async {
        let transport = StubTransport { request in
            if request.url?.path == "/v3/uploads/presign" {
                return (201, #"{ "files": [{ "upload_url": "https://s3.amazonaws.com/x?s", "key": "k/a.jpg", "content_type": "image/jpeg" }], "expires_in": 3600 }"#)
            }
            return (403, "<Error>AccessDenied</Error>")
        }
        let file = UploadFile(fileURL: URL(fileURLWithPath: "/tmp/a.jpg"), filename: "a.jpg", contentType: "image/jpeg")
        await #expect(throws: ArenaError.self) {
            try await makeService(transport).post(text: "", attachment: file, channelID: 1)
        }
        #expect(transport.requests.count == 2)
    }
}

private final class ProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var log: [PostProgress] = []
    func append(_ value: PostProgress) { lock.withLock { log.append(value) } }
    var values: [PostProgress] { lock.withLock { log } }
}
