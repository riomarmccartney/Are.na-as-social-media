import Foundation

/// A file on disk, ready to upload. Its file name becomes the block title.
public struct UploadFile: Sendable, Equatable {
    public let fileURL: URL
    public let filename: String
    public let contentType: String

    public init(fileURL: URL, filename: String, contentType: String) {
        self.fileURL = fileURL
        self.filename = filename
        self.contentType = contentType
    }
}

public enum PostProgress: Sendable, Equatable {
    case uploading(fraction: Double)
    case creatingBlock
}

/// Turns a composer draft into one block in one channel.
public struct PostService: Sendable {
    public let client: ArenaClient

    public init(client: ArenaClient) {
        self.client = client
    }

    /// Posts the draft. Returns `nil` only when there is nothing to post.
    ///
    /// - Text → Text block; a lone URL → Link block.
    /// - Attachment → presign, upload to S3, then create the block with the
    ///   file name as `title` and the composer text as `description`.
    @discardableResult
    public func post(
        text: String,
        attachment: UploadFile?,
        channelID: Int,
        progress: @escaping @Sendable (PostProgress) -> Void = { _ in }
    ) async throws -> Block? {
        guard let kind = DraftClassifier.classify(text: text, hasAttachment: attachment != nil) else {
            return nil
        }

        let newBlock: NewBlock
        switch kind {
        case .text(let markdown):
            newBlock = NewBlock(value: markdown, channelID: channelID)
        case .link(let url):
            newBlock = NewBlock(value: url.absoluteString, channelID: channelID)
        case .media(let description):
            guard let attachment else { return nil }
            progress(.uploading(fraction: 0))
            let presigned = try await client.presignUpload(filename: attachment.filename, contentType: attachment.contentType)
            try await client.upload(fileAt: attachment.fileURL, to: presigned) { fraction in
                progress(.uploading(fraction: fraction))
            }
            newBlock = NewBlock(
                value: presigned.blockValue,
                title: attachment.filename,
                description: description,
                channelID: channelID
            )
        }

        try Task.checkCancellation()
        progress(.creatingBlock)
        return try await client.createBlock(newBlock)
    }
}
