import SwiftUI

@main
struct ArenaPostApp: App {
    @State private var app = AppModel()

    init() {
        // Prepared attachments aren't kept between launches.
        MediaPreparer.removeAllWorkFiles()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
        }
    }
}
