import AVKit
import ArenaKit
import SwiftUI

/// One block rendered like a social post.
struct PostCard: View {
    let block: Block

    @State private var showingImage = false
    @State private var showingVideo = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(user: block.user, size: 32)

            VStack(alignment: .leading, spacing: 8) {
                header
                content
            }
        }
        .fullScreenCover(isPresented: $showingImage) {
            if case .image(let image) = block.content {
                ImageViewer(url: image.src ?? image.large.src)
            }
        }
        .fullScreenCover(isPresented: $showingVideo) {
            if case .attachment(let attachment, _) = block.content {
                VideoViewer(url: attachment.url)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(block.user.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(block.createdAt, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        if block.state == .failed {
            Label("Are.na couldn't process this block.", systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.orange)
        }

        switch block.content {
        case .text(let markdown):
            MarkdownText(markdown.markdown)

        case .image(let image):
            descriptionText
            RemoteImage(version: image.medium, aspectRatio: image.aspectRatio)
                .onTapGesture { showingImage = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(image.altText ?? block.title ?? "Image")
            titleCaption

        case .attachment(let attachment, let preview):
            descriptionText
            if attachment.isVideo {
                VideoThumbnail(preview: preview)
                    .onTapGesture { showingVideo = true }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Play video")
            } else {
                Link(destination: attachment.url) {
                    FileChip(attachment: attachment)
                }
            }
            titleCaption

        case .link(let preview):
            descriptionText
            if let url = block.source?.url {
                Link(destination: url) {
                    LinkCard(title: block.title, url: url, image: preview)
                }
            }

        case .embed(let embed, let thumbnail):
            descriptionText
            if let url = embed.sourceURL ?? block.source?.url {
                Link(destination: url) {
                    EmbedCard(embed: embed, image: thumbnail, fallbackURL: embed.thumbnailURL)
                }
            }

        case .pending:
            HStack(spacing: 8) {
                ProgressView()
                Text("Processing on Are.na…")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

        case .unsupported:
            descriptionText
            Link("Open on Are.na", destination: block.webURL)
                .font(.subheadline)
        }
    }

    /// For media posts, the composer text was saved as the description.
    @ViewBuilder
    private var descriptionText: some View {
        if let description = block.description?.markdown, !description.isEmpty {
            MarkdownText(description)
        }
    }

    /// The file name, saved as the title.
    @ViewBuilder
    private var titleCaption: some View {
        if let title = block.title, !title.isEmpty {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - Pieces

private struct MarkdownText: View {
    let markdown: String

    init(_ markdown: String) {
        self.markdown = markdown
    }

    var body: some View {
        Text(attributed)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }

    private var attributed: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }
}

private struct RemoteImage: View {
    let version: Block.Image.Version
    let aspectRatio: Double?

    var body: some View {
        AsyncImage(url: version.src2x ?? version.src) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .aspectRatio(aspectRatio.map { CGFloat($0) } ?? 4 / 3, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: 460)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct VideoThumbnail: View {
    let preview: Block.Image?

    var body: some View {
        ZStack {
            if let preview {
                RemoteImage(version: preview.medium, aspectRatio: preview.aspectRatio)
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.quaternary)
                    .aspectRatio(16 / 9, contentMode: .fit)
            }
            Image(systemName: "play.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .padding(18)
                .background(.black.opacity(0.5), in: Circle())
        }
    }
}

private struct FileChip: View {
    let attachment: Block.Attachment

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename ?? "File")
                    .lineLimit(1)
                if let size = attachment.fileSize {
                    Text(Int64(size).formatted(.byteCount(style: .file)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
        .tint(.primary)
    }
}

private struct LinkCard: View {
    let title: String?
    let url: URL
    let image: Block.Image?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let image {
                RemoteImage(version: image.medium, aspectRatio: image.aspectRatio)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
            }
            VStack(alignment: .leading, spacing: 2) {
                if let title, !title.isEmpty {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Text(url.host() ?? url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 14))
        .tint(.primary)
    }
}

private struct EmbedCard: View {
    let embed: Block.Embed
    let image: Block.Image?
    let fallbackURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let image {
                    RemoteImage(version: image.medium, aspectRatio: image.aspectRatio)
                } else {
                    AsyncImage(url: fallbackURL) { phase in
                        if let loaded = phase.image {
                            loaded.resizable().scaledToFill()
                        } else {
                            Rectangle().fill(.quaternary)
                        }
                    }
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Image(systemName: "play.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(.black.opacity(0.5), in: Circle())
            }
            if let title = embed.title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .tint(.primary)
            }
        }
    }
}

// MARK: - Full screen viewers

private struct ImageViewer: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    ProgressView().tint(.white)
                }
            }
            .scaleEffect(scale * pinch)
            .gesture(
                MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onEnded { value in scale = min(max(scale * value.magnification, 1), 5) }
            )
            .onTapGesture(count: 2) {
                withAnimation(.snappy) { scale = scale > 1 ? 1 : 2.5 }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CloseButton { dismiss() }
        }
    }
}

private struct VideoViewer: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea(edges: .bottom)
            }
            CloseButton { dismiss() }
        }
        .onAppear {
            let player = AVPlayer(url: url)
            self.player = player
            player.play()
        }
        .onDisappear { player?.pause() }
    }
}

private struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .padding(10)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .padding()
        .accessibilityLabel("Close")
    }
}
