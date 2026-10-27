# Are.na as social media — iOS app plan

A single-purpose iOS app that turns one Are.na channel into a personal "feed".
The app opens straight into a Threads/Twitter-style composer; whatever you post
becomes one Are.na block in the channel you picked in Settings.

---

## 1. Product scope

### Core rules

- **Login is required.** Nothing is visible until you sign in with Are.na.
- **The composer is the home screen.** Launch → keyboard up → type → Post.
- **One post = one block.** Are.na blocks hold one kind of content, so a post is
  exactly one of:

  | What you compose        | Block created                                                  |
  | ----------------------- | -------------------------------------------------------------- |
  | Text                    | `Text` (markdown)                                              |
  | Text that is only a URL | `Link` (Are.na scrapes it; YouTube/Vimeo become `Embed`)       |
  | One photo               | `Image`                                                        |
  | One video file          | `Attachment` (`video/mp4`; confirmed with a real upload in M4) |
  | One file (PDF, audio…)  | `Attachment`                                                   |

  When an attachment is added, the other attachment buttons are disabled until
  it is removed.
- **Attachment posts (image, video, file)** map to the block like this (D1):
  - **title** = the attached file's name (e.g. `IMG_4821.jpg`, `trip.mp4`,
    `zine.pdf`). See §3.4 for how it's found.
  - **description** = the text typed in the composer, if any (markdown kept).
  - Attachment with no text → title only, empty description.
- **Channel is set in Settings.** All posts go to that channel.
- **History is one tap away.** A button in the composer opens your past blocks
  rendered as posts.

### Out of scope for v1

- Posting to several channels at once.
- Multi-attachment posts (could later be posted as a "thread" of consecutive blocks).
- Comments, following, other people's feeds.
- iPad/Mac-specific layouts (the iPhone layout just runs there).

---

## 2. Screens & flows

```text
Launch
  └─ RootView (switch on session state)
       ├─ .signedOut            → LoginView
       ├─ .signedIn, no channel → ChannelPickerView (onboarding, can't dismiss)
       └─ .ready                → ComposerView  ← home
                                     ├─ History button  → HistoryView (push)
                                     ├─ Channel chip    → ChannelPickerView (sheet)
                                     └─ Settings button → SettingsView (sheet)
```

### 2.1 LoginView

- App mark, one-line explanation, **"Sign in with Are.na"** button.
- Opens `ASWebAuthenticationSession` → Are.na OAuth page → returns to the app.
- Error state (cancelled / network / denied) shown inline under the button.
- Debug builds only: "Use personal access token" field, so development is not
  blocked on the OAuth app registration. Create one with the `write` scope at
  `https://www.are.na/developers/personal-access-tokens` (it gives full access
  to your account, so it never ships in release builds).

### 2.2 ComposerView (home)

Layout, top to bottom:

- **Top bar**
  - Leading: History button (`clock.arrow.circlepath` or `square.stack`).
  - Center: channel chip, e.g. `● my-feed` (tap → quick channel switch sheet).
  - Trailing: Settings (`gearshape`).
- **Body** (scrolls)
  - Avatar + display name, like Threads.
  - Multiline `TextField(axis: .vertical)` focused on appear
    (`@FocusState`), placeholder "Post to my-feed…".
  - Attachment preview under the text: image thumbnail / video thumbnail with
    duration / file chip, with an ✕ to remove. The file name (which becomes
    the block title) is shown under it, and the text field placeholder changes
    to "Add a description…".
  - When the text is a lone URL: live link preview card (`LPMetadataProvider`)
    so you see what Are.na will scrape.
- **Keyboard accessory bar** (`.toolbar { ToolbarItemGroup(placement: .keyboard) }`
  or a `safeAreaInset(edge: .bottom)` bar)
  - Photo/Video library (`PhotosPicker`, `.any(of: [.images, .videos])`, max 1).
  - Camera (`UIImagePickerController` wrapped, photo + video).
  - Files (`.fileImporter`).
  - Paste link (reads `UIPasteboard` URL).
  - **Post** capsule button on the trailing edge; disabled when empty or while
    posting. Shows a progress ring during upload.
