# Are.na

Are.na is a platform for connecting ideas and building knowledge. Users collect content — images, text, links, files — into channels, building personal and collaborative knowledge networks.

- Website: https://www.are.na

## Are.na API — Compact Reference

Version: 3.0.0
This document covers the Are.na developer API. It does not describe the full website.
OpenAPI: https://api.are.na/v3/openapi.json
Explorer: https://www.are.na/developers/explore

## Endpoints

### Authentication
- POST /v3/oauth/token | docs: https://www.are.na/developers/explore/authentication/post-token | markdown: https://www.are.na/developers/explore/authentication/post-token.md | params: none

### Block
- GET /v3/blocks/{id} | docs: https://www.are.na/developers/explore/block | markdown: https://www.are.na/developers/explore/block.md | params: path.id*
- GET /v3/blocks/batch/{batch_id} | docs: https://www.are.na/developers/explore/block/{batch_id} | markdown: https://www.are.na/developers/explore/block/{batch_id}.md | params: path.batch_id*
- GET /v3/blocks/{id}/comments | docs: https://www.are.na/developers/explore/block/comments | markdown: https://www.are.na/developers/explore/block/comments.md | params: path.id*, query.page, query.per, query.sort
- GET /v3/blocks/{id}/connections | docs: https://www.are.na/developers/explore/block/connections | markdown: https://www.are.na/developers/explore/block/connections.md | params: path.id*, query.page, query.per, query.sort, query.filter
- POST /v3/blocks/batch | docs: https://www.are.na/developers/explore/block/post-batch | markdown: https://www.are.na/developers/explore/block/post-batch.md | params: none
- POST /v3/blocks | docs: https://www.are.na/developers/explore/block/post-block | markdown: https://www.are.na/developers/explore/block/post-block.md | params: none
- POST /v3/blocks/{id}/comments | docs: https://www.are.na/developers/explore/block/post-comments | markdown: https://www.are.na/developers/explore/block/post-comments.md | params: path.id*
- PUT /v3/blocks/{id} | docs: https://www.are.na/developers/explore/block/put-block | markdown: https://www.are.na/developers/explore/block/put-block.md | params: path.id*

### Channel
- GET /v3/channels/{id} | docs: https://www.are.na/developers/explore/channel | markdown: https://www.are.na/developers/explore/channel.md | params: path.id*
- GET /v3/channels/{id}/connections | docs: https://www.are.na/developers/explore/channel/connections | markdown: https://www.are.na/developers/explore/channel/connections.md | params: path.id*, query.page, query.per, query.sort
- GET /v3/channels/{id}/contents | docs: https://www.are.na/developers/explore/channel/contents | markdown: https://www.are.na/developers/explore/channel/contents.md | params: path.id*, query.page, query.per, query.sort, query.user_id
- GET /v3/channels/{id}/followers | docs: https://www.are.na/developers/explore/channel/followers | markdown: https://www.are.na/developers/explore/channel/followers.md | params: path.id*, query.page, query.per, query.sort
- POST /v3/channels | docs: https://www.are.na/developers/explore/channel/post-channel | markdown: https://www.are.na/developers/explore/channel/post-channel.md | params: none
- PUT /v3/channels/{id} | docs: https://www.are.na/developers/explore/channel/put-channel | markdown: https://www.are.na/developers/explore/channel/put-channel.md | params: path.id*
- DELETE /v3/channels/{id} | docs: https://www.are.na/developers/explore/channel/delete-channel | markdown: https://www.are.na/developers/explore/channel/delete-channel.md | params: path.id*

### Comment
- DELETE /v3/comments/{id} | docs: https://www.are.na/developers/explore/comment/delete-comment | markdown: https://www.are.na/developers/explore/comment/delete-comment.md | params: path.id*

### Connection
- GET /v3/connections/{id} | docs: https://www.are.na/developers/explore/connection | markdown: https://www.are.na/developers/explore/connection.md | params: path.id*
- POST /v3/connections | docs: https://www.are.na/developers/explore/connection/post-connection | markdown: https://www.are.na/developers/explore/connection/post-connection.md | params: none
- POST /v3/connections/{id}/move | docs: https://www.are.na/developers/explore/connection/post-move | markdown: https://www.are.na/developers/explore/connection/post-move.md | params: path.id*
- PUT /v3/connections/{id} | docs: https://www.are.na/developers/explore/connection/put-connection | markdown: https://www.are.na/developers/explore/connection/put-connection.md | params: path.id*
- DELETE /v3/connections/{id} | docs: https://www.are.na/developers/explore/connection/delete-connection | markdown: https://www.are.na/developers/explore/connection/delete-connection.md | params: path.id*

### Feed
- GET /v3/me/feed | docs: https://www.are.na/developers/explore/feed | markdown: https://www.are.na/developers/explore/feed.md | params: query.limit, query.next, query.prev
- GET /v3/me/notifications | docs: https://www.are.na/developers/explore/feed/notifications | markdown: https://www.are.na/developers/explore/feed/notifications.md | params: query.limit, query.next, query.prev, query.unread
- POST /v3/me/notifications/read | docs: https://www.are.na/developers/explore/feed/post-read | markdown: https://www.are.na/developers/explore/feed/post-read.md | params: none
- POST /v3/me/notifications/{id}/read | docs: https://www.are.na/developers/explore/feed/post-read-by-id | markdown: https://www.are.na/developers/explore/feed/post-read-by-id.md | params: path.id*

