import AVKit
import ArenaKit
import SwiftUI

/// One block opened from the list: its content, title, description, who
/// added it, comments and other channels it's in, like a block page on are.na.
struct BlockDetailView: View {
    /// What Are.na's "delete" can do through the API: blocks are only ever
    /// removed from a channel.
    static let deleteExplanation =
        "It's removed from this channel. Are.na doesn't let apps delete blocks completely, so it stays in any other channels it's in."

    /// The channel you post to, for the delete confirmation.
    let channelTitle: String?
    /// Saves changes and returns the updated block; `nil` when you can't
    /// edit this block.
    let onSave: ((BlockUpdate) async throws -> Block)?
    /// Removes the block from the channel; `nil` when you can't.
    let onDelete: (() async throws -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var block: Block
    @State private var showingEditor = false
    @State private var confirmingDelete = false
    @State private var deleteError: String?
    @State private var showingImage = false
    @State private var showingVideo = false

    init(
        block: Block,
        channelTitle: String? = nil,
        onSave: ((BlockUpdate) async throws -> Block)? = nil,
        onDelete: (() async throws -> Void)? = nil
    ) {
        _block = State(initialValue: block)
        self.channelTitle = channelTitle
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    media

                    if onSave != nil || onDelete != nil {
                        manageButtons
                    }

                    if let title = block.title, !title.isEmpty {
                        Text(title)
                            .font(.arenaTitle)
                            .foregroundStyle(.arenaInk)
                            .textSelection(.enabled)
                    }

                    if let description = block.description?.markdown, !description.isEmpty {
                        MarkdownText(description)
                            .font(.arena(17))
                            .foregroundStyle(.arenaBodyInk)
                            .textSelection(.enabled)
                    }

                    ArenaSection("Info") {
                        InfoRow(label: "Added by", value: Text(block.user.name))
                        InfoRow(
                            label: "Added",
                            value: Text(block.createdAt, format: .relative(presentation: .named))
                        )
                    }

                    actions

                    BlockActivityView(block: block)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.arenaBackground)
            .navigationTitle(kindTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .confirmationDialog(
            "Delete from \(channelTitle ?? "channel")?", isPresented: $confirmingDelete, titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await delete() }
            }
        } message: {
            Text(Self.deleteExplanation)
        }
        .alert(
            "Couldn't delete the block",
            isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
        .sheet(isPresented: $showingEditor) {
            BlockEditView(block: block) { changes in
                if let onSave {
                    block = try await onSave(changes)
                }
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

    @ViewBuilder
    private var media: some View {
        if block.state == .failed {
            Label("Are.na couldn't process this block.", systemImage: "exclamationmark.triangle")
                .font(.arenaSmall)
                .foregroundStyle(.arenaPrivate)
        }

        switch block.content {
        case .text(let markdown):
            MarkdownText(markdown.markdown)
                .font(.arena(17))
                .foregroundStyle(.arenaBodyInk)
                .textSelection(.enabled)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .arenaFrame()

        case .image(let image):
            Button {
                showingImage = true
            } label: {
                fitted(RemoteImage(url: image.large.bestURL), aspectRatio: image.aspectRatio)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(image.altText ?? block.title ?? "Image")
            .accessibilityHint("Opens full screen")

        case .attachment(let attachment, let preview):
            if attachment.isVideo {
                Button {
                    showingVideo = true
                } label: {
                    fitted(RemoteImage(url: preview?.large.bestURL), aspectRatio: preview?.aspectRatio ?? 16 / 9)
                        .overlay { PlayBadge() }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play video")
            } else {
                Link(destination: attachment.url) {
                    FileRow(attachment: attachment)
                }
            }

        case .link(let preview):
            if let preview, let url = block.source?.url {
                Link(destination: url) {
                    fitted(RemoteImage(url: preview.large.bestURL), aspectRatio: preview.aspectRatio)
                }
                .accessibilityLabel("Open \(url.host() ?? "link")")
            }

        case .embed(let embed, let thumbnail):
            if let url = embed.sourceURL ?? block.source?.url {
                Link(destination: url) {
                    fitted(RemoteImage(url: thumbnail?.large.bestURL ?? embed.thumbnailURL), aspectRatio: thumbnail?.aspectRatio ?? 16 / 9)
                        .overlay { PlayBadge() }
                }
                .accessibilityLabel("Play \(embed.title ?? "media")")
            }

        case .pending:
            HStack(spacing: 8) {
                ProgressView()
                Text("Processing on Are.na…")
                    .foregroundStyle(.arenaSecondary)
            }
            .font(.arenaSmall)

        case .unsupported:
            EmptyView()
        }
    }

    private func delete() async {
        guard let onDelete else { return }
        do {
            try await onDelete()
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
    }

    private func fitted(_ image: RemoteImage, aspectRatio: Double?) -> some View {
        image
            .aspectRatio(aspectRatio.map { CGFloat($0) } ?? 1, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: 520)
    }

    /// Edit and Delete sit right under the block so they're easy to find.
    private var manageButtons: some View {
        HStack(spacing: 8) {
            if onSave != nil {
                Button {
                    showingEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            if onDelete != nil {
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .labelStyle(.titleAndIcon)
        .buttonStyle(.arena)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Link("Open on Are.na", destination: block.webURL)
            if let url = sourceURL {
                Link("Open link", destination: url)
            }
        }
        .buttonStyle(.arena)
    }

    private var sourceURL: URL? {
        switch block.content {
        case .link: block.source?.url
        case .embed(let embed, _): embed.sourceURL ?? block.source?.url
        default: nil
        }
    }

    private var kindTitle: String {
        switch block.content {
        case .text: "Text"
        case .image: "Image"
        case .attachment(let attachment, _): attachment.isVideo ? "Video" : "File"
        case .link: "Link"
        case .embed: "Media"
        case .pending, .unsupported: "Block"
        }
    }
}

// MARK: - Pieces

private struct InfoRow: View {
    let label: String
    let value: Text

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(.arenaSecondary)
                .frame(width: 72, alignment: .leading)
            value
                .foregroundStyle(.arenaInk)
            Spacer(minLength: 0)
        }
        .font(.arenaSmall)
        .accessibilityElement(children: .combine)
    }
}

private struct FileRow: View {
    let attachment: Block.Attachment

    var body: some View {
        HStack(spacing: 12) {
            Text((attachment.fileExtension ?? "File").uppercased())
                .font(.arenaSmallBold)
                .foregroundStyle(.arenaSecondary)
                .frame(width: 44, height: 44)
                .arenaFrame()
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename ?? "File")
                    .font(.arenaBody)
                    .foregroundStyle(.arenaInk)
                    .lineLimit(1)
                if let size = attachment.fileSize {
                    Text(Int64(size).formatted(.byteCount(style: .file)))
                        .font(.arenaSmall)
                        .foregroundStyle(.arenaSecondary)
                }
            }
            Spacer()
            Image(systemName: "arrow.down")
                .foregroundStyle(.arenaSecondary)
        }
        .padding(12)
        .arenaFrame()
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
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
        }
        .padding()
        .accessibilityLabel("Close")
    }
}
