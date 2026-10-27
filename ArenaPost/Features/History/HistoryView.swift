import ArenaKit
import SwiftUI
import UIKit

/// Past blocks in the channel, shown as posts.
struct HistoryView: View {
    @Environment(AppModel.self) private var app

    @State private var model = HistoryModel()
    @AppStorage(PreferenceKey.historyFilter) private var filter = HistoryModel.Filter.mine
    @State private var blockToRemove: Block?
    @State private var removeError: String?

    var body: some View {
        List {
            ForEach(model.blocks) { block in
                PostCard(block: block)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .contextMenu { menu(for: block) }
                    .onAppear {
                        Task { await loadMore(after: block) }
                    }
            }
            if model.isLoading, !model.blocks.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .overlay { emptyState }
        .navigationTitle(app.channel?.title ?? "Past posts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Show", selection: $filter) {
                    ForEach(HistoryModel.Filter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        .refreshable { await reload() }
        .task(id: filter) {
            await reload()
            if let client = app.client {
                await model.refreshProcessingBlocks(client: client)
            }
        }
        .confirmationDialog(
            "Remove from \(app.channel?.title ?? "channel")?",
            isPresented: Binding(get: { blockToRemove != nil }, set: { if !$0 { blockToRemove = nil } }),
            titleVisibility: .visible,
            presenting: blockToRemove
        ) { block in
            Button("Remove", role: .destructive) {
                Task { await remove(block) }
            }
        } message: { _ in
            Text("The block stays on Are.na; it's only removed from this channel.")
        }
        .alert(
            "Couldn't remove the block",
            isPresented: Binding(get: { removeError != nil }, set: { if !$0 { removeError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(removeError ?? "")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.blocks.isEmpty {
            if !model.hasLoaded {
                ProgressView()
            } else if let message = model.errorMessage {
                ContentUnavailableView {
                    Label("Couldn't load posts", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") { Task { await reload() } }
                }
            } else {
                ContentUnavailableView(
                    "Nothing here yet",
                    systemImage: "square.stack",
                    description: Text(filter == .mine ? "Your posts will show up here." : "This channel is empty.")
                )
            }
        }
    }

    @ViewBuilder
    private func menu(for block: Block) -> some View {
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
        if canRemove(block) {
            Button(role: .destructive) {
                blockToRemove = block
            } label: {
                Label("Remove from channel", systemImage: "trash")
            }
        }
    }

    /// Contents don't carry removal abilities, so this is a best guess:
    /// you connected it, or you own the channel. The server has the final say.
    private func canRemove(_ block: Block) -> Bool {
        guard let me = app.me, block.connection != nil else { return false }
        return block.connection?.connectedBy?.id == me.id || app.channel?.ownerID == me.id
    }

    private var userIDFilter: Int? {
        filter == .mine ? app.me?.id : nil
    }

    private func reload() async {
        guard let client = app.client, let channel = app.channel else { return }
        await model.reload(client: client, channelID: channel.id, userID: userIDFilter)
        if let error = model.lastError { app.handle(error) }
    }

    private func loadMore(after block: Block) async {
        guard let client = app.client, let channel = app.channel else { return }
        await model.loadMoreIfNeeded(after: block, client: client, channelID: channel.id, userID: userIDFilter)
    }

    private func remove(_ block: Block) async {
        guard let client = app.client else { return }
        do {
            try await model.remove(block, client: client)
        } catch {
            app.handle(error)
            removeError = error.localizedDescription
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
