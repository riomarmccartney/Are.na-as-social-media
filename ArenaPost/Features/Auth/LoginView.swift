import ArenaKit
import AuthenticationServices
import SwiftUI

/// Laid out like the are.na home page: the star, a short lettered list, and
/// one filled button.
struct LoginView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            ArenaStar()
                .fill(.arenaInk)
                .frame(width: 26, height: 30)
                .accessibilityHidden(true)

            Text("Chirp is")
                .font(.arenaTitle)
                .foregroundStyle(.arenaInk)

            VStack(alignment: .leading, spacing: 10) {
                LetteredItem(letter: "a", text: "A quick way to post to one of your Are.na channels")
                LetteredItem(letter: "b", text: "Text, links, photos, videos and files, each saved as a block")
            }

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    Task { await signIn() }
                } label: {
                    if isSigningIn {
                        ProgressView()
                            .tint(.arenaOnAccent)
                    } else {
                        Text("Sign in with Are.na")
                    }
                }
                .buttonStyle(.arenaPrimary(fullWidth: true))
                .disabled(isSigningIn || AppConfig.oauth == nil)

                if AppConfig.oauth == nil {
                    Text("Set ARENA_CLIENT_ID in Config/Local.xcconfig to enable sign-in.")
                        .font(.arenaSmall)
                        .foregroundStyle(.arenaSecondary)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.arenaSmall)
                        .foregroundStyle(.arenaPrivate)
                }
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: 480, alignment: .leading)
    }

    private func signIn() async {
        guard let oauth = AppConfig.oauth, let scheme = oauth.callbackScheme else { return }
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }

        let request = oauth.makeAuthorizationRequest()
        do {
            let callbackURL = try await webAuthenticationSession.authenticate(
                using: request.url,
                callback: .customScheme(scheme),
                preferredBrowserSession: .shared,
                additionalHeaderFields: [:]
            )
            let code = try request.code(fromCallback: callbackURL)
            let token = try await request.exchange(code: code, configuration: oauth, userAgent: AppConfig.userAgent)
            try await app.signIn(token: token.accessToken)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // The user closed the sign-in sheet.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct LetteredItem: View {
    let letter: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(letter).")
                .foregroundStyle(.arenaSecondary)
                .frame(minWidth: 16, alignment: .trailing)
            Text(text)
                .foregroundStyle(.arenaBodyInk)
        }
        .font(.arena(17))
        .accessibilityElement(children: .combine)
    }
}
