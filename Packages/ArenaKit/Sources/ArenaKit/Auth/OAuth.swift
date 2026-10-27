import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// OAuth 2.0 authorization-code flow with PKCE against Are.na.
/// The app is a public client: there is no client secret.
public struct OAuthConfiguration: Sendable {
    public static let authorizeURL = URL(string: "https://www.are.na/oauth/authorize")!
    public static let tokenURL = URL(string: "https://api.are.na/v3/oauth/token")!

    public let clientID: String
    public let redirectURI: URL
    /// `write` includes read access. Without it, Are.na defaults to `read`.
    public let scope: String

    public init(clientID: String, redirectURI: URL, scope: String = "write") {
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.scope = scope
    }

    /// The custom URL scheme of ``redirectURI`` (e.g. `arenapost`).
    public var callbackScheme: String? { redirectURI.scheme }

    /// Starts a sign-in attempt: the URL to open plus the secrets to keep
    /// until the callback arrives.
    public func makeAuthorizationRequest() -> AuthorizationRequest {
        let pkce = PKCE.generate()
        let state = randomURLSafeString(byteCount: 16)
        var components = URLComponents(url: Self.authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        return AuthorizationRequest(url: components.url!, state: state, pkce: pkce)
    }
}

public struct AuthorizationRequest: Sendable {
    public let url: URL
    public let state: String
    public let pkce: PKCE
}

public enum OAuthError: Error, Sendable, Equatable {
    case stateMismatch
    case missingCode
    /// The user denied access or Are.na reported an error.
    case authorizationFailed(String)
    /// Are.na granted a token without `write`, so posting would fail.
    case missingWriteScope(granted: String)
}

extension OAuthError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .stateMismatch, .missingCode:
            "Sign-in didn't complete. Please try again."
        case .authorizationFailed(let reason):
            reason == "access_denied" ? "Access to Are.na was denied." : "Are.na sign-in failed (\(reason))."
        case .missingWriteScope:
            "Are.na only granted read access. Sign in again and allow posting."
        }
    }
}

public struct TokenResponse: Decodable, Sendable, Equatable {
    public let accessToken: String
    public let tokenType: String
    public let scope: String

    public var grantsWrite: Bool {
        scope.split(separator: " ").contains("write")
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
    }
}

extension AuthorizationRequest {
    /// Reads the authorization code from the redirect, checking `state`.
    public func code(fromCallback callbackURL: URL) throws -> String {
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        if let error = value("error") {
            throw OAuthError.authorizationFailed(error)
        }
        guard value("state") == state else { throw OAuthError.stateMismatch }
        guard let code = value("code"), !code.isEmpty else { throw OAuthError.missingCode }
        return code
    }

    /// Exchanges the code for an access token (`POST /v3/oauth/token`).
    /// Are.na tokens don't expire and there is no refresh token.
    public func exchange(
        code: String,
        configuration: OAuthConfiguration,
        userAgent: String,
        transport: any HTTPTransport = URLSessionTransport()
    ) async throws -> TokenResponse {
        var request = URLRequest(url: OAuthConfiguration.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = Data(formEncoded([
            ("grant_type", "authorization_code"),
            ("client_id", configuration.clientID),
            ("code", code),
            ("redirect_uri", configuration.redirectURI.absoluteString),
            ("code_verifier", pkce.verifier),
        ]).utf8)

        let (data, response) = try await transport.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw ArenaError.from(status: response.statusCode, body: data, headers: response)
        }
        let token: TokenResponse
        do {
            token = try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw ArenaError.decoding(String(describing: error))
        }
        guard token.grantsWrite else { throw OAuthError.missingWriteScope(granted: token.scope) }
        return token
    }
}

/// `application/x-www-form-urlencoded` encoding (RFC 3986 unreserved set).
func formEncoded(_ pairs: [(String, String)]) -> String {
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    func encode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
    return pairs.map { "\(encode($0.0))=\(encode($0.1))" }.joined(separator: "&")
}
