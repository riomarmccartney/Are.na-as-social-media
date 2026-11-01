# Releasing to the App Store

`.github/workflows/release.yml` (run by hand from the Actions tab) builds a
signed IPA and uploads it to App Store Connect with
[Publish iOS App to App Store](https://github.com/marketplace/actions/publish-ios-app-to-app-store)
(`openMF/mifos-x-actionhub-publish-ios-on-appstore@v1.0.15`).

That action only sets up Ruby, writes the API key and match SSH key to
`secrets/` (git-ignored), and runs `bundle exec fastlane ios release`. The
lane itself is in [`fastlane/Fastfile`](../fastlane/Fastfile):

1. `setup_ci` — temporary keychain.
2. `match` (read-only) — App Store certificate + profiles for
   `studio.upcoming.arenapost` and `studio.upcoming.arenapost.widget`.
3. Switches the XcodeGen project from automatic to manual signing with those
   profiles (only on CI; `project.yml` stays on automatic signing).
4. Build number = latest TestFlight build + 1.
5. `build_app`, then `upload_to_app_store` without metadata or screenshots.
   The **Submit for review** checkbox on the workflow form submits it too.

The version shown on the store is `MARKETING_VERSION` in `project.yml`; bump
it there for each new App Store version.

## One-time setup

### 1. App Store Connect

- Create the app at <https://appstoreconnect.apple.com/apps> with bundle ID
  `studio.upcoming.arenapost` (register it and `…arenapost.widget` under
  Identifiers in the developer portal first if needed).
- Create an API key under **Users and Access → Integrations → App Store
  Connect API** with the **App Manager** role. Note the Key ID and Issuer ID,
  and download the `.p8` file (only downloadable once).

### 2. Certificates repository (fastlane match)

Create an empty **private** GitHub repository, e.g. `chirp-certificates`.
Then, on a Mac, from this repository:

```sh
bundle install
export MATCH_GIT_URL=git@github.com:<owner>/chirp-certificates.git
bundle exec fastlane match appstore \
  --app_identifier "studio.upcoming.arenapost,studio.upcoming.arenapost.widget" \
  --team_id <TEAM_ID>
```

It asks for a passphrase — this is `MATCH_PASSWORD`. It creates the
distribution certificate and both App Store profiles, encrypts them and pushes
them to the certificates repository.

### 3. Deploy key for the certificates repository

```sh
ssh-keygen -t ed25519 -N "" -C "chirp-match-ci" -f ./match_ci_key
```

Add `match_ci_key.pub` to the certificates repository under **Settings →
Deploy keys** (read-only is enough; CI runs match with `readonly: true`).
The private key `match_ci_key` becomes `MATCH_GIT_PRIVATE_KEY`. Delete both
files afterwards.

### 4. GitHub settings for this repository

**Settings → Secrets and variables → Actions**

| Secrets | Value |
| --- | --- |
| `APPSTORE_KEY_ID` | API key ID |
| `APPSTORE_ISSUER_ID` | Issuer ID |
| `APPSTORE_AUTH_KEY` | **base64** of the `.p8`: `base64 -i AuthKey_XXXX.p8 \| pbcopy` |
| `MATCH_PASSWORD` | match passphrase |
| `MATCH_GIT_PRIVATE_KEY` | contents of `match_ci_key`, **not** base64 (`pbcopy < match_ci_key`) |

| Variables | Value |
| --- | --- |
| `CHIRP_TEAM_ID` | Apple Developer team ID |
| `MATCH_GIT_URL` | `git@github.com:<owner>/chirp-certificates.git` |
| `ARENA_CLIENT_ID` | Are.na OAuth client ID (built into the app) |

### 5. Run it

**Actions → Release to App Store → Run workflow.** The build shows up in
TestFlight after Apple finishes processing it.

## Notes

- Export compliance: unless `ITSAppUsesNonExemptEncryption` is set in the
  Info.plist (`project.yml`), App Store Connect asks the encryption question for
  every build before it can be tested or submitted.
- Store listing (description, screenshots, privacy) is edited in App Store
  Connect; the lane skips metadata so it never overwrites it.
- To release locally, put the `.p8` at `secrets/AuthKey.p8`, export the same
  variables and secrets, run `xcodegen generate`, then
  `bundle exec fastlane ios release`.
