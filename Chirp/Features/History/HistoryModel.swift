import ArenaKit
import Foundation
import Observation

@MainActor
@Observable
final class HistoryModel {
    private(set) var blocks: [Block] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var lastError: (any Error)?

    private var nextPage: Int? = 1
    /// Bumped on reload so responses to an earlier load are ignored.
    private var generation = 0

    func reload(client: ArenaClient, channelID: Int) async {
        generation += 1
        nextPage = 1
        await load(client: client, channelID: channelID, replacing: true)
    }

    func loadMoreIfNeeded(after block: Block, client: ArenaClient, channelID: Int) async {
        guard !isLoading, nextPage != nil,
            let index = blocks.firstIndex(where: { $0.id == block.id }),
            index >= blocks.count - 5
        else { return }
        await load(client: client, channelID: channelID, replacing: false)
    }

    func remove(_ block: Block, client: ArenaClient) async throws {
        guard let connectionID = block.connection?.id else { return }
        try await client.removeConnection(id: connectionID)
        blocks.removeAll { $0.id == block.id }
    }

    /// Saves the changes and puts the updated block in place of the old one.
    func update(_ block: Block, with changes: BlockUpdate, client: ArenaClient) async throws -> Block {
        var updated = try await client.updateBlock(id: block.id, changes)
        // The update response isn't in a channel, so it has no connection.
        updated.connection = block.connection
        if let index = blocks.firstIndex(where: { $0.id == block.id }) {
            blocks[index] = updated
        }
        return updated
    }

    /// Re-fetches blocks Are.na is still processing (e.g. a just-uploaded
    /// video) until they're ready, for up to about a minute.
    func refreshProcessingBlocks(client: ArenaClient) async {
        for _ in 0..<12 {
            let pending = blocks.filter(\.isProcessing)
            guard !pending.isEmpty else { return }
            try? await Task.sleep(for: .seconds(5))
            if Task.isCancelled { return }
            for block in pending {
                guard var updated = try? await client.block(id: block.id) else { continue }
                updated.connection = block.connection
                if let index = blocks.firstIndex(where: { $0.id == block.id }) {
                    blocks[index] = updated
                }
            }
        }
    }

    private func load(client: ArenaClient, channelID: Int, replacing: Bool) async {
        guard let page = nextPage else { return }
        let generation = generation
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await client.channelContents(channelID: channelID, page: page)
            guard generation == self.generation else { return }
            let incoming = result.data.compactMap(\.block)
            let known = replacing ? [] : blocks
            let knownIDs = Set(known.map(\.id))
            blocks = known + incoming.filter { !knownIDs.contains($0.id) }
            nextPage = result.meta.hasMorePages ? (result.meta.nextPage ?? page + 1) : nil
            errorMessage = nil
            lastError = nil
        } catch is CancellationError {
            return
        } catch {
            guard generation == self.generation else { return }
            errorMessage = error.localizedDescription
            lastError = error
        }
        hasLoaded = true
    }
}