- **After posting**: success haptic, small toast "Posted to my-feed · View",
  composer clears and stays focused, ready for the next post.
- **On failure**: content stays in the composer, toast with "Retry".
- **Drafts**: current text + attachment reference are saved when the app goes
  to background and restored on launch.

### 2.3 HistoryView (past posts)

- Vertical feed of `PostCard`s, newest first (`sort=created_at_desc`), from
  the configured channel.
- Segmented filter: **Mine** (default) / **Everyone** — channels can have
  collaborators. "Mine" is filtered by the server (`user_id=<me.id>` on the
  contents request), so pages stay full and pagination is correct.
- Channel contents can include channels as well as blocks; items with
  `type == "Channel"` are skipped.
- `PostCard` renders by block type:
  - Text → `content.markdown` via `AttributedString(markdown:)`.
  - Image → `image.medium.src_2x`, sized from `image.aspect_ratio` so the card
    doesn't jump; `image.blurhash` as the placeholder; tap → full-screen
    `image.src`.
  - Attachment → if `attachment.content_type` starts with `video/`,
    `VideoPlayer` on `attachment.url` with `image` as poster; other files →
    file chip (`attachment.filename`, `file_size`), opens in Quick Look.
  - Link → preview card (`image`, `title`, `source.url` host).
  - Embed → thumbnail (`embed.thumbnail_url`) with a play badge; tap opens
    `embed.source_url`.
  - `PendingBlock` / `state == "processing"` → placeholder card with a spinner,
    refetched with `GET /v3/blocks/{id}` until `available` (or `failed` → error
    card).
  - Image / Attachment: the **description** is shown as the post text above the
    media (like a tweet with a photo); the **title** (filename) is shown as
    small secondary metadata under the media.
  - Footer: relative time ("3h").
- Pull to refresh, infinite scroll (load next page when the last 5 cards appear).
- Context menu: Copy text/URL, Share, Open in Are.na, Remove from channel.
  "Remove" is shown when `connection.connected_by.id == me.id` or you own the
  channel; a 403 from the server is still handled (contents items don't carry
  removal abilities, so this is a best guess, not a guarantee).
- Uses `ETag` / `If-None-Match` on refresh, so an unchanged first page comes
  back as a cheap `304`.
- Empty state: "Nothing here yet — your posts will show up here."

### 2.4 SettingsView

- **Account**: avatar, name, `@slug`, Sign out (clears Keychain + caches).
- **Channel**: current channel → ChannelPickerView.
- **Posting**
  - Strip location from photos — toggle, default on.
  - Video quality: Original / High (1080p) / Compact (720p).
- **About**: version, link to the repo, link to Are.na.

### 2.5 ChannelPickerView

- List of channels you created: `GET /v3/users/{me.id}/contents?type=Channel&sort=updated_at_desc`
  (title, `counts.blocks`, visibility badge public/closed/private), loaded
  page by page as you scroll.
- Search field filters the loaded list on the device. It does **not** call
  `GET /v3/search`, which is Premium-only.
