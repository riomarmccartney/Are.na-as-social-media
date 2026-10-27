import Foundation

/// What a composer draft turns into. One post is always exactly one block.
public enum PostKind: Sendable, Equatable {
    /// A Text block with markdown.
    case text(String)
    /// A Link block (Are.na may turn it into an Embed).
    case link(URL)
    /// An Image/Attachment block from the attached file; the composer text,
    /// if any, becomes the block description.
    case media(description: String?)
}

public enum DraftClassifier {
    /// Classifies the composer contents, or returns `nil` when there is
    /// nothing to post.
    public static func classify(text: String, hasAttachment: Bool) -> PostKind? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasAttachment {
            return .media(description: trimmed.isEmpty ? nil : trimmed)
        }
        guard !trimmed.isEmpty else { return nil }
        if let url = loneURL(in: trimmed) {
            return .link(url)
        }
        return .text(trimmed)
    }

    /// The URL when the whole text is a single http(s) link (or `www.` host).
    static func loneURL(in text: String) -> URL? {
        guard !text.contains(where: \.isWhitespace) else { return nil }
        let lowercased = text.lowercased()
        let candidate: String
        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
            candidate = text
        } else if lowercased.hasPrefix("www.") {
            candidate = "https://" + text
        } else {
            return nil
        }
        guard let url = URL(string: candidate),
              let host = url.host, host.contains("."), !host.hasPrefix("."), !host.hasSuffix(".")
        else { return nil }
        return url
    }
}
