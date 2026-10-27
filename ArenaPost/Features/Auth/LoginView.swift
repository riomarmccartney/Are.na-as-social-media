import ArenaKit
import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    @State private var isSigningIn = false
    @State private var errorMessage: String?
    #if DEBUG
        @State private var personalToken = ""
    #endif

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.tint)
                Text("Post to Are.na")
                    .font(.largeTitle.bold())
                Text("Write, snap or share. Every post becomes a block in your channel.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await signIn() }
                } label: {
                    Group {
                        if isSigningIn {
                            ProgressView()
                        } else {
                            Text("Sign in with Are.na")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(isSigningIn || AppConfig.oauth == nil)

                if AppConfig.oauth == nil {
                    Text("Set ARENA_CLIENT_ID in Config/Local.xcconfig to enable sign-in.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }

            #if DEBUG
                personalTokenForm
            #endif
        }
        .padding(24)
        .frame(maxWidth: 480)
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

    #if DEBUG
        /// Development shortcut until the OAuth app is registered. Personal
        /// access tokens give full account access, so this never ships.
        private var personalTokenForm: some View {
            VStack(spacing: 8) {
                SecureField("Personal access token (debug)", text: $personalToken)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                Button("Use token") {
                    Task {
                        isSigningIn = true
                        defer { isSigningIn = false }
                        do {
                            try await app.signIn(token: personalToken.trimmingCharacters(in: .whitespacesAndNewlines))
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .disabled(personalToken.isEmpty || isSigningIn)
            }
            .font(.footnote)
        }
    #endif
}
