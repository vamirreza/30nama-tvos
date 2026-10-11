# 30nama for Apple TV

An unofficial [30nama](https://30nama.com) app for **Apple TV (tvOS 17+)**, a native SwiftUI port of
[arastu/30nama-webos](https://github.com/arastu/30nama-webos). Browse, search and stream with Persian
subtitles from the Siri Remote. The interface is Persian and right-to-left.

It talks to the same v2 API as the official 30nama TV client, so it shows the same catalogue and
keeps continue-watching in sync with your other devices.

> **You need your own 30nama account with an active plan**, a Mac with Xcode 15+, and an Apple
> developer account (a free one works for installing on your own Apple TV, re-signed every 7 days).
> Apple TV apps cannot be sideloaded any other way.

## What it does

| Area | |
|---|---|
| Sign in | QR code: scan it with a phone that is logged in to 30nama and approve |
| Home | Featured title, continue watching, suggested, movies, series, anime |
| Search | The system keyboard (Siri dictation works); results update as you type |
| Browse | Categories and genres, advanced filters (type, genre, IMDb score, decade, country), newest or most relevant |
| Title page | Seasons and episodes, cast and director (each opens their other titles), watchlist and favourites |
| My list | Watchlist, favourites, continue watching (play, details, remove) |
| Notifications, account | Plan and days left, settings, sign out |
| Player | The system `AVPlayerViewController` over HLS. Persian or English subtitles in three sizes, quality cap, skip intro, a next-episode countdown at the credits, an episode menu, resume where you left off on any device, progress reported every 30 s |

Only titles that stream are listed. Downloads, payments, ratings and comments are not in the app,
because the API the official TV client uses has no way to do them.

## Build and install

1. `brew install xcodegen`
2. Get the **client key**. Requests carry a `c-api-key` header, the same one the official 30nama TV
   web client (`tv.30app.store`) sends. It is not in this repo; read it from that client's network
   requests in your browser's developer tools. (The key the 30nama website sends is a different one
   and the TV API rejects it.)
3. ```bash
   cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
   # put the key in API_KEY, and your Apple team id in DEVELOPMENT_TEAM
   xcodegen generate
   open SiNamaTV.xcodeproj
   ```
4. Pick your Apple TV (or the tvOS Simulator) and Run. To pair a real Apple TV: Xcode → Window →
   Devices and Simulators → Add, then enter the code the TV shows (Settings → Remotes and Devices →
   Remote App and Devices).

If you build without the key, the app asks for it on first launch instead (Settings screen on the
login page: "تغییر کلید API"). Typing it with the Siri Remote is tedious, so prefer the build setting.

Change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` if `com.vamirreza.sinama.tv` is taken for your team.

## Using it

| Siri Remote | |
|---|---|
| Swipe / click pad edges | Move focus |
| Click | Open |
| Menu | Back; from a tab's root, leaves to the Home screen |
| Player: click | Pause / resume, shows the transport bar |
| Player: swipe left/right on the pad | Scrub; swipe down for the info/menus (episodes, subtitles, quality) |

Skip intro and next episode appear as a button on the player when they apply. If the next-episode
button shows, the next episode starts by itself after 10 seconds of playback; choose «ماندن» to stay.

## Differences from the webOS/Tizen app

- Native SwiftUI + AVKit instead of React + hls.js. Focus, scrolling, the keyboard and the
  transport bar are the system's.
- Search uses the tvOS system keyboard instead of an on-screen Persian/English/digit grid.
- Quality is a **cap** (auto, 1080p, 720p, 480p) via `preferredMaximumResolution`; AVPlayer does not
  list the HLS variants, so there is no per-variant picker.
- The session token is kept in the keychain.

## Known gaps

This port was written without access to a Mac, so treat the first build as unverified:

- **It has not been compiled or run on a device.** `.github/workflows/build.yml` builds it on a
  macOS runner (`xcodegen` + `xcodebuild` for the tvOS Simulator); fix anything it reports.
- **5.1 audio selection is a guess.** AVFoundation does not expose channel counts for HLS audio
  groups, so the stereo/5.1 setting matches the audio option's display name ("5.1", "surround").
  If the stream's groups are not named like that, the system's default pick is used.
- **Cloudflare** sits in front of the API. The Chromium TV runtimes pass it; `URLSession` may not.
  If the login screen shows «سرور سی‌نما درخواست را مسدود کرد», that is why.
- The app icon and top-shelf image are generated placeholders (a red play disc and the wordmark);
  replace the layers in `Resources/Assets.xcassets` with real artwork before shipping beyond your own TV.
- The UI font is Vazirmatn (SIL OFL, `Resources/Fonts/OFL.txt`), bundled in `Resources/Fonts`.

## How it works

`Sources/Core` is the app's model layer: `APIClient.swift` (form-encoded POSTs with the official
client's headers, Cloudflare and 204 handling, bounded retry), `Endpoints.swift` (the whole API
surface), `Models.swift` (tolerant parsing of the loosely-typed responses), `Subtitles.swift`
(SRT/VTT parser). `Sources/Views` are the SwiftUI screens, one tab each. `Sources/Player` is
`PlayerEngine`, which owns an `AVPlayer` inside the system player UI: subtitles are drawn in the
player's overlay, skip intro / next episode are the player's contextual actions, and quality,
subtitle and episode choices are transport-bar menus.

API behaviour worth knowing (from the webOS project's notes): `streamonly` must be the string
`"true"`; `user_list` with `action=add` toggles; `observer` answers 204 with no body; people pages
only match exactly by IMDb id.

## Disclaimer

Not affiliated with 30nama. It uses your own account and plan, and shows only what the official
apps show you.
