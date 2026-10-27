import ArenaKit
import Foundation
import Observation

/// The channel posts go to, stored on device.
struct ChannelRef: Codable, Hashable, Sendable {
    let id: Int
    let slug: String
    let title: String
    let ownerID: Int?

    init(_ channel: Channel) {
        id = channel.id
        slug = channel.slug
        title = channel.title
        ownerID = channel.owner?.type == "User" ? channel.owner?.id : nil
    }
}

/// Session state: who is signed in and which channel is selected.
@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case launching
        case signedOut
        case needsChannel
        case ready
    }

    private(set) var phase: Phase = .launching
    private(set) var me: User?
    private(set) var channel: ChannelRef?
    private(set) var client: ArenaClient?

    private let keychain = Keychain(service: "studio.upcoming.arenapost")
    private let defaults = UserDefaults.standard

    private enum Key {
        static let token = "arena.token"
        static let me = "session.me"
        static let channel = "session.channel"
    }

    init() {
        me = defaults.decoded(User.self, forKey: Key.me)
        channel = defaults.decoded(ChannelRef.self, forKey: Key.channel)
    }

    /// Restores the session from the Keychain and refreshes the profile.
    func bootstrap() async {
        guard phase == .launching else { return }
        guard let token = keychain.read(Key.token) else {
            phase = .signedOut
            return
        }
        let client = ArenaClient(token: token, userAgent: AppConfig.userAgent)
        self.client = client
        // Open straight into the app with the cached profile; refresh below.
        updatePhase()

        do {
            store(me: try await client.me())
        } catch {
            handle(error)
        }
    }

    /// Validates the token by loading the profile, then saves it.
    func signIn(token: String) async throws {
        let client = ArenaClient(token: token, userAgent: AppConfig.userAgent)
        let me = try await client.me()
        try keychain.write(token, for: Key.token)
        if me.id != self.me?.id {
            select(nil)
        }
        self.client = client
        store(me: me)
        updatePhase()
    }

    func signOut() {
        keychain.delete(Key.token)
        defaults.removeObject(forKey: Key.me)
        client = nil
        me = nil
        select(nil)
        phase = .signedOut
    }

    func select(_ channel: Channel?) {
        self.channel = channel.map(ChannelRef.init)
        defaults.encode(self.channel, forKey: Key.channel)
        if client != nil {
            updatePhase()
        }
    }

    /// Signs out when Are.na says the token is no longer valid.
    func handle(_ error: any Error) {
        if case ArenaError.unauthorized = error {
            signOut()
        }
    }

    private func store(me: User) {
        self.me = me
        defaults.encode(me, forKey: Key.me)
    }

    private func updatePhase() {
        phase = channel == nil ? .needsChannel : .ready
    }
}

private extension UserDefaults {
    func decoded<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    func encode<T: Encodable>(_ value: T?, forKey key: String) {
        if let value, let data = try? JSONEncoder().encode(value) {
            set(data, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
}
