import AVFoundation
import ArenaKit
import ImageIO
import UniformTypeIdentifiers

/// A file prepared for upload. `filename` is both the name on disk and the
/// block title.
struct PreparedAttachment: Identifiable, Equatable, Sendable {
    enum Kind: Sendable {
        case image
        case video
        case file
    }

    let id = UUID()
    let kind: Kind
    let fileURL: URL
    let contentType: String
    let previewURL: URL?
    let duration: TimeInterval?
    let fileSize: Int?

    var filename: String { fileURL.lastPathComponent }

    var uploadFile: UploadFile {
        UploadFile(fileURL: fileURL, filename: filename, contentType: contentType)
    }

    /// The per-attachment work directory, deleted once the post is done.
    var directory: URL { fileURL.deletingLastPathComponent() }
}

enum MediaError: LocalizedError {
    case unreadable
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .unreadable: "Couldn't read that file."
        case .exportFailed: "Couldn't prepare that video."
        }
    }
}

/// Converts picked media into upload-ready files, off the main actor.
enum MediaPreparer {
    private static let maxImagePixelSize = 4096

    // MARK: Images

    /// Re-encodes to JPEG (max 4096 px, orientation applied). GIFs are kept
    /// as-is so they stay animated.
    @concurrent
    static func prepareImage(data: Data, originalFilename: String?, stripLocation: Bool) async throws -> PreparedAttachment {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let sourceType = CGImageSourceGetType(source) as String?
        else { throw MediaError.unreadable }

        let directory = try makeWorkDirectory()

        if UTType(sourceType)?.conforms(to: .gif) == true {
            let url = directory.appendingPathComponent(
                AttachmentNaming.uploadFilename(originalFilename: originalFilename, fileExtension: "gif")
            )
            try data.write(to: url)
            return attachment(.image, at: url, contentType: "image/gif", preview: url)
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxImagePixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw MediaError.unreadable
        }

        var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
        // The pixels are already rotated, and the size may have changed.
        properties[kCGImagePropertyOrientation] = 1
        properties[kCGImagePropertyPixelWidth] = nil
        properties[kCGImagePropertyPixelHeight] = nil
        if var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = 1
            properties[kCGImagePropertyTIFFDictionary] = tiff
        }
        if stripLocation {
            properties[kCGImagePropertyGPSDictionary] = nil
        }
        properties[kCGImageDestinationLossyCompressionQuality] = 0.9

        let url = directory.appendingPathComponent(
            AttachmentNaming.uploadFilename(originalFilename: originalFilename, fileExtension: "jpg")
        )
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw MediaError.unreadable
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw MediaError.unreadable }

        return attachment(.image, at: url, contentType: "image/jpeg", preview: url)
    }

    // MARK: Videos

    /// Exports to MP4 at the chosen quality and makes a poster frame.
    @concurrent
    static func prepareVideo(
        at sourceURL: URL,
        originalFilename: String?,
        quality: VideoQuality,
        stripLocation: Bool
    ) async throws -> PreparedAttachment {
        defer { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }

        let asset = AVURLAsset(url: sourceURL)
        guard let session = AVAssetExportSession(asset: asset, presetName: quality.exportPreset) else {
            throw MediaError.exportFailed
        }
        session.shouldOptimizeForNetworkUse = true
        if stripLocation {
            session.metadataItemFilter = .forSharing()
        }

        let directory = try makeWorkDirectory()
        let url = directory.appendingPathComponent(
            AttachmentNaming.uploadFilename(originalFilename: originalFilename, fileExtension: "mp4")
        )
        do {
            try await session.export(to: url, as: .mp4)
        } catch {
            throw MediaError.exportFailed
        }

        let exported = AVURLAsset(url: url)
        let duration = try? await exported.load(.duration).seconds
        let preview = try? await posterFrame(for: exported)
        return attachment(.video, at: url, contentType: "video/mp4", preview: preview, duration: duration)
    }

    private static func posterFrame(for asset: AVURLAsset) async throws -> URL {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1200, height: 1200)
        let (image, _) = try await generator.image(at: .zero)

        let url = try makePreviewDirectory().appendingPathComponent("\(UUID().uuidString).jpg")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw MediaError.unreadable
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw MediaError.unreadable }
        return url
    }

    // MARK: Files

    /// Copies a file from the Files app, keeping its name.
    @concurrent
    static func prepareFile(at sourceURL: URL) async throws -> PreparedAttachment {
        let isScoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if isScoped { sourceURL.stopAccessingSecurityScopedResource() } }

        let ext = sourceURL.pathExtension
        let url = try makeWorkDirectory().appendingPathComponent(
            AttachmentNaming.uploadFilename(originalFilename: sourceURL.lastPathComponent, fileExtension: ext)
        )
        try FileManager.default.copyItem(at: sourceURL, to: url)

        let type = UTType(filenameExtension: ext)
        let contentType = type?.preferredMIMEType ?? MIMEType.forFileExtension(ext)
        if type?.conforms(to: .image) == true {
            return attachment(.image, at: url, contentType: contentType, preview: url)
        }
        return attachment(.file, at: url, contentType: contentType, preview: nil)
    }

    // MARK: Work directories

    private static var uploadsRoot: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Uploads", isDirectory: true)
    }

    /// A fresh `tmp/Uploads/<uuid>/` directory for one attachment.
    static func makeWorkDirectory() throws -> URL {
        let url = uploadsRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func makePreviewDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Previews", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func discard(_ attachment: PreparedAttachment) {
        try? FileManager.default.removeItem(at: attachment.directory)
        if let previewURL = attachment.previewURL, previewURL != attachment.fileURL {
            try? FileManager.default.removeItem(at: previewURL)
        }
    }

    /// Removes leftovers from earlier launches.
    static func removeAllWorkFiles() {
        try? FileManager.default.removeItem(at: uploadsRoot)
        try? FileManager.default.removeItem(
            at: FileManager.default.temporaryDirectory.appendingPathComponent("Previews", isDirectory: true)
        )
    }

    private static func attachment(
        _ kind: PreparedAttachment.Kind,
        at url: URL,
        contentType: String,
        preview: URL?,
        duration: TimeInterval? = nil
    ) -> PreparedAttachment {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        return PreparedAttachment(
            kind: kind,
            fileURL: url,
            contentType: contentType,
            previewURL: preview,
            duration: duration,
            fileSize: size
        )
    }
}
