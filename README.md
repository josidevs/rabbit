# Rabbit for Reddit

A personal-use Reddit client in Flutter/Dart, heavily inspired by Apollo.

## Features

- **Apollo-style browsing** — front page / r/popular / r/all / any subreddit,
  your subscriptions when logged in, Hot/New/Top/Rising/Controversial sorts
  (with Top time ranges), infinite scroll, pull-to-refresh, search.
- **Full post view** — markdown selftext, inline images and galleries with a
  zoomable viewer, link cards, nested comments with colored depth rails,
  tap-to-collapse, "load more comments", six comment sorts.
- **Upvote percentage** shown on every post card and post header, Apollo-style.
- **Voting & saving** with optimistic UI (requires login).
- **OAuth2** — userless "installed client" grant for anonymous browsing out of
  the box; full authorization-code login (loopback redirect) for voting/saving.
- **Rate-limit bar** pinned to the bottom: live view of Reddit's
  `X-Ratelimit-*` headers (remaining/window + reset countdown).
- **Heuristic content tags** — posts are scanned for negative-content
  "gotchas" (death/violence/tragedy → *Heavy*, rage-bait → *Drama*, plus
  *Politics*, *Medical*, *Money/Scam?*, *Uplifting*, *NSFW*, *Spoiler*).
  Tag colors use the Okabe–Ito colorblind-safe palette and every tag has an
  icon, so color is never the only signal. NSFW/spoiler media is blurred
  until tapped.
- **Recently viewed tab** — every post you open is stored locally (last 300).
  If a post has since been deleted or removed, the app checks the Internet
  Archive's Wayback Machine and offers the archived copy.

## One-time setup (required)

The app ships with no API credentials — you use your own free Reddit app:

1. Go to <https://www.reddit.com/prefs/apps> → **create app**.
2. Type: **installed app**.
3. Redirect URI: `http://127.0.0.1:52377/callback` (must match exactly).
4. Copy the client ID (the short string under the app name).
5. In Rabbit: **Settings → Client ID** → paste it.

Browsing works immediately (anonymous). To vote/save, use
**Settings → Log in with Reddit** — it opens your browser and returns to the
app automatically.

## Running locally

```sh
flutter pub get
flutter run            # pick a device: Windows desktop, Android, etc.
```

On Windows, plugin builds require symlink support — enable **Developer Mode**
(`start ms-settings:developers`) once.

## Getting installable builds (Codemagic)

`codemagic.yaml` defines two workflows:

- **android-apk** — analyzes, tests, and builds `app-release.apk`
  (debug-signed, installable directly on your own device).
- **ios-unsigned-ipa** — unsigned IPA for sideloading via AltStore/SideStore.

Setup: push this repo to GitHub, add the app at [codemagic.io](https://codemagic.io)
choosing *Flutter App (via codemagic.yaml)*, and run a workflow. Download the
artifact from the build page. The Android workflow also auto-runs on pushes to
`main`.

## Notes

- Personal use only; respect Reddit's API terms. The free tier
  (100 requests/min per client) is plenty for one person — the bottom bar
  shows exactly where you stand.
- History, tokens, and settings are stored locally on-device only.