- **"Paste channel link…"** row for channels you collaborate on but didn't
  create (they aren't in the list above): accepts `are.na/<user>/<slug>` or a
  bare slug → `GET /v3/channels/{slug}`.
- "New channel…" row → title + visibility (default `closed`) →
  `POST /v3/channels` → selected.
- Before saving a selection, the app checks `GET /v3/channels/{id}` →
  `can.add_to == true`; otherwise "You can't add blocks to this channel".
- Selection is stored locally (id, slug, title) and the composer chip updates.
- If the stored channel later returns 404/403 (deleted, access lost), the app
  routes back to this picker with an explanation.

---

## 3. Are.na API (v3)

Base URL: `https://api.are.na/v3`. Are.na's v2 API is deprecated; build on v3
only.

Source of truth: the snapshot in [`docs/arena/`](arena/) —
`openapi.json` (full spec) and `developers-all.md` (guide), refreshed with
`scripts/fetch-arena-docs.sh`. Everything below was checked against it.

### 3.1 Auth — OAuth 2.0 + PKCE (public client, no secret in the app)

1. Register an OAuth application at
   `https://www.are.na/developers/oauth/applications` with redirect URI
   `arenapost://oauth/callback` (scheme name TBD with the app name). Only the
   `client_id` is used by the app.
2. App generates `code_verifier` (43–128 chars from `A-Z a-z 0-9 - . _ ~`) and
   `code_challenge = BASE64URL(SHA256(verifier))` with CryptoKit, plus a random
   `state`.
3. `ASWebAuthenticationSession` opens
   `https://www.are.na/oauth/authorize?client_id=…&redirect_uri=…&response_type=code&scope=write&code_challenge=…&code_challenge_method=S256&state=…`
   (`scope` defaults to `read` if omitted, so `write` must be explicit).
4. Callback → verify `state` → `POST https://api.are.na/v3/oauth/token` as
   **`application/x-www-form-urlencoded`** with `grant_type=authorization_code`,
   `client_id`, `code`, `redirect_uri`, `code_verifier` (no `client_secret`).
   Response: `{ access_token, token_type: "Bearer", scope, created_at }`.
5. Check the returned `scope` contains `write`; if not, show "Are.na only
   granted read access — sign in again and allow posting".
6. Store the access token in the Keychain
   (`kSecAttrAccessibleAfterFirstUnlock`, shared access group so a future Share
   Extension can use it). There is **no `expires_in` and no refresh token**,
   so there is no refresh logic to build.
7. All requests: `Authorization: Bearer <token>` and
   `User-Agent: ArenaPost/<version> (+<contact URL or email>)` (Are.na asks
   clients to identify themselves). A 401 means the token was revoked → clear
   the Keychain and go back to LoginView.

### 3.2 Endpoints used

| Purpose | Endpoint | Notes |
| --- | --- | --- |
| Current user | `GET /v3/me` | `Me` = `User` + `email`, `counts`; id/name/slug/avatar used for the header and "Mine" |
| My channels | `GET /v3/users/{id}/contents?type=Channel&sort=updated_at_desc&page=&per=` | channels you created; there is no dedicated "user channels" endpoint |
| Channel by link | `GET /v3/channels/{id-or-slug}` | full resource incl. `can.add_to`, `owner`, `collaborators` |
| Create channel | `POST /v3/channels` | `{ title, visibility?: public\|closed\|private (default closed), description? }` |
| History | `GET /v3/channels/{id}/contents?sort=created_at_desc&user_id=&page=&per=24` | mixed blocks + channels; each item has `connection { id, position, connected_at, connected_by }` |
| Refresh one block | `GET /v3/blocks/{id}` | poll a `processing` block after posting |
| Presign upload | `POST /v3/uploads/presign` | body `{ files: [{ filename, content_type }] }` (1–50) → 201 `{ files: [{ upload_url, key, content_type }], expires_in: 3600 }` |
| Upload bytes | `PUT <upload_url>` | raw bytes, `Content-Type` = the returned `content_type` |
| Create block | `POST /v3/blocks` | see body below; 201 returns the `Block` (may be `PendingBlock`) |
| Remove from channel | `DELETE /v3/connections/{connection.id}` | 204; removes it from the channel only — the block itself is not deleted |
| Edit later | `PUT /v3/blocks/{id}` | owner only; `title`, `description`, `alt_text`, … (v2 of the app) |

Not used: `GET /v3/search` (**Premium only**) and `POST /v3/blocks/batch`
(**Supporter only**). The app works on a free account.

**Create block body** (`BlockInput` + target channel):

```jsonc
// Text post
{ "value": "today's **notes**", "channels": [{ "id": 123 }] }

// Link post (value is a URL → Are.na infers Link or Embed)
{ "value": "https://example.com/article", "channels": [{ "id": 123 }] }

// Image / video / file post (value = uploaded S3 URL)
{
  "value": "https://s3.amazonaws.com/arena_images-temp/<key>",
  "title": "IMG_4821.jpg",            // attached file name (§3.4)
  "description": "composer text",     // markdown, omitted if empty
  "channels": [{ "id": 123 }]
}
```

- `channels: [{ id, position?, metadata? }]` is the preferred form; the legacy
  `channel_ids: [..]` must not be sent alongside it. `id` can be a numeric id
  or slug.
- Other optional fields worth knowing: `alt_text` (images — a later "Add alt
  text" row in the composer), `cover_url` (custom preview for Link/Attachment/
  Embed), `metadata` (e.g. `{ "client": "arenapost" }` to mark posts made from
  the app), `original_source_url` / `original_source_title`.

**Block types the app must decode** (`type` discriminator): `Text`
(`content.markdown`), `Image` (`image.{src, small, medium, large, square,
blurhash, aspect_ratio, filename}`), `Link` (`image?`, `source.url`),
`Attachment` (`attachment.{url, filename, content_type, file_size,
file_extension}`, `image?` preview), `Embed` (`embed.{source_url, html,
thumbnail_url}`), `PendingBlock`. Shared fields: `id`, `title`,
`description.markdown`, `state` (`processing | available | failed`),
`created_at`, `user`, `connection?`. Unknown types decode to `.unsupported`
instead of failing the whole page.

**Errors**: `{ error, code, details: { message, errors? } }`; 429 has its own
shape with `error.retry_after` (seconds).

**Rate limits** (global per account, separate read/write budgets):

| Tier | Reads / min | Writes / min | Writes / hour |
| --- | --- | --- | --- |
| Free | 120 | 30 | 300 |
| Premium | 300 | 60 | 1500 |
| Supporter | 600 | 120 | 4000 |

A media post is 2 writes (presign + create), a text post 1, so even the free
tier is far above personal use. On 429 wait `retry_after` (or until
`X-RateLimit-Reset`) before retrying — never a tight loop. History uses
`ETag`/`If-None-Match` and only loads pages on scroll, as the docs ask.

### 3.3 Posting pipeline

```text
ComposerDraft
  └─ classify()  → .text(String) | .link(URL) | .media(LocalAsset, description?)
       ├─ text/link → POST /v3/blocks { value, channels }              → done
       └─ media
            1. prepare: image → JPEG (HEIC→JPEG), optional EXIF GPS strip, max 4096px
                        video → AVAssetExportSession → .mp4 (H.264/HEVC per quality)
            2. POST /v3/uploads/presign { files: [{ filename, content_type }] }
                 → files[0].{ upload_url, key, content_type }
            3. PUT bytes to upload_url, Content-Type = content_type
               (URLSession upload task, progress → UI)
            4. POST /v3/blocks { value: "https://s3.amazonaws.com/arena_images-temp/<key>",
                                 title: <file name>, description: <composer text>,
                                 channels: [{ id }] }
            5. If the response is PendingBlock / state == processing,
               poll GET /v3/blocks/{id} (backoff 1s → 2s → 4s …, max ~1 min)
```

`classify()` rules (unit-tested):

- Attachment present → `.media`; trimmed composer text (if non-empty) becomes
  the description, the file name becomes the title. A URL typed next to an
  attachment stays plain description text — it does not create a Link block.
- Trimmed text is a single `http(s)` URL (via `NSDataDetector`) → `.link`.
- Otherwise → `.text` (markdown is passed as-is).

Not documented by Are.na, to confirm with a real upload in M4:

- **Video**: the presign docs say "images, attachments"; an `.mp4` uploaded
  this way is expected to become an `Attachment` block with
  `attachment.content_type = video/mp4`.
- **Maximum upload size**: no limit is published. Test a large video early;
  if there is a cap, check size before presigning and show a clear message.

### 3.4 Where the attachment's file name (block title) comes from

| Source | How the name is read | Example title |
| --- | --- | --- |
| Files app (`.fileImporter`) | `url.lastPathComponent` | `zine.pdf` |
| Photos library (`PhotosPicker`) | `PhotosPickerItem.itemIdentifier` → `PHAsset` → `PHAssetResource.assetResources(for:)` → `originalFilename`. Needs Photos read access (limited access is enough for the picked item). | `IMG_4821.HEIC` → `IMG_4821.jpg` |
| Camera capture | No file name exists, so generate one from the capture time | `IMG_20261027_143205.jpg` / `.mp4` |

Rules:

- The title is the name of the file **as it is uploaded**: when step 1
  converts the file (HEIC → JPEG, MOV → MP4) the base name is kept and the
  extension changes, so title, presign `filename` and the actual file always
  agree.
- If the Photos name can't be read (access denied, iCloud-only asset), fall
  back to the camera-style timestamp name. Posting is never blocked by this.
- The composer's attachment preview shows the file name under the thumbnail,
  so you see the title before posting.
- The title is not editable in v1. Editing title/description later can use
  `PUT /v3/blocks/{id}` from History.

---

## 4. Technical architecture

### 4.1 Stack

- **Swift 6** (strict concurrency), **SwiftUI**, **Observation** (`@Observable`).
- **Minimum iOS 26** (current Xcode/SDK as of Oct 2026; gets Liquid Glass
  toolbars for free). Can drop to iOS 18 if older devices matter — nothing in
  the plan requires 26-only APIs except visual polish.
- No backend. Zero or near-zero third-party dependencies:
  - Networking: `URLSession` + `async/await`.
  - Auth: `AuthenticationServices`, `CryptoKit`, Keychain via `Security`.
  - Media: `PhotosUI`, `AVFoundation`, `AVKit`, `LinkPresentation`.
  - Image loading/caching in History: start with a small `actor ImageCache`
    over `URLCache`; switch to **Nuke** only if scrolling performance needs it.

### 4.2 Project layout

```text
ArenaPost/                         Xcode app target (synchronized folders)
  App/
    ArenaPostApp.swift
    RootView.swift                 session-state switch (§2)
    AppModel.swift                 @Observable: session, me, selectedChannel
  Features/
    Auth/        LoginView, OAuthCoordinator (ASWebAuthenticationSession)
    Composer/    ComposerView, ComposerModel, AttachmentBar, AttachmentPreview, LinkPreview
    History/     HistoryView, HistoryModel (pagination), PostCard + per-type subviews
    Settings/    SettingsView, ChannelPickerView, NewChannelSheet
  Shared/        Toast, Haptics, Avatar, MediaPreparer (image/video export)
  Resources/     Assets, Info.plist (URL scheme, photo/camera usage strings)

Packages/ArenaKit/                 local Swift package, pure Foundation (+CryptoKit)
  Sources/ArenaKit/
    ArenaClient.swift              actor; typed requests, auth header, retry/backoff
    Endpoints.swift
    Models/      User, Channel, Block (enum by type), Paginated<T>
    Auth/        OAuthConfig, PKCE, TokenStore (protocol) + KeychainTokenStore
    Posting/     DraftClassifier, AttachmentNaming (title from file name), Uploader (presign + S3 PUT), PostService
  Tests/ArenaKitTests/
    PKCETests, DraftClassifierTests, AttachmentNamingTests, BlockDecodingTests (fixtures built from `docs/arena/openapi.json` examples),
    ArenaClientTests (URLProtocol stub)
```

Keeping the API layer in `ArenaKit` means it is unit-testable with `swift test`
(no simulator), reusable by a later Share Extension / App Intents, and the
decoding can be checked against real JSON fixtures.

### 4.3 State

- `AppModel` (`@Observable`, injected via `.environment`): `session`
  (`signedOut | signedIn(token)`), `me: User?`, `channel: ChannelRef?`.
- `ChannelRef { id, slug, title }` in `@AppStorage` (Codable JSON); token only
  in the Keychain.
- `ComposerModel`: `text`, `attachment: Attachment?`, `phase` (`idle |
  preparing | uploading(progress) | creating | failed(Error)`), `canPost`.
- `HistoryModel`: `blocks`, `page`, `hasMore`, `filter`, `isLoading`,
  `refresh()`, `loadMoreIfNeeded(current:)`.

### 4.4 Reliability details

- Video uploads use a `URLSession` background configuration so they finish if
  the app is backgrounded; the pending post (block-create step) is persisted to
  a small JSON file and completed on next launch/wake.
- Presigned URLs expire after 1h: if an upload is retried later, presign again.
- Are.na publishes no upload size limit; once one is found in testing (M4),
  check file size before presigning and show a clear error instead of a
  failed PUT.

---

## 5. Quality & tooling

- **SwiftLint** (strict, CI-enforced) + **swift-format** (format on commit).
- **Type checking / build**: `xcodebuild -scheme ArenaPost -destination
  'platform=iOS Simulator,name=iPhone 17' build test`.
- **Tests**: `swift test` in `Packages/ArenaKit`; a few XCUITests for the gate
  (signed out → login shown; signed in without channel → picker shown).
- **CI**: GitHub Actions on a `macos-26` runner — lint → `swift test` →
  `xcodebuild build test`.
- **Accessibility**: Dynamic Type on all text, VoiceOver labels on icon
  buttons, 44pt hit targets, Dark Mode, Reduce Motion respected for toasts.
- **Secrets**: the OAuth `client_id` is not secret but lives in an
  `.xcconfig` (not hard-coded); no client secret is ever shipped (PKCE).

> Note: iOS apps can only be built on macOS with Xcode. Cloud sessions on this
> repo run on Linux and can't reach `api.are.na`, so building and calling the
> real API needs a Mac (or CI on a macOS runner). `ArenaKit` unit tests run
> anywhere.

---

## 6. Milestones

| # | Milestone | Done when |
| - | --------- | --------- |
| M0 | Setup | Are.na OAuth app registered; Xcode project + `ArenaKit` package; SwiftLint/swift-format; CI green on an empty app; JSON fixtures for each block type saved from `docs/arena/openapi.json` |
| M1 | Auth & gate | Sign in via OAuth+PKCE, token in Keychain, `/me` loaded, sign out works, RootView routing tested |
| M2 | Channel | Picker lists/filters your channels, paste-a-link for collaborations, create one, `can.add_to` checked, selection persisted, invalid channel handled |
| M3 | Text & link posts | Composer focused on launch; text → Text block, URL → Link block; toast; draft restore |
| M4 | Image & video posts | PhotosPicker + camera + files; prep/export; presign → PUT → create; progress; filename → title, text → description (D1); first task: upload a real mp4 + a large file to confirm video → Attachment and find the size cap |
| M5 | History | Paginated feed with per-type cards, Mine/Everyone filter, refresh, context menu incl. remove |
| M6 | Polish | Background video upload + resume, retry queue, haptics, empty/error states, accessibility pass, app icon |
| M7 | Optional | Share Extension ("Post to my-feed" from Safari/Photos), App Intent / Shortcut + Action Button, Lock Screen widget that opens the composer |

M1–M3 together are the smallest useful app; M4 is where most of the risk is
(upload API shape, video sizes).

---

## 7. Decisions to make

- **D1 — Text with an attachment.** ✅ Decided: composer text → block
  `description`, attached file name → block `title` (§1, §3.4).
- **D2 — History default filter.** Recommended: "Mine", with "Everyone" one tap
  away (matters only for collaborative channels).
- **D3 — One channel or quick-switch favorites.** Recommended: one channel in
  v1; the channel chip can grow into a favorites switcher later.
- **D4 — Minimum iOS.** Recommended: iOS 26.
- **D5 — App name, bundle id, URL scheme** (e.g. `ArenaPost`,
  `studio.upcoming.arenapost`, `arenapost://`).
