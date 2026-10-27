import Foundation

public enum ChannelLink {
    /// Extracts a channel slug from what a user pastes: a channel URL
    /// (`https://www.are.na/<user>/<slug>`, with or without scheme/`www.`),
    /// or a bare slug. Returns `nil` for anything else.
    public static func slug(from input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace) else { return nil }

        let lowercased = text.lowercased()
        if !lowercased.hasPrefix("http://"), !lowercased.hasPrefix("https://"),
           lowercased.hasPrefix("are.na/") || lowercased.hasPrefix("www.are.na/") {
            text = "https://" + text
        }

        if let url = URL(string: text), let host = url.host?.lowercased() {
            guard host == "are.na" || host == "www.are.na" else { return nil }
            let parts = url.path.split(separator: "/").map(String.init)
            // /<user>/<slug> or /channel/<slug>
            guard parts.count == 2 else { return nil }
            return validSlug(parts[1])
        }
        return validSlug(text)
    }

    private static func validSlug(_ candidate: String) -> String? {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        guard !candidate.isEmpty, candidate.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return candidate
    }
}
