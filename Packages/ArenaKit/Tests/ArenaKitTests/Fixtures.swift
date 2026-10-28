// JSON shaped after the schemas in docs/arena/openapi.json.
enum Fixtures {
    static let user = """
        { "id": 42, "type": "User", "name": "Rio", "slug": "rio", "username": "rio",
          "avatar": "https://d2w9rnfcy7mm78.cloudfront.net/42/avatar.jpg", "initials": "R" }
        """

    static let me = """
        { "id": 42, "type": "User", "name": "Rio", "slug": "rio", "avatar": null, "initials": "R",
          "created_at": "2023-01-15T10:30:00Z", "updated_at": "2023-06-20T14:45:00Z",
          "bio": null, "badge": null, "tier": "free", "email": "rio@example.com",
          "counts": { "channels": 3 }, "_links": {} }
        """

    static func imageObject(filename: String = "IMG_4821.jpg") -> String {
        """
        { "alt_text": null, "blurhash": "LEHV6nWB2yk8", "width": 1920, "height": 1080,
          "src": "https://d2w9rnfcy7mm78.cloudfront.net/1/original.jpg", "aspect_ratio": 1.7778,
          "content_type": "image/jpeg", "filename": "\(filename)", "file_size": 1024000,
          "updated_at": "2023-01-15T14:45:00Z",
          "small": { "src": "https://cdn.example/s.jpg", "src_2x": "https://cdn.example/s@2x.jpg", "width": 160, "height": 90 },
          "medium": { "src": "https://cdn.example/m.jpg", "src_2x": "https://cdn.example/m@2x.jpg", "width": 640, "height": 360 },
          "large": { "src": "https://cdn.example/l.jpg", "src_2x": "https://cdn.example/l@2x.jpg", "width": 1280, "height": 720 },
          "square": { "src": "https://cdn.example/q.jpg", "src_2x": "https://cdn.example/q@2x.jpg", "width": 320, "height": 320 } }
        """
    }

    static func block(id: Int, type: String, extra: String, state: String = "available", commentCount: Int = 0) -> String {
        """
        { "id": \(id), "base_type": "Block", "type": "\(type)", "title": "Title \(id)",
          "description": { "markdown": "desc **\(id)**", "html": "<p>desc</p>", "plain": "desc" },
          "state": "\(state)", "visibility": "public", "comment_count": \(commentCount),
          "created_at": "2026-10-27T10:30:00.123Z", "updated_at": "2026-10-27T10:30:00Z",
          "user": \(user), "metadata": null, "source": null, "_links": {},
          "connection": { "id": \(id + 1000), "position": 1, "pinned": false, "metadata": null,
                          "connected_at": "2026-10-27T10:30:00Z", "connected_by": \(user) }
          \(extra.isEmpty ? "" : ", " + extra) }
        """
    }

    static let textBlock = block(
        id: 1, type: "Text",
        extra: """
            "content": { "markdown": "hello **world**", "html": "<p>hello</p>", "plain": "hello world" }
            """)

    static let imageBlock = block(id: 2, type: "Image", extra: "\"image\": \(imageObject())")

    static let linkBlock = block(
        id: 3, type: "Link",
        extra: """
            "image": null, "content": null
            """
    ).replacingOccurrences(
        of: "\"source\": null",
        with: "\"source\": { \"url\": \"https://example.com/article\", \"title\": \"Article\", \"provider\": null }"
    )

    static let videoAttachmentBlock = block(
        id: 4, type: "Attachment",
        extra: """
            "attachment": { "filename": "trip.mp4", "content_type": "video/mp4", "file_size": 2048000,
                            "file_extension": "mp4", "updated_at": null, "url": "https://attachments.are.na/4/trip.mp4" },
            "image": null
            """)

    static let embedBlock = block(
        id: 5, type: "Embed",
        extra: """
            "embed": { "url": "https://www.youtube.com/embed/abc", "type": "youtube", "title": "Video",
                       "author_name": null, "author_url": null, "source_url": "https://www.youtube.com/watch?v=abc",
                       "width": 640, "height": 480, "html": "<iframe></iframe>", "thumbnail_url": "https://example.com/t.jpg" },
            "image": null
            """)

    static let pendingBlock = block(id: 6, type: "PendingBlock", extra: "", state: "processing")

    static let commentedBlock = block(
        id: 7, type: "Text",
        extra: """
            "can": { "manage": false, "comment": true, "connect": true },
            "content": { "markdown": "hi", "html": "<p>hi</p>", "plain": "hi" }
            """,
        commentCount: 3)

    static let comment = """
        { "id": 12345, "type": "Comment",
          "body": { "markdown": "Love this @rio", "html": "<p>Love this</p>", "plain": "Love this" },
          "created_at": "2026-10-27T11:00:00Z", "updated_at": "2026-10-27T11:00:00Z",
          "user": \(user), "_links": {} }
        """

    static let channel = """
        { "id": 123, "type": "Channel", "slug": "my-feed-abc", "title": "my feed",
          "description": null, "state": "available", "visibility": "closed",
          "created_at": "2023-01-15T10:30:00Z", "updated_at": "2023-01-15T14:45:00Z", "metadata": null,
          "owner": \(user),
          "counts": { "blocks": 42, "channels": 0, "contents": 42, "collaborators": 0 },
          "_links": {}, "can": { "add_to": true, "update": true, "destroy": true, "manage_collaborators": true } }
        """

    static func page(_ items: [String], nextPage: Int? = 2, hasMore: Bool = true) -> String {
        """
        { "data": [\(items.joined(separator: ","))],
          "meta": { "current_page": 1, "next_page": \(nextPage.map(String.init) ?? "null"), "prev_page": null,
                    "per_page": 24, "total_pages": 2, "total_count": 30, "has_more_pages": \(hasMore) } }
        """
    }
}
