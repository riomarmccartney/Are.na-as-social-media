import ArenaKit
import SwiftUI
import UIKit

/// Past blocks in the channel in one, two or three columns, styled like
/// are.na blocks.
struct HistoryView: View {
    @Environment(AppModel.self) private var app

    @State private var model = HistoryModel()
    @AppStorage(PreferenceKey.historyColumns) private var columnCount = 1
    @State private var blockToRemove: Block?
    @State private var removeError: String?
    @State private var openBlock: Block?
    @State private var editingBlock: Block?
    @State private var toast: Toast?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if model.blocks.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    LazyVGrid(columns: columns, spacing: columnCount == 1 ? 32 : 24) {
                        ForEach(model.blocks) { block in
                            BlockTile(block: block, onOpen: { openBlock = block }) { menu(for: block) }
                                .onAppear {
                                    Task { await loadMore(after: block) }
                                }
                        }
                    }
                    if model.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
        }
        .background(.arenaBackground)
        .navigationTitle(app.channel?.title ?? "Past posts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.snappy) { columnCount = nextColumnCount }
                } label: {
                    Label("Show \(nextColumnCount) column\(nextColumnCount == 1 ? "" : "s")", systemImage: symbol(columns: nextColumnCount))
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .toast($toast) { toast in
            if let link = toast.link { openURL(link) }
            self.toast = nil
        }
        .refreshable { await reload() }
        .task {
            await reload()
            if let client = app.client {
                await model.refreshProcessingBlocks(client: client)
            }
        }
        .sheet(item: $openBlock) { block in
            BlockDetailView(
                block: block,
                channelTitle: app.channel?.title,
                onSave: canEdit(block) ? { try await save($0, to: block) } : nil,
                onDelete: canRemove(block) ? { try await delete(block) } : nil
            )
        }
        .sheet(item: $editingBlock) { block in
            BlockEditView(block: block) { _ = try await save($0, to: block) }
        }
        .confirmationDialog(
            "Delete from \(app.channel?.title ?? "channel")?",
            isPresented: Binding(get: { blockToRemove != nil }, set: { if !$0 { blockToRemove = nil } }),
            titleVisibility: .visible,
            presenting: blockToRemove
        ) { block in
            Button("Delete", role: .destructive) {
                Task { await remove(block) }
            }
        } message: { _ in
            Text(BlockDetailView.deleteExplanation)
        }
        .alert(
            "Couldn't delete the block",
            isPresented: Binding(get: { removeError != nil }, set: { if !$0 { removeError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(removeError ?? "")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !model.hasLoaded {
            ProgressView()
        } else if let message = model.errorMessage {
            VStack(spacing: 12) {
                Text("Couldn't load posts")
                    .font(.arenaBodyBold)
                    .foregroundStyle(.arenaInk)
                Text(message)
                    .font(.arenaSmall)
                    .foregroundStyle(.arenaSecondary)
                    .multilineTextAlignment(.center)
                Button("Try again") { Task { await reload() } }
                    .buttonStyle(.arena)
            }
        } else {
            Text("This channel is empty.")
                .font(.arenaSmall)
                .foregroundStyle(.arenaSecondary)
        }
    }

    @ViewBuilder
    private func menu(for block: Block) -> some View {
        if canEdit(block) {
            Button {
                editingBlock = block
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        if let copyText = block.copyText {
            Button {
                UIPasteboard.general.string = copyText
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
        ShareLink(item: block.shareURL) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        Link(destination: block.webURL) {
            Label("Open in Are.na", systemImage: "safari")
        }
        if !block.isProcessing {
            Button {
                Task { await saveStory(block) }
            } label: {
                Label("Save as story", systemImage: "rectangle.portrait")
            }
        }
        if canRemove(block) {
            Button(role: .destructive) {
                blockToRemove = block
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var columns: [GridItem] {
        let count = min(max(columnCount, 1), 3)
        return Array(repeating: GridItem(.flexible(), spacing: count == 3 ? 10 : 16, alignment: .top), count: count)
    }

    /// The layout the toolbar button switches to: 1 → 2 → 3 → 1.
    private var nextColumnCount: Int {
        min(max(columnCount, 1), 3) % 3 + 1
    }

    private func symbol(columns: Int) -> String {
        switch columns {
        case 1: "rectangle.grid.1x2"
        case 2: "square.grid.2x2"
        default: "square.grid.3x3"
        }
    }

    /// Are.na says whether you can; older responses without it fall back to
    /// "you added it", since only a block's owner can change it.
    private func canEdit(_ block: Block) -> Bool {
        block.can?.manage ?? (block.user.id == app.me?.id)
    }

    /// Contents don't carry removal abilities, so this is a best guess:
    /// you connected it, or you own the channel. The server has the final say.
    private func canRemove(_ block: Block) -> Bool {
        guard let me = app.me, block.connection != nil else { return false }
        return block.connection?.connectedBy?.id == me.id || app.channel?.ownerID == me.id
    }

    private func reload() async {
        guard let client = app.client, let channel = app.channel else { return }
        await model.reload(client: client, channelID: channel.id)
        if let error = model.lastError { app.handle(error) }
    }

    private func loadMore(after block: Block) async {
        guard let client = app.client, let channel = app.channel else { return }
        await model.loadMoreIfNeeded(after: block, client: client, channelID: channel.id)
    }

    /// Saves a 9:16 image of the block for Instagram stories.
    private func saveStory(_ block: Block) async {
        guard let story = await StoryBlock.from(block) else {
            toast = .failure("Couldn't make a story image of this block.")
            return
        }
        do {
            try await StoryExporter.save(StoryCard(block: story))
            toast = .success("Story image saved to Photos", action: "Instagram", link: StoryExporter.instagramURL)
        } catch {
            toast = .failure(error.localizedDescription)
        }
    }

    private func save(_ changes: BlockUpdate, to block: Block) async throws -> Block {
        guard let client = app.client else { throw ArenaError.unauthorized }
        do {
            return try await model.update(block, with: changes, client: client)
        } catch {
            app.handle(error)
            throw error
        }
    }

    private func remove(_ block: Block) async {
        do {
            try await delete(block)
        } catch {
            removeError = error.localizedDescription
        }
    }

    private func delete(_ block: Block) async throws {
        guard let client = app.client else { throw ArenaError.unauthorized }
        do {
            try await model.remove(block, client: client)
        } catch {
            app.handle(error)
            throw error
        }
    }
}

private extension Block {
    /// Text worth copying: markdown, description, or the source link.
    var copyText: String? {
        switch content {
        case .text(let markdown): markdown.markdown
        case .link, .embed: source?.url.absoluteString ?? description?.markdown
        default: description?.markdown
        }
    }

    var shareURL: URL {
        switch content {
        case .link, .embed: source?.url ?? webURL
        default: webURL
        }
    }
}
