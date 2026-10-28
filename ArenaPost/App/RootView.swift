import SwiftUI

/// Gates the app: nothing is reachable before signing in, and a channel has
/// to be chosen before the composer appears.
struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            switch app.phase {
            case .launching:
                ProgressView()
            case .signedOut:
                LoginView()
            case .needsChannel:
                NavigationStack {
                    ChannelPickerView(isOnboarding: true)
                }
            case .ready:
                ComposerView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.arenaBackground)
        .animation(.default, value: app.phase)
        .task {
            await app.bootstrap()
        }
    }
}
