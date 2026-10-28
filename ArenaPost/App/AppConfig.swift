import ArenaKit
import Foundation

enum AppConfig {
    static let redirectURI = URL(string: "arenapost://oauth/callback")!
    static let repositoryURL = URL(string: "https://github.com/riomarmccartney/Are.na-as-social-media")!

    /// `ARENA_CLIENT_ID` from `Config/Local.xcconfig`, via Info.plist.
    static var clientID: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "ArenaClientID") as? String,
            !value.isEmpty, !value.hasPrefix("$(")
        else { return nil }
        return value
    }

    static var oauth: OAuthConfiguration? {
        clientID.map { OAuthConfiguration(clientID: $0, redirectURI: redirectURI) }
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Are.na asks API clients to name themselves and a contact.
    static var userAgent: String {
        "Chirp/\(version) (+\(repositoryURL.absoluteString))"
    }
}
