import Foundation
import Testing
@testable import ArenaKit

@Suite struct DecodingTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder.arena.decode(T.self, from: Data(json.utf8))
    }

    @Test func decodesMe() throws {
        let me = try decode(User.self, Fixtures.me)
        #expect(me == User(id: 42, name: "Rio", slug: "rio", avatar: nil, initials: "R"))
    }

    @Test func decodesChannelWithAbilities() throws {
        let channel = try decode(Channel.self, Fixtures.channel)
        #expect(channel.id == 123)
        #expect(channel.visibility == .closed)
        #expect(channel.counts?.blocks == 42)
        #expect(channel.owner?.id == 42)
        #expect(channel.can?.addTo == true)
    }

    @Test func decodesEveryBlockType() throws {
        let page = try decode(Page<ContentItem>.self, Fixtures.page([
            Fixtures.textBlock, Fixtures.imageBlock, Fixtures.linkBlock,
            Fixtures.videoAttachmentBlock, Fixtures.embedBlock, Fixtures.pendingBlock, Fixtures.channel,
        ]))
        #expect(page.data.count == 7)
        #expect(page.meta.hasMorePages)
        #expect(page.meta.nextPage == 2)

        let blocks = page.data.compactMap(\.block)
        #expect(blocks.count == 6)

        guard case .text(let markdown) = blocks[0].content else { Issue.record("text"); return }
        #expect(markdown.markdown == "hello **world**")

        guard case .image(let image) = blocks[1].content else { Issue.record("image"); return }
        #expect(image.filename == "IMG_4821.jpg")
        #expect(image.medium.src2x == URL(string: "https://cdn.example/m@2x.jpg"))
        #expect(image.aspectRatio == 1.7778)

        guard case .link = blocks[2].content else { Issue.record("link"); return }
        #expect(blocks[2].source?.url == URL(string: "https://example.com/article"))

        guard case .attachment(let attachment, _) = blocks[3].content else { Issue.record("attachment"); return }
        #expect(attachment.isVideo)
        #expect(attachment.filename == "trip.mp4")

        guard case .embed(let embed, _) = blocks[4].content else { Issue.record("embed"); return }
        #expect(embed.sourceURL == URL(string: "https://www.youtube.com/watch?v=abc"))

        #expect(blocks[5].content == .pending)
        #expect(blocks[5].isProcessing)

        if case .channel(let channel) = page.data[6] {
            #expect(channel.slug == "my-feed-abc")
        } else {
            Issue.record("channel")
        }
    }

    @Test func decodesSharedBlockFields() throws {
        let block = try decode(Block.self, Fixtures.imageBlock)
        #expect(block.title == "Title 2")
        #expect(block.description?.markdown == "desc **2**")
        #expect(block.user.id == 42)
        #expect(block.connection?.id == 1002)
        #expect(block.connection?.connectedBy?.id == 42)
        #expect(block.webURL == URL(string: "https://www.are.na/block/2"))
        // Fractional seconds: 2026-10-27T10:30:00.123Z
        #expect(abs(block.createdAt.timeIntervalSince1970 - 1_793_097_000.123) < 0.001)
    }

    @Test func unknownBlockTypeIsUnsupported() throws {
        let block = try decode(Block.self, Fixtures.block(id: 9, type: "Hologram", extra: ""))
        #expect(block.content == .unsupported(type: "Hologram"))
    }

    @Test func malformedItemIsDroppedNotFatal() throws {
        let page = try decode(Page<ContentItem>.self, Fixtures.page([Fixtures.textBlock, #"{ "type": "Image", "id": 7 }"#]))
        #expect(page.data.count == 1)
    }
}
