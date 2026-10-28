import SwiftUI
import UIKit

/// The attached file under the composer text, with its name (the future
/// block title) and a remove button.
struct AttachmentPreview: View {
    let attachment: PreparedAttachment
    let onRemove: () -> Void

    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                content
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.arena)
                .padding(8)
                .accessibilityLabel("Remove attachment")
            }

            Label(attachment.filename, systemImage: symbol)
                .font(.arenaSmall)
                .foregroundStyle(.arenaSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityLabel("Title: \(attachment.filename)")
        }
        .onChange(of: attachment.previewURL, initial: true) { _, url in
            // Previews are at most 4096 px JPEGs, so decoding once here is cheap.
            image = url.flatMap { UIImage(contentsOfFile: $0.path)?.preparingThumbnail(of: CGSize(width: 1200, height: 1200)) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch attachment.kind {
        case .image, .video:
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 380)
                    .overlay(alignment: .bottomLeading) {
                        if attachment.kind == .video {
                            videoBadge.padding(10)
                        }
                    }
            } else {
                Rectangle()
                    .fill(.arenaFill)
                    .frame(height: 220)
                    .overlay { Image(systemName: symbol).font(.largeTitle.weight(.light)).foregroundStyle(.arenaTertiary) }
            }
        case .file:
            HStack(spacing: 12) {
                Image(systemName: "doc")
                    .font(.title2.weight(.light))
                    .foregroundStyle(.arenaSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.filename)
                        .font(.arenaBody)
                        .foregroundStyle(.arenaInk)
                        .lineLimit(1)
                    if let size = attachment.fileSize {
                        Text(Int64(size).formatted(.byteCount(style: .file)))
                            .font(.arenaSmall)
                            .foregroundStyle(.arenaSecondary)
                    }
                }
                Spacer(minLength: 44)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .arenaFrame()
        }
    }

    private var videoBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "play.fill")
            if let duration = attachment.duration, duration.isFinite {
                Text(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))
            }
        }
        .font(.arenaSmallBold)
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 3))
    }

    private var symbol: String {
        switch attachment.kind {
        case .image: "photo"
        case .video: "video"
        case .file: "doc"
        }
    }
}
