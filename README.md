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
| Home | A rotating featured slider, continue watching, suggested, movies, series, anime |
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

## Top Shelf (Apple TV)

`TopShelf/` is a Top Shelf extension: a carousel of the featured titles with the English title drawn
on each card. The app saves the list when Home loads and the extension reads it through the app
group `group.com.vamirreza.sinama`. App groups need a **paid** developer team on a real Apple TV, so
they are off for devices by default (the static Top Shelf image shows instead). With a paid team add
to `Config/Secrets.xcconfig`:

```
TV_DEVICE_ENTITLEMENTS = Config/SiNamaTV.entitlements
SHELF_DEVICE_ENTITLEMENTS = Config/SiNamaTopShelf.entitlements
```

and change the group id (and bundle ids) to your own. The simulator always uses the group.

## Differences from the webOS/Tizen app

- Native SwiftUI + AVKit instead of React + hls.js. Focus, scrolling, the keyboard and the
  transport bar are the system's.
- Search uses the tvOS system keyboard instead of an on-screen Persian/English/digit grid.
- Quality is a **cap** (auto, 1080p, 720p, 480p) via `preferredMaximumResolution`; AVPlayer does not
  list the HLS variants, so there is no per-variant picker.
- The session token is kept in the keychain.

## iPhone and iPad

The `SiNamaPhone` scheme builds the same code as an iPhone/iPad app (iOS 17+): `xcodegen generate`,
open `SiNamaTV.xcodeproj`, pick the `SiNamaPhone` scheme. Layout sizes live in
`Sources/App/Metrics.swift`; the few places that differ use `#if os(tvOS)`.

- **Sign in** opens the 30nama approval page in an in-app Safari sheet (you cannot scan your own
  screen). Log in there if asked and approve; the app picks the session up on its own.
- **Player** is the system player with a small overlay of its own: close, a menu (episodes,
  subtitles, quality) and the skip-intro / next-episode buttons. Picture in Picture and background
  audio are on.
- Notifications live under the Account tab.
- The iPhone app presents itself to the API with the same client key as the TV client, so it needs
  the same `API_KEY`.

## Known gaps

- **5.1 audio selection is a guess.** AVFoundation does not expose channel counts for HLS audio
  groups, so the stereo/5.1 setting matches the audio option's display name ("5.1", "surround").
  If the stream's groups are not named like that, the system's default pick is used. Not testable
  in the simulator.
- **Cloudflare** sits in front of the API. `URLSession` passes it today; if it ever starts
  blocking, the login screen shows «سرور سی‌نما درخواست را مسدود کرد».
- The app icons and top-shelf image are generated placeholders (a red play disc and the wordmark);
  replace the artwork in `Resources/tvOS/Assets.xcassets` and `Resources/iOS/Assets.xcassets`
  before shipping beyond your own devices.
- The UI font is Vazirmatn (SIL OFL, `Resources/Fonts/OFL.txt`), bundled in `Resources/Fonts`.
- The tvOS system player also shows its own subtitle button next to ours.

## Testing

`UITests` (tvOS) and `UITestsPhone` (iOS) are XCUITest tours that press the remote or tap, and save
screenshots to `$SHOT_DIR` (default: the temp directory, `sinama-shots` / `sinama-phone-shots`). They need a
signed-in simulator for everything past the login screen.

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

## Contributing

Issues and pull requests are welcome. Keep secrets out of commits: the client key and your team id
belong in `Config/Secrets.xcconfig`, which is git-ignored. Both targets must build
(`SiNamaTV` and `SiNamaPhone`, see `.github/workflows/build.yml`).

## Disclaimer and license

This is an unofficial, community project. It is **not affiliated with, endorsed by or supported by
30nama**. "30nama" and its logo (`Resources/Shared/Assets.xcassets`, `Resources/Brand`) belong to
their owners and are included only to identify the service; remove or replace them if you
redistribute the app. The app uses your own account and plan, shows only what the official apps
show you, and cannot download or bypass anything. Use it in line with the service's terms.

The source code is MIT-licensed (see `LICENSE`). Vazirmatn is SIL OFL
(`Resources/Fonts/OFL.txt`). The webOS app that inspired the API notes,
[arastu/30nama-webos](https://github.com/arastu/30nama-webos), has no license file; no code was
copied from it.
