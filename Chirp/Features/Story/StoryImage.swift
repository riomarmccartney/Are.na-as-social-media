import ArenaKit
import Photos
import SwiftUI
import UIKit

/// What goes in the middle of a story image: one block, drawn like a tile on
/// an are.na channel page. Images are loaded up front because
/// `ImageRenderer` can't wait for downloads.
struct StoryBlock {
    enum Content {
        case text(String)
        case image(UIImage, badge: Badge?)
        case file(extension: String)
        case link(host: String)
    }

    enum Badge {
        case play
        case link
    }

    let content: Content
    /// The block title, shown under the tile.
    let caption: String?
}

extension StoryBlock {
    /// From what's in the composer, before it's posted (the attachment's
    /// files are deleted once the post is done).
    init?(kind: PostKind?, attachment: PreparedAttachment?) {
        switch kind {
        case .text(let markdown):
            self.init(content: .text(markdown), caption: nil)
        case .link(let url):
            self.init(content: .link(host: url.host() ?? url.absoluteString), caption: url.absoluteString)
        case .media:
            guard let attachment else { return nil }
            let preview = attachment.previewURL.flatMap { UIImage(contentsOfFile: $0.path) }
            switch attachment.kind {
            case .image, .video:
                guard let preview else { return nil }
                self.init(content: .image(preview, badge: attachment.kind == .video ? .play : nil), caption: attachment.filename)
            case .file:
                self.init(content: .file(extension: attachment.fileURL.pathExtension), caption: attachment.filename)
            }
        case nil:
            return nil
        }
    }

    /// From a posted block, downloading its image if it has one.
    static func from(_ block: Block) async -> StoryBlock? {
        func image(_ url: URL?) async -> UIImage? {
            guard let url, let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
            return UIImage(data: data)
        }
        let caption = block.title.flatMap { $0.isEmpty ? nil : $0 }

        switch block.content {
        case .text(let markdown):
            return StoryBlock(content: .text(markdown.markdown), caption: caption)
        case .image(let picture):
            // The original, so the photo stays sharp at the story's size.
            guard let loaded = await image(picture.src ?? picture.large.bestURL) else { return nil }
            return StoryBlock(content: .image(loaded, badge: nil), caption: caption)
        case .attachment(let attachment, let preview):
            if attachment.isVideo, let loaded = await image(preview?.large.bestURL) {
                return StoryBlock(content: .image(loaded, badge: .play), caption: caption)
            }
            return StoryBlock(content: .file(extension: attachment.fileExtension ?? "file"), caption: caption)
        case .link(let preview):
            let host = block.source?.url.host() ?? "Link"
            if let loaded = await image(preview?.large.bestURL) {
                return StoryBlock(content: .image(loaded, badge: .link), caption: caption ?? host)
            }
            return StoryBlock(content: .link(host: host), caption: caption)
        case .embed(let embed, let thumbnail):
            guard let loaded = await image(thumbnail?.large.bestURL ?? embed.thumbnailURL) else { return nil }
            return StoryBlock(content: .image(loaded, badge: .play), caption: caption ?? embed.title)
        case .pending, .unsupported:
            return nil
        }
    }
}

/// A 9:16 story laid out on a 1080 × 1920 canvas and rendered at
/// `StoryExporter.pixelWidth`: the block as an outlined square in the middle,
/// with its title underneath.
struct StoryCard: View {
    static let size = CGSize(width: 1080, height: 1920)
    private static let tile: CGFloat = 840
    private static let band: CGFloat = 112
    /// The tile is the one-column list tile (398 pt wide on a 430 pt phone)
    /// scaled up, so type and spacing keep the same proportions as in the app.
    private static let k: CGFloat = tile / 398

    let block: StoryBlock

    var body: some View {
        ZStack {
            Color.arenaBackground

            // Equal bands above and below keep the tile in the middle.
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: Self.band)
                tile
                    .frame(width: Self.tile, height: Self.tile)
                    .overlay { Rectangle().strokeBorder(Color(white: 0.8), lineWidth: 1 * Self.k) }
                Text(block.caption ?? " ")
                    .font(.custom("ArialMT", size: 13 * Self.k))
                    .foregroundStyle(.arenaSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: Self.tile)
                    .padding(.top, 8 * Self.k)
                    .frame(height: Self.band, alignment: .top)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private var tile: some View {
        switch block.content {
        case .text(let markdown):
            MarkdownText(markdown)
                .font(.custom("ArialMT", size: 13 * Self.k))
                .foregroundStyle(.arenaBodyInk)
                .padding(12 * Self.k)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()

        case .image(let image, let badge):
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if badge == .play {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20 * Self.k))
                            .foregroundStyle(.white)
                            .frame(width: 44 * Self.k, height: 44 * Self.k)
                            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 3 * Self.k))
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if badge == .link {
                        linkBadge.padding(6 * Self.k)
                    }
                }

        case .file(let fileExtension):
            Text(fileExtension.uppercased())
                .font(.custom("Arial-BoldMT", size: 20 * Self.k))
                .foregroundStyle(.arenaSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .link(let host):
            Text(host)
                .font(.custom("ArialMT", size: 13 * Self.k))
                .foregroundStyle(.arenaSecondary)
                .multilineTextAlignment(.center)
                .padding(12 * Self.k)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottomTrailing) { linkBadge.padding(6 * Self.k) }
        }
    }

    private var linkBadge: some View {
        Image(systemName: "link")
            .font(.system(size: 11 * Self.k, weight: .semibold))
            .foregroundStyle(.arenaSecondary)
            .frame(width: 24 * Self.k, height: 24 * Self.k)
            .background(.arenaFill, in: RoundedRectangle(cornerRadius: 3 * Self.k))
    }
}

enum StoryExporter {
    /// The saved image is at least this wide (1440 × 2560).
    static let pixelWidth: CGFloat = 1440

    /// Opens Instagram's story camera, where the saved image is one swipe away.
    static let instagramURL = URL(string: "instagram://story-camera")!

    enum Failure: LocalizedError {
        case render
        case noPhotosAccess

        var errorDescription: String? {
            switch self {
            case .render: "Couldn't make the story image."
            case .noPhotosAccess: "Allow Chirp to add photos in Settings to save story images."
            }
        }
    }

    @MainActor
    static func render(_ card: StoryCard) -> UIImage? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = pixelWidth / StoryCard.size.width
        renderer.proposedSize = ProposedViewSize(StoryCard.size)
        return renderer.uiImage
    }

    /// Renders the card and adds it to the photo library.
    @MainActor
    static func save(_ card: StoryCard) async throws {
        guard let image = render(card) else { throw Failure.render }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw Failure.noPhotosAccess }
        try await addToLibrary(image)
    }

    /// Nonisolated because Photos runs the change block on its own queue; a
    /// main-actor closure there traps.
    private nonisolated static func addToLibrary(_ image: UIImage) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}
