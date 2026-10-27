import ArenaKit
import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
@Observable
final class ComposerModel {
    enum Phase: Equatable {
        case idle
        /// `nil` while waiting for Are.na, otherwise upload progress 0...1.
        case posting(progress: Double?)
    }

    var text: String
    private(set) var attachment: PreparedAttachment?
    private(set) var isPreparingAttachment = false
    private(set) var phase: Phase = .idle
    var toast: Toast?
    /// Increments after each successful post (drives the success haptic).
    private(set) var postCount = 0

    private var postTask: Task<Void, Never>?

    init(draft: String = "") {
        text = draft
    }

    var kind: PostKind? {
        DraftClassifier.classify(text: text, hasAttachment: attachment != nil)
    }

    var isBusy: Bool {
        isPreparingAttachment || phase != .idle
    }

    var canPost: Bool {
        !isBusy && kind != nil
    }

    var canAttach: Bool {
        !isBusy && attachment == nil
    }

    /// The URL to preview when the post will become a Link block.
    var linkURL: URL? {
        if case .link(let url) = kind { return url }
        return nil
    }

    // MARK: Attaching

    func attach(_ item: PhotosPickerItem, stripLocation: Bool, videoQuality: VideoQuality) async {
        await prepare {
            let originalName = await PhotoLibraryNames.originalFilename(for: item.itemIdentifier)
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                guard let movie = try await item.loadTransferable(type: PickedMovie.self) else { throw MediaError.unreadable }
                return try await MediaPreparer.prepareVideo(
                    at: movie.url,
                    originalFilename: originalName,
                    quality: videoQuality,
                    stripLocation: stripLocation
                )
            }
            guard let data = try await item.loadTransferable(type: Data.self) else { throw MediaError.unreadable }
            return try await MediaPreparer.prepareImage(data: data, originalFilename: originalName, stripLocation: stripLocation)
        }
    }

    func attach(_ capture: CameraPicker.Capture, stripLocation: Bool, videoQuality: VideoQuality) async {
        await prepare {
            switch capture {
            case .photo(let image):
                guard let data = image.jpegData(compressionQuality: 0.95) else { throw MediaError.unreadable }
                return try await MediaPreparer.prepareImage(data: data, originalFilename: nil, stripLocation: stripLocation)
            case .movie(let url):
                return try await MediaPreparer.prepareVideo(
                    at: url,
                    originalFilename: nil,
                    quality: videoQuality,
                    stripLocation: stripLocation
                )
            }
        }
    }

    func attachFile(at url: URL) async {
        await prepare {
            try await MediaPreparer.prepareFile(at: url)
        }
    }

    func removeAttachment() {
        if let attachment {
            MediaPreparer.discard(attachment)
        }
        attachment = nil
    }

    /// Puts a pasted link into the composer (as the whole text when empty).
    func insertLink(_ string: String) {
        let link = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty else { return }
        text = text.isEmpty ? link : text + (text.hasSuffix(" ") || text.hasSuffix("\n") ? "" : " ") + link
    }

    private func prepare(_ work: () async throws -> PreparedAttachment) async {
        guard canAttach else { return }
        isPreparingAttachment = true
        defer { isPreparingAttachment = false }
        do {
            attachment = try await work()
        } catch {
            toast = .failure(error.localizedDescription)
        }
    }

    // MARK: Posting

    func post(client: ArenaClient, channel: ChannelRef, onUnauthorized: @escaping @MainActor () -> Void) {
        guard canPost else { return }
        phase = .posting(progress: nil)
        let text = text
        let upload = attachment?.uploadFile

        postTask = Task {
            do {
                try await PostService(client: client).post(text: text, attachment: upload, channelID: channel.id) { progress in
                    Task { @MainActor [weak self] in self?.apply(progress) }
                }
                finishPost(channel: channel)
            } catch is CancellationError {
                phase = .idle
            } catch {
                phase = .idle
                if case ArenaError.unauthorized = error {
                    onUnauthorized()
                } else {
                    toast = .failure(error.localizedDescription, action: "Retry")
                }
            }
        }
    }

    func cancelPost() {
        postTask?.cancel()
    }

    private func apply(_ progress: PostProgress) {
        guard case .posting = phase else { return }
        switch progress {
        case .uploading(let fraction): phase = .posting(progress: fraction)
        case .creatingBlock: phase = .posting(progress: nil)
        }
    }

    private func finishPost(channel: ChannelRef) {
        removeAttachment()
        text = ""
        phase = .idle
        postCount += 1
        toast = .success("Posted to \(channel.title)", action: "View")
    }
}
