import ArenaKit
import SwiftUI

/// A block in the list: a square with its content and the title underneath,
/// as on an are.na channel page. `menu` is offered on long press and from
/// the ••• button.
struct BlockTile<MenuItems: View>: View {
    let block: Block
    let onOpen: () -> Void
    @ViewBuilder let menu: () -> MenuItems

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onOpen) {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay { content }
                    .clipped()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .contextMenu { menu() }

            HStack(spacing: 6) {
                Text(caption.isEmpty ? " " : caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let comments = block.commentCount, comments > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "bubble.left")
                        Text(comments, format: .number)
                    }
                    .fixedSize()
                }
            }
            .font(.arenaSmall)
            .foregroundStyle(.arenaSecondary)
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
            .overlay(alignment: .trailing) {
                Menu {
                    menu()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.arenaSecondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("More")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if block.state == .failed {
            message("Are.na couldn't process this block.")
        } else {
            switch block.content {
            case .text(let markdown):
                MarkdownText(markdown.markdown)
                    .font(.arena(13, relativeTo: .footnote))
                    .foregroundStyle(.arenaBodyInk)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipped()
                    .arenaFrame()

            case .image(let image):
                RemoteImage(url: image.medium.bestURL)

            case .attachment(let attachment, let preview):
                if attachment.isVideo {
                    RemoteImage(url: preview?.medium.bestURL)
                        .overlay { PlayBadge() }
                } else {
                    Text((attachment.fileExtension ?? "File").uppercased())
                        .font(.arenaTitle)
                        .foregroundStyle(.arenaSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .arenaFrame()
                }

            case .link(let preview):
                Group {
                    if let preview {
                        RemoteImage(url: preview.medium.bestURL)
                    } else {
                        message(block.source?.url.host() ?? "Link")
                    }
                }
                .overlay(alignment: .bottomTrailing) { LinkBadge().padding(6) }

            case .embed(let embed, let thumbnail):
                RemoteImage(url: thumbnail?.medium.bestURL ?? embed.thumbnailURL)
                    .overlay { PlayBadge() }

            case .pending:
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Processing…")
                        .font(.arenaSmall)
                        .foregroundStyle(.arenaSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .arenaFrame()

            case .unsupported:
                message("Open on Are.na")
            }
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.arenaSmall)
            .foregroundStyle(.arenaSecondary)
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .arenaFrame()
    }

    /// The title, as Are.na shows it; for links without one, the site.
    private var caption: String {
        if let title = block.title, !title.isEmpty { return title }
        if case .link = block.content { return block.source?.url.host() ?? "" }
        return ""
    }

    private var accessibilityLabel: String {
        let kind =
            switch block.content {
            case .text: "Text"
            case .image: "Image"
            case .attachment(let attachment, _): attachment.isVideo ? "Video" : "File"
            case .link: "Link"
            case .embed: "Media"
            case .pending: "Processing"
            case .unsupported: "Block"
            }
        let comments = block.commentCount.flatMap { $0 > 0 ? "\($0) comment\($0 == 1 ? "" : "s")" : nil } ?? ""
        return [kind, caption, "by \(block.user.name)", comments].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

// MARK: - Pieces shared with BlockDetailView

extension Block.Image.Version {
    var bestURL: URL { src2x ?? src }
}

/// Inline markdown; the caller sets the font.
struct MarkdownText: View {
    let markdown: String

    init(_ markdown: String) {
        self.markdown = markdown
    }

    var body: some View {
        Text(attributed)
    }

    private var attributed: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }
}

/// An image fitted inside the space it's given, on a grey fill until it loads.
struct RemoteImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else {
                Rectangle().fill(.arenaFill)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlayBadge: View {
    var body: some View {
        Image(systemName: "play.fill")
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 3))
            .accessibilityHidden(true)
    }
}

/// The small link marker are.na puts in the corner of link blocks.
private struct LinkBadge: View {
    var body: some View {
        Image(systemName: "link")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.arenaSecondary)
            .frame(width: 24, height: 24)
            .background(.arenaFill, in: RoundedRectangle(cornerRadius: 3))
            .accessibilityHidden(true)
    }
}
