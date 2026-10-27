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
                        .padding(8)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .padding(8)
                .accessibilityLabel("Remove attachment")
            }

            Label(attachment.filename, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
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
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .bottomLeading) {
                        if attachment.kind == .video {
                            videoBadge.padding(10)
                        }
                    }
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.quaternary)
                    .frame(height: 220)
                    .overlay { Image(systemName: symbol).font(.largeTitle).foregroundStyle(.secondary) }
            }
        case .file:
            HStack(spacing: 12) {
                Image(systemName: "doc")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.filename)
                        .lineLimit(1)
                    if let size = attachment.fileSize {
                        Text(Int64(size).formatted(.byteCount(style: .file)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 44)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var videoBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "play.fill")
            if let duration = attachment.duration, duration.isFinite {
                Text(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.55), in: Capsule())
    }

    private var symbol: String {
        switch attachment.kind {
        case .image: "photo"
        case .video: "video"
        case .file: "doc"
        }
    }
}