### Group
- GET /v3/groups/{id} | docs: https://www.are.na/developers/explore/group | markdown: https://www.are.na/developers/explore/group.md | params: path.id*
- GET /v3/groups/{id}/contents | docs: https://www.are.na/developers/explore/group/contents | markdown: https://www.are.na/developers/explore/group/contents.md | params: path.id*, query.page, query.per, query.sort, query.type
- GET /v3/groups/{id}/followers | docs: https://www.are.na/developers/explore/group/followers | markdown: https://www.are.na/developers/explore/group/followers.md | params: path.id*, query.page, query.per, query.sort
- GET /v3/groups/{id}/invitations | docs: https://www.are.na/developers/explore/group/invitations | markdown: https://www.are.na/developers/explore/group/invitations.md | params: path.id*, query.page, query.per
- GET /v3/groups/{id}/invite | docs: https://www.are.na/developers/explore/group/invite | markdown: https://www.are.na/developers/explore/group/invite.md | params: path.id*
- GET /v3/groups/{id}/members | docs: https://www.are.na/developers/explore/group/members | markdown: https://www.are.na/developers/explore/group/members.md | params: path.id*, query.page, query.per
- POST /v3/groups | docs: https://www.are.na/developers/explore/group/post-group | markdown: https://www.are.na/developers/explore/group/post-group.md | params: none
- POST /v3/groups/{id}/invitations | docs: https://www.are.na/developers/explore/group/post-invitations | markdown: https://www.are.na/developers/explore/group/post-invitations.md | params: path.id*
- POST /v3/groups/{id}/invite | docs: https://www.are.na/developers/explore/group/post-invite | markdown: https://www.are.na/developers/explore/group/post-invite.md | params: path.id*
- POST /v3/groups/{id}/members | docs: https://www.are.na/developers/explore/group/post-members | markdown: https://www.are.na/developers/explore/group/post-members.md | params: path.id*
- PUT /v3/groups/{id} | docs: https://www.are.na/developers/explore/group/put-group | markdown: https://www.are.na/developers/explore/group/put-group.md | params: path.id*
- DELETE /v3/groups/{id}/invitations/{invitation_id} | docs: https://www.are.na/developers/explore/group/delete-{invitation_id} | markdown: https://www.are.na/developers/explore/group/delete-{invitation_id}.md | params: path.id*, path.invitation_id*
- DELETE /v3/groups/{id}/members/{user_id} | docs: https://www.are.na/developers/explore/group/delete-{user_id} | markdown: https://www.are.na/developers/explore/group/delete-{user_id}.md | params: path.id*, path.user_id*
- DELETE /v3/groups/{id} | docs: https://www.are.na/developers/explore/group/delete-group | markdown: https://www.are.na/developers/explore/group/delete-group.md | params: path.id*
- DELETE /v3/groups/{id}/invite | docs: https://www.are.na/developers/explore/group/delete-invite | markdown: https://www.are.na/developers/explore/group/delete-invite.md | params: path.id*
- DELETE /v3/groups/{id}/members/me | docs: https://www.are.na/developers/explore/group/delete-me | markdown: https://www.are.na/developers/explore/group/delete-me.md | params: path.id*

### Search
- GET /v3/search | docs: https://www.are.na/developers/explore/search | markdown: https://www.are.na/developers/explore/search.md | params: query.query, query.type, query.scope, query.user_id, query.group_id, query.channel_id, query.ext, query.metadata, query.sort, query.after, query.seed, query.page, query.per

### System
- GET /v3/openapi | docs: https://www.are.na/developers/explore/system/openapi | markdown: https://www.are.na/developers/explore/system/openapi.md | params: none
- GET /v3/openapi.json | docs: https://www.are.na/developers/explore/system/openapi-json | markdown: https://www.are.na/developers/explore/system/openapi-json.md | params: none
- GET /v3/ping | docs: https://www.are.na/developers/explore/system/ping | markdown: https://www.are.na/developers/explore/system/ping.md | params: none

### Upload
- POST /v3/uploads/presign | docs: https://www.are.na/developers/explore/upload/post-presign | markdown: https://www.are.na/developers/explore/upload/post-presign.md | params: none

### User
- GET /v3/users/{id} | docs: https://www.are.na/developers/explore/user | markdown: https://www.are.na/developers/explore/user.md | params: path.id*
- GET /v3/users/{id}/contents | docs: https://www.are.na/developers/explore/user/contents | markdown: https://www.are.na/developers/explore/user/contents.md | params: path.id*, query.page, query.per, query.sort, query.type
- GET /v3/users/{id}/followers | docs: https://www.are.na/developers/explore/user/followers | markdown: https://www.are.na/developers/explore/user/followers.md | params: path.id*, query.page, query.per, query.sort
- GET /v3/users/{id}/following | docs: https://www.are.na/developers/explore/user/following | markdown: https://www.are.na/developers/explore/user/following.md | params: path.id*, query.page, query.per, query.sort, query.type
- GET /v3/users/{id}/groups | docs: https://www.are.na/developers/explore/user/groups | markdown: https://www.are.na/developers/explore/user/groups.md | params: path.id*, query.page, query.per, query.sort
- GET /v3/me | docs: https://www.are.na/developers/explore/user/me | markdown: https://www.are.na/developers/explore/user/me.md | params: none