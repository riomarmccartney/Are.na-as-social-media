import ArenaKit
import BackgroundTasks
import Foundation
import UserNotifications

/// Notifies you when someone comments on one of your posts.
///
/// Are.na has no push notifications, so the app looks for new comments on
/// your recent blocks during background app refresh and posts a local
/// notification. iOS decides when that runs (often every hour or so, less
/// when the battery is low, never after you swipe the app away).
@MainActor
enum CommentNotifier {
    static let taskID = "studio.upcoming.arenapost.comments"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: PreferenceKey.commentNotifications) as? Bool ?? true
    }

    /// Asks once; later calls return the answer already given.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
        return await center.notificationSettings().authorizationStatus == .authorized
    }

    /// Asks iOS to wake the app again in a while.
    static func scheduleNextCheck() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = .now.addingTimeInterval(20 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Compares comment counts on your latest blocks in the channel with the
    /// last check. With `notify` off it only records them, so comments you
    /// can already see in the app aren't announced later.
    static func check(client: ArenaClient, me: User, channelID: Int, notify: Bool) async {
        guard isEnabled else { return }
        guard let page = try? await client.channelContents(channelID: channelID, userID: me.id) else { return }

        let key = "notifications.commentCounts.\(channelID)"
        let previous = UserDefaults.standard.dictionary(forKey: key) as? [String: Int]
        var counts: [String: Int] = [:]

        for block in page.data.compactMap(\.block) {
            let count = block.commentCount ?? 0
            counts[String(block.id)] = count
            // Nothing to compare against on the first check.
            guard notify, let previous, let before = previous[String(block.id)], count > before else { continue }
            let newComments = try? await client.comments(onBlock: block.id, newestFirst: true, per: min(count - before, 10))
            for comment in newComments?.data.reversed() ?? [] where comment.user.id != me.id {
                await post(comment, on: block)
            }
        }
        UserDefaults.standard.set(counts, forKey: key)
    }

    private static func post(_ comment: ArenaKit.Comment, on block: Block) async {
        let content = UNMutableNotificationContent()
        content.title = "\(comment.user.name) commented"
        if let title = block.title, !title.isEmpty {
            content.subtitle = title
        }
        content.body = comment.body?.plain ?? comment.body?.markdown ?? ""
        content.sound = .default
        content.threadIdentifier = "block-\(block.id)"
        let request = UNNotificationRequest(identifier: "comment-\(comment.id)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
