import SwiftUI

@main
struct ArenaPostApp: App {
    @State private var app = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Prepared attachments aren't kept between launches.
        MediaPreparer.removeAllWorkFiles()
        ArenaAppearance.apply()
    }

    var body: some Scene {
        let app = app
        WindowGroup {
            RootView()
                .environment(app)
                .font(.arenaBody)
                .tint(.arenaInk)
                .onOpenURL { url in
                    if let link = ComposeLink(url: url) {
                        app.composeLink = link
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                CommentNotifier.scheduleNextCheck()
            case .active:
                // Comments you can see in the app don't need a notification.
                Task { await app.checkForNewComments(notify: false) }
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(CommentNotifier.taskID)) {
            await CommentNotifier.scheduleNextCheck()
            await app.checkForNewComments(notify: true)
        }
    }
}
