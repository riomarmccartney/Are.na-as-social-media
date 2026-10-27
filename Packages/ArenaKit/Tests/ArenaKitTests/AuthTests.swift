import Foundation
import Testing

@testable import ArenaKit

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite struct PKCETests {
    @Test func matchesRFC7636Example() {
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func generatedVerifierIsValid() {
        let pkce = PKCE.generate()
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        #expect((43...128).contains(pkce.verifier.count))
        #expect(pkce.verifier.allSatisfy(allowed.contains))
        #expect(PKCE.generate().verifier != pkce.verifier)
    }

    @Test func hashesLongInputAcrossBlocks() {
        // 100 bytes spans two SHA-256 blocks.
        let pkce = PKCE(verifier: String(repeating: "a", count: 100))
        #expect(pkce.challenge == "KBZZeIjkoNOja4K4MxarMmgOuPAPjNO5BNaBJG0oWg4")
    }
}

@Suite struct OAuthTests {
    let configuration = OAuthConfiguration(clientID: "client-1", redirectURI: URL(string: "arenapost://oauth/callback")!)

    @Test func authorizationURLHasPKCEAndWriteScope() throws {
        let request = configuration.makeAuthorizationRequest()
        let components = try #require(URLComponents(url: request.url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        #expect(components.host == "www.are.na")
        #expect(components.path == "/oauth/authorize")
        #expect(items["client_id"] == "client-1")
        #expect(items["redirect_uri"] == "arenapost://oauth/callback")
        #expect(items["response_type"] == "code")
        #expect(items["scope"] == "write")
        #expect(items["code_challenge"] == request.pkce.challenge)
        #expect(items["code_challenge_method"] == "S256")
        #expect(items["state"] == request.state)
        #expect(configuration.callbackScheme == "arenapost")
    }

    @Test func readsCodeFromCallback() throws {
        let request = configuration.makeAuthorizationRequest()
        let callback = URL(string: "arenapost://oauth/callback?code=abc&state=\(request.state)")!
        #expect(try request.code(fromCallback: callback) == "abc")
    }

    @Test func rejectsStateMismatch() {
        let request = configuration.makeAuthorizationRequest()
        let callback = URL(string: "arenapost://oauth/callback?code=abc&state=other")!
        #expect(throws: OAuthError.stateMismatch) { try request.code(fromCallback: callback) }
    }

    @Test func reportsDeniedAccess() {
        let request = configuration.makeAuthorizationRequest()
        let callback = URL(string: "arenapost://oauth/callback?error=access_denied&state=\(request.state)")!
        #expect(throws: OAuthError.authorizationFailed("access_denied")) { try request.code(fromCallback: callback) }
    }

    @Test func exchangesCodeWithFormBody() async throws {
        let transport = StubTransport(
            body: #"{ "access_token": "tok", "token_type": "Bearer", "scope": "write", "created_at": 1702900000 }"#)
        let request = configuration.makeAuthorizationRequest()
        let token = try await request.exchange(code: "c/d+e", configuration: configuration, userAgent: "UA", transport: transport)
        #expect(token.accessToken == "tok")

        let sent = try #require(transport.requests.first?.request)
        #expect(sent.url == OAuthConfiguration.tokenURL)
        #expect(sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        let body = try #require(sent.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(
            body == "grant_type=authorization_code&client_id=client-1&code=c%2Fd%2Be"
                + "&redirect_uri=arenapost%3A%2F%2Foauth%2Fcallback&code_verifier=\(request.pkce.verifier)")
        #expect(!body.contains("client_secret"))
    }

    @Test func rejectsReadOnlyToken() async {
        let transport = StubTransport(body: #"{ "access_token": "tok", "token_type": "Bearer", "scope": "read", "created_at": 1 }"#)
        let request = configuration.makeAuthorizationRequest()
        await #expect(throws: OAuthError.missingWriteScope(granted: "read")) {
            _ = try await request.exchange(code: "c", configuration: configuration, userAgent: "UA", transport: transport)
        }
    }
}
