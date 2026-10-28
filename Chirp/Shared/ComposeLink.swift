import Foundation

/// `arenapost://compose[/photo|/camera]`: opens the composer, optionally
/// straight into the photo library or camera. Used by the widgets.
enum ComposeLink: String, CaseIterable, Sendable {
    case write
    case photo
    case camera

    var url: URL {
        switch self {
        case .write: URL(string: "arenapost://compose")!
        case .photo: URL(string: "arenapost://compose/photo")!
        case .camera: URL(string: "arenapost://compose/camera")!
        }
    }

    init?(url: URL) {
        guard url.scheme == "arenapost", url.host() == "compose" else { return nil }
        switch url.pathComponents.dropFirst().first {
        case nil: self = .write
        case "photo": self = .photo
        case "camera": self = .camera
        default: return nil
        }
    }
}
