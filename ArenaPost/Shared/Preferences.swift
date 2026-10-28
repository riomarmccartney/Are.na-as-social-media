import AVFoundation

enum PreferenceKey {
    static let stripLocation = "posting.stripLocation"
    static let videoQuality = "posting.videoQuality"
    static let draft = "composer.draft"
    static let historyColumns = "history.columns"
    static let commentNotifications = "notifications.comments"
    static let storyOnPost = "composer.storyOnPost"
}

enum VideoQuality: String, CaseIterable, Identifiable, Sendable {
    case original
    case high
    case compact

    var id: Self { self }

    var title: String {
        switch self {
        case .original: "Original"
        case .high: "High (1080p)"
        case .compact: "Compact (720p)"
        }
    }

    var exportPreset: String {
        switch self {
        case .original: AVAssetExportPresetPassthrough
        case .high: AVAssetExportPreset1920x1080
        case .compact: AVAssetExportPreset1280x720
        }
    }
}
