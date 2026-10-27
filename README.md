# Are.na-as-social-media

**ArenaPost** — an iOS app that opens straight into a Threads-style composer and
posts each entry as a block to one Are.na channel.

- Text → Text block, a lone URL → Link block, a photo/video/file → Image or
  Attachment block (file name = block title, your text = description).
- A History screen shows your past blocks in the channel as posts.
- Sign-in with Are.na (OAuth + PKCE) is required; the channel is set in Settings.

See [docs/PLAN.md](docs/PLAN.md) for the product and technical plan, and
[docs/arena/](docs/arena/) for the Are.na API snapshot it was built against.

## Requirements

- Xcode 26 (iOS 26 SDK, Swift 6.2)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- Optional: [SwiftLint](https://github.com/realm/SwiftLint) — `brew install swiftlint`

## Setup

1. Register an OAuth application at
   <https://www.are.na/developers/oauth/applications> with the redirect URI
   `arenapost://oauth/callback`.
2. Create your local config and fill in the client id and your Apple team id:

   ```sh
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   ```

3. Generate and open the Xcode project (it is not committed; `project.yml` is
   the source of truth):

   ```sh
   xcodegen generate
   open ArenaPost.xcodeproj
   ```

4. Run the `ArenaPost` scheme on a device or simulator.

Before the OAuth app exists you can sign in with a
[personal access token](https://www.are.na/developers/personal-access-tokens)
(with `write` scope): Debug builds show a token field on the login screen.

## Project layout

```text
ArenaPost/                 SwiftUI app
  App/                     entry point, session gate (RootView), AppModel
  Features/Auth/           Sign in with Are.na
  Features/Composer/       home screen, media preparation, camera/photos/files
  Features/History/        past posts feed
  Features/Settings/       settings, channel picker, new channel
  Shared/                  Keychain, preferences, small views
Packages/ArenaKit/         Are.na v3 client, OAuth/PKCE, posting pipeline (+ tests)
Config/                    xcconfig files (Local.xcconfig is git-ignored)
docs/                      plan + Are.na API snapshot
scripts/                   fetch-arena-docs.sh
```

## Checks

```sh
swift test --package-path Packages/ArenaKit       # unit tests (macOS or Linux)
swift format lint --recursive --strict --configuration .swift-format \
  ArenaPost Packages/ArenaKit/Sources Packages/ArenaKit/Tests
swiftlint lint --strict
xcodebuild build -project ArenaPost.xcodeproj -scheme ArenaPost \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

CI runs all of these on every push (`.github/workflows/ci.yml`).
