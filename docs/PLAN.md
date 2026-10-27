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

  | What you compose                         | Block created              |
  | ---------------------------------------- | -------------------------- |
  | Text                                     | `Text` (markdown)          |
  | Text that is only a URL                  | `Link` (Are.na scrapes it; YouTube/Vimeo etc. become `Embed`) |
  | One photo                                | `Image`                    |
  | One video file                           | `Attachment` (Are.na plays mp4 inline) |
  | One file (PDF, audio…)                   | `Attachment`               |

  When an attachment is added, the other attachment buttons are disabled until
  it is removed. Text typed next to an attachment becomes the block's
  **description** (caption). See decision D1.
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

```
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
  blocked on the OAuth app registration.

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
    duration / file chip, with an ✕ to remove.
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

- Vertical feed of `PostCard`s, newest first, from the configured channel.
- Segmented filter: **Mine** (default) / **Everyone** — channels can have
  collaborators; "Mine" keeps only blocks whose `user.id == me.id`.
- `PostCard` renders by block type:
  - Text → markdown via `AttributedString(markdown:)`.
  - Image → aspect-fit image (display size URL), tap to full-screen zoom.
  - Attachment (video) → `VideoPlayer` with poster frame; other files → file chip.
  - Link / Embed → preview card (thumbnail, title, host).
  - Footer: relative time ("3h"), description if any.
- Pull to refresh, infinite scroll (load next page when the last 5 cards appear).
- Context menu: Copy text/URL, Share, Open in Are.na, Remove from channel.
- Empty state: "Nothing here yet — your posts will show up here."

### 2.4 SettingsView

- **Account**: avatar, name, `@slug`, Sign out (clears Keychain + caches).
- **Channel**: current channel → ChannelPickerView.
- **Posting**
  - Use text as caption when attaching media (D1) — toggle.
  - Strip location from photos — toggle, default on.
  - Video quality: Original / High (1080p) / Compact (720p).
- **About**: version, link to the repo, link to Are.na.

### 2.5 ChannelPickerView

- Search field + list of your channels (title, block count, visibility badge
  public/closed/private).
- "New channel…" row → name + visibility → creates it and selects it.
- Selection is stored locally (id, slug, title) and the composer chip updates.
- If the stored channel later returns 404/403 (deleted, access lost), the app
  routes back to this picker with an explanation.

---

## 3. Are.na API (v3)

Base URL: `https://api.are.na/v3`. Are.na's v2 API is deprecated; build on v3
only.

> ⚠️ The exact request/response field names below must be checked against
> `https://api.are.na/v3/openapi.json` and the API Explorer
> (`https://www.are.na/developers/explore`) before implementation. This
> planning session could not reach are.na directly (network policy), so items
> marked **(verify)** are taken from the docs' summaries, not from the spec.

### 3.1 Auth — OAuth 2.0 + PKCE (public client, no secret in the app)

1. Register an OAuth application on Are.na with redirect URI
   `arenapost://oauth/callback` (scheme name TBD with the app name).
2. App generates `code_verifier` (43–128 random chars) and
   `code_challenge = BASE64URL(SHA256(verifier))` with CryptoKit, plus a random
   `state`.
3. `ASWebAuthenticationSession` opens
   `https://www.are.na/oauth/authorize?client_id=…&redirect_uri=…&response_type=code&scope=write&code_challenge=…&code_challenge_method=S256&state=…`
4. Callback → verify `state` → `POST https://api.are.na/v3/oauth/token` with
   `grant_type=authorization_code`, `code`, `client_id`, `redirect_uri`,
   `code_verifier`.
5. Store the access token (and refresh token if issued **(verify)**) in the
   Keychain (`kSecAttrAccessibleAfterFirstUnlock`, shared access group so a
   future Share Extension can use it).
6. All requests: `Authorization: Bearer <token>`. A 401 → try refresh, else
   sign out to LoginView.

Scope: tokens default to `read`; posting needs `write` — a read-only token gets
**403** on writes, which the app surfaces as "Sign in again to allow posting".

### 3.2 Endpoints used

