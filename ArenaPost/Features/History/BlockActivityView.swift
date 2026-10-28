import ArenaKit
import Observation
import SwiftUI
import UIKit

/// What other people did with a block: comments, and the other channels
/// it was connected to (Are.na's closest thing to a reaction).
@MainActor
@Observable
final class BlockActivityModel {
    private(set) var comments: [ArenaKit.Comment] = []
    private(set) var totalComments = 0
    /// Other channels the block is in; the one you post to is left out.
    private(set) var connections: [Channel] = []
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var lastError: (any Error)?

    func load(client: ArenaClient, blockID: Int, excludingChannelID: Int?) async {
        errorMessage = nil
        lastError = nil
        do {
            async let comments = client.comments(onBlock: blockID)
            async let connections = client.connections(ofBlock: blockID)
            let (commentPage, connectionPage) = try await (comments, connections)
            self.comments = commentPage.data
            totalComments = commentPage.meta.totalCount
            self.connections = connectionPage.data.filter { $0.id != excludingChannelID }
        } catch {
            lastError = error
            errorMessage = error.localizedDescription
        }
        hasLoaded = true
    }

    func addComment(_ body: String, client: ArenaClient, blockID: Int) async throws {
        let comment = try await client.addComment(onBlock: blockID, body: body)
        comments.append(comment)
        totalComments += 1
    }

    func deleteComment(_ comment: ArenaKit.Comment, client: ArenaClient) async throws {
        try await client.deleteComment(id: comment.id)
        comments.removeAll { $0.id == comment.id }
        totalComments = max(0, totalComments - 1)
    }
}

/// The Comments and Connected to sections under a block.
struct BlockActivityView: View {
    let block: Block

    @Environment(AppModel.self) private var app
    @State private var model = BlockActivityModel()
    @State private var draft = ""
    @State private var isPosting = false
    @State private var postError: String?
    @State private var commentToDelete: ArenaKit.Comment?

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            ArenaSection(model.totalComments > 0 ? "Comments (\(model.totalComments))" : "Comments") {
                if !model.hasLoaded {
                    ProgressView()
                } else if let message = model.errorMessage {
                    Text(message)
                        .font(.arenaSmall)
                        .foregroundStyle(.arenaPrivate)
                } else if model.comments.isEmpty {
                    Text("No comments yet.")
                        .font(.arenaSmall)
                        .foregroundStyle(.arenaSecondary)
                }

                ForEach(model.comments) { comment in
                    CommentRow(comment: comment)
                        .contextMenu {
                            if let text = comment.body?.markdown {
                                Button {
                                    UIPasteboard.general.string = text
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                            // Only the author can delete a comment.
                            if comment.user.id == app.me?.id {
                                Button(role: .destructive) {
                                    commentToDelete = comment
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                }

                if model.totalComments > model.comments.count {
                    Link("See all comments on Are.na", destination: block.webURL)
                        .font(.arenaSmallBold)
                        .foregroundStyle(.arenaSecondary)
                }

                if block.can?.comment ?? true {
                    commentField
                }
            }

            if !model.connections.isEmpty {
                ArenaSection("Also connected to") {
                    ForEach(model.connections) { channel in
                        Link(destination: URL(string: "https://www.are.na/channel/\(channel.slug)")!) {
                            ConnectionRow(channel: channel)
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete your comment?",
            isPresented: Binding(get: { commentToDelete != nil }, set: { if !$0 { commentToDelete = nil } }),
            titleVisibility: .visible,
            presenting: commentToDelete
        ) { comment in
            Button("Delete", role: .destructive) {
                Task { await delete(comment) }
            }
        } message: { _ in
            Text("This can't be undone.")
        }
        .task(id: block.id) {
            guard let client = app.client else { return }
            await model.load(client: client, blockID: block.id, excludingChannelID: app.channel?.id)
            if let error = model.lastError { app.handle(error) }
        }
    }

    private var commentField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Add a comment", text: $draft, axis: .vertical)
                    .font(.arenaBody)
                    .foregroundStyle(.arenaBodyInk)
                    .lineLimit(1...6)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .arenaFrame()
                    .disabled(isPosting)
                Button {
                    Task { await post() }
                } label: {
                    if isPosting {
                        ProgressView()
                            .tint(.arenaOnAccent)
                    } else {
                        Text("Post")
                    }
                }
                .buttonStyle(.arenaPrimary)
                .disabled(trimmedDraft.isEmpty || isPosting)
            }
            if let postError {
                Text(postError)
                    .font(.arenaSmall)
                    .foregroundStyle(.arenaPrivate)
            }
        }
        .padding(.top, 4)
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func delete(_ comment: ArenaKit.Comment) async {
        guard let client = app.client else { return }
        do {
            try await model.deleteComment(comment, client: client)
        } catch {
            app.handle(error)
            postError = error.localizedDescription
        }
    }

    private func post() async {
        guard let client = app.client, !trimmedDraft.isEmpty else { return }
        isPosting = true
        postError = nil
        defer { isPosting = false }
        do {
            try await model.addComment(trimmedDraft, client: client, blockID: block.id)
            draft = ""
        } catch {
            app.handle(error)
            postError = error.localizedDescription
        }
    }
}

private struct CommentRow: View {
    let comment: ArenaKit.Comment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(user: comment.user, size: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.user.name)
                        .font(.arenaSmallBold)
                        .foregroundStyle(.arenaInk)
                    Text(comment.createdAt, format: .relative(presentation: .named))
                        .font(.arenaSmall)
                        .foregroundStyle(.arenaTertiary)
                }
                if let body = comment.body?.markdown {
                    MarkdownText(body)
                        .font(.arenaBody)
                        .foregroundStyle(.arenaBodyInk)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ConnectionRow: View {
    let channel: Channel

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.title)
                    .font(.arenaBodyBold)
                    .foregroundStyle(channel.visibility.color)
                    .lineLimit(1)
                if let owner = channel.owner {
                    Text("by \(owner.name)")
                        .font(.arenaSmall)
                        .foregroundStyle(.arenaSecondary)
                }
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.arenaTertiary)
        }
        .frame(minHeight: 36)
        .contentShape(Rectangle())
    }
}
