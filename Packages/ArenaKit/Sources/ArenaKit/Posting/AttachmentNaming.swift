import Foundation

/// Picks the file name an attachment is uploaded with. That name is also the
/// block's title, so it has to match the file that is actually uploaded.
public enum AttachmentNaming {
    /// - Parameters:
    ///   - originalFilename: The name from Files/Photos, if known (e.g. `IMG_4821.HEIC`).
    ///   - fileExtension: The extension of the file being uploaded, after any
    ///     conversion (e.g. `jpg` for a HEIC converted to JPEG).
    ///   - date: Used for the fallback name when there is no original name.
    public static func uploadFilename(
        originalFilename: String?,
        fileExtension: String,
        date: Date = .now,
        timeZone: TimeZone = .current
    ) -> String {
        let ext = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        let base = originalFilename.map(baseName(of:)).flatMap(sanitized) ?? fallbackBaseName(date: date, timeZone: timeZone)
        return ext.isEmpty ? base : "\(base).\(ext)"
    }

    /// `IMG_20261027_143205` — used for camera captures and unknown names.
    public static func fallbackBaseName(date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        func pad(_ value: Int?, _ width: Int = 2) -> String {
            let string = String(value ?? 0)
            return String(repeating: "0", count: max(0, width - string.count)) + string
        }
        return "IMG_\(pad(c.year, 4))\(pad(c.month))\(pad(c.day))_\(pad(c.hour))\(pad(c.minute))\(pad(c.second))"
    }

    private static func baseName(of filename: String) -> String {
        let name = (filename as NSString).lastPathComponent
        let stripped = (name as NSString).deletingPathExtension
        return stripped.isEmpty ? name : stripped
    }

    /// Removes characters that are unsafe in a file name; `nil` if nothing is left.
    private static func sanitized(_ base: String) -> String? {
        let unsafe = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.controlCharacters).union(.newlines)
        let cleaned = base.unicodeScalars.map { unsafe.contains($0) ? "_" : String($0) }.joined()
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty || cleaned.allSatisfy({ $0 == "_" || $0 == "." }) ? nil : cleaned
    }
}

/// MIME types for the files the app uploads.
public enum MIMEType {
    public static func forFileExtension(_ fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "jpg", "jpeg": "image/jpeg"
        case "png": "image/png"
        case "gif": "image/gif"
        case "webp": "image/webp"
        case "heic": "image/heic"
        case "heif": "image/heif"
        case "tif", "tiff": "image/tiff"
        case "svg": "image/svg+xml"
        case "mp4", "m4v": "video/mp4"
        case "mov": "video/quicktime"
        case "webm": "video/webm"
        case "mp3": "audio/mpeg"
        case "m4a": "audio/mp4"
        case "aac": "audio/aac"
        case "wav": "audio/wav"
        case "pdf": "application/pdf"
        case "txt", "md": "text/plain"
        case "csv": "text/csv"
        case "json": "application/json"
        case "zip": "application/zip"
        case "epub": "application/epub+zip"
        default: "application/octet-stream"
        }
    }
}