| Purpose | Endpoint | Notes |
| --- | --- | --- |
| Current user | `GET /v3/me` **(verify)** | id, name, slug, avatar — needed for "Mine" filter and composer header |
| My channels | `GET /v3/users/{id}/channels` **(verify)** | paginated; feeds the picker |
| Create channel | `POST /v3/channels` | title, visibility |
| Channel info | `GET /v3/channels/{id}` | validate stored channel on launch |
| Channel contents | `GET /v3/channels/{id}/contents?page=&per=` | `per` max 100, default sort `position_desc`, meta has `has_more_pages` / `next_page` |
| Presign upload | `POST /v3/uploads/presign` **(verify path & body)** | returns presigned S3 PUT URLs, up to 50 files, expire after 1h |
| Upload bytes | `PUT <presigned url>` | straight to S3; send the same `Content-Type` that was presigned |
| Create block | `POST /v3/blocks` | `value` = text, URL, or uploaded S3 URL; channel id(s) to connect to; `title` / `description` **(verify field names)** |
| Batch create | `POST /v3/blocks/batch` | not needed for v1; useful for a future "thread" post |
| Update block | `PUT /v3/blocks/{id}` | owner only; edit caption later (v2 of the app) |
| Remove from channel | disconnect endpoint **(verify)** | for the History context menu |

Rate limits: the docs ask clients to space out write operations. One post =
1–3 writes, so this only matters for retries; use exponential backoff on 429.

### 3.3 Posting pipeline

```
ComposerDraft
  └─ classify()  → .text(String) | .link(URL) | .media(LocalAsset, caption?)
       ├─ text/link → POST /v3/blocks { value, channel }            → done
       └─ media
            1. prepare: image → JPEG/HEIC→JPEG, optional EXIF GPS strip, max 4096px
                        video → AVAssetExportSession → .mp4 (H.264/HEVC per quality)
            2. POST presign { filename, content_type }  → { upload_url, … }
            3. PUT bytes to upload_url (URLSession upload task, progress → UI)
            4. POST /v3/blocks { value: <S3 URL>, channel, description: caption }
            5. Block may arrive with a "processing" state; History refetches it
```

`classify()` rules (unit-tested):

- Attachment present → `.media` (text becomes caption if D1 is on, otherwise
  the Post button is disabled until text is cleared — pick one in D1).
- Trimmed text is a single `http(s)` URL (via `NSDataDetector`) → `.link`.
- Otherwise → `.text` (markdown is passed as-is).

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

```
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
    Posting/     DraftClassifier, Uploader (presign + S3 PUT), PostService
  Tests/ArenaKitTests/
    PKCETests, DraftClassifierTests, BlockDecodingTests (fixtures from openapi examples),
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
- Are.na upload size limits depend on the account plan **(verify)** — check
  file size before uploading and show a clear error instead of a failed PUT.

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

> Note: iOS apps can only be built on macOS with Xcode. The cloud session this
> plan was written in is Linux and has no access to `api.are.na`, so the app
> scaffolding/build/verification steps need a Mac (or CI on a macOS runner and
> `api.are.na` allowed in the environment's network policy).

---

## 6. Milestones

| # | Milestone | Done when |
| - | --------- | --------- |
| M0 | Setup | Are.na OAuth app registered; Xcode project + `ArenaKit` package; SwiftLint/swift-format; CI green on an empty app; API field names verified against `openapi.json` and fixtures saved |
| M1 | Auth & gate | Sign in via OAuth+PKCE, token in Keychain, `/me` loaded, sign out works, RootView routing tested |
| M2 | Channel | Picker lists/searches channels, can create one, selection persisted, invalid channel handled |
| M3 | Text & link posts | Composer focused on launch; text → Text block, URL → Link block; toast; draft restore |
| M4 | Image & video posts | PhotosPicker + camera + files; prep/export; presign → PUT → create; progress; caption (D1); size checks |
| M5 | History | Paginated feed with per-type cards, Mine/Everyone filter, refresh, context menu incl. remove |
| M6 | Polish | Background video upload + resume, retry queue, haptics, empty/error states, accessibility pass, app icon |
| M7 | Optional | Share Extension ("Post to my-feed" from Safari/Photos), App Intent / Shortcut + Action Button, Lock Screen widget that opens the composer |

M1–M3 together are the smallest useful app; M4 is where most of the risk is
(upload API shape, video sizes).

---

## 7. Decisions to make

- **D1 — Text with an attachment.** Recommended: use it as the block's
  description (caption), toggle in Settings. Alternative: disallow text when an
  attachment is present.
- **D2 — History default filter.** Recommended: "Mine", with "Everyone" one tap
  away (matters only for collaborative channels).
- **D3 — One channel or quick-switch favorites.** Recommended: one channel in
  v1; the channel chip can grow into a favorites switcher later.
- **D4 — Minimum iOS.** Recommended: iOS 26.
- **D5 — App name, bundle id, URL scheme** (e.g. `ArenaPost`,
  `studio.upcoming.arenapost`, `arenapost://`).
