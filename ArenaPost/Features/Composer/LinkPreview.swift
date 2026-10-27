@preconcurrency import LinkPresentation
import SwiftUI

/// What Are.na will scrape when the post is a lone URL.
struct LinkPreview: View {
    let url: URL

    @State private var metadata: LPLinkMetadata?

    var body: some View {
        Group {
            if let metadata {
                LinkMetadataView(metadata: metadata)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                    Text(url.host() ?? url.absoluteString)
                        .lineLimit(1)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .task(id: url) {
            metadata = nil
            // Wait for typing to pause before fetching.
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            metadata = try? await LPMetadataProvider().startFetchingMetadata(for: url)
        }
    }
}

private struct LinkMetadataView: UIViewRepresentable {
    let metadata: LPLinkMetadata

    func makeUIView(context: Context) -> LPLinkView {
        LPLinkView(metadata: metadata)
    }

    func updateUIView(_ view: LPLinkView, context: Context) {
        view.metadata = metadata
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: LPLinkView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }
}
