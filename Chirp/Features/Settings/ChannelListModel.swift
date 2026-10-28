import ArenaKit
import Observation

@MainActor
@Observable
final class ChannelListModel {
    private(set) var channels: [Channel] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastError: (any Error)?

    private var nextPage: Int? = 1

    func reload(client: ArenaClient, userID: Int) async {
        nextPage = 1
        await load(client: client, userID: userID, replacing: true)
    }

    func loadMore(client: ArenaClient, userID: Int) async {
        await load(client: client, userID: userID, replacing: false)
    }

    private func load(client: ArenaClient, userID: Int, replacing: Bool) async {
        guard let page = nextPage, !isLoading || replacing else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await client.channels(ofUser: userID, page: page)
            let known = replacing ? [] : channels
            let knownIDs = Set(known.map(\.id))
            channels = known + result.data.filter { !knownIDs.contains($0.id) }
            nextPage = result.meta.hasMorePages ? (result.meta.nextPage ?? page + 1) : nil
            errorMessage = nil
            lastError = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
            lastError = error
        }
    }
}
