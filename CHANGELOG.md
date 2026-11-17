# Changelog

Davefin's changes on top of Moonfin. Moonfin's own release notes are on its
[releases page](https://github.com/Moonfin-Client/Moonfin-Core/releases).

## Davefin 3.1.0-davefin.1

Based on Moonfin 3.1.0.

### Added

- **Pop-out player** on Windows, macOS and Linux: a small, resizable,
  always-on-top window with play/pause, seek, scrubber with trickplay,
  intro/credits skip, dock back to the mini player bar, return to the full
  player and stop. Space, ←/→ and Esc work, and dragging the video moves
  the window. Open it from the button next to Minimize in the player, or
  from the mini player bar.
- **Web picture-in-picture** from the same button, in browsers with the
  picture-in-picture API.
- `FeatureFlags.popOutPlayer`, on by default; turn it off with
  `--dart-define=POP_OUT_PLAYER=false`.

### Changed: side-by-side install with Moonfin

- App name **Davefin**, and recolored icons (orange/magenta instead of
  purple/cyan) plus a reworded Android TV banner.
- Android and Android TV `applicationId`: `org.davefin.androidtv` (beta
  builds: `org.davefin.androidtv.beta`). The Kotlin namespace stays
  `org.moonfin.androidtv`.
- iOS and macOS bundle id: `org.davefin.app`.
- Linux application id `org.davefin.linux` and binary `davefin`, which also
  moves the data dir to `~/.local/share/org.davefin.linux`.
- Windows binary `davefin.exe`, version-resource company `org.davefin` and
  product `Davefin`, which moves the data dir to
  `%APPDATA%\org.davefin\Davefin`. The installer has its own AppId and
  installs to `Program Files\Davefin`. MSIX identity `Davefin.Davefin`.
- URL scheme `davefin://` on every platform. Pasted `moonfin://` links are
  still understood.
- In-app updates come from this fork's releases. Source and issue links
  point here (GPL-2.0).
- Firebase push (Moonfin's project) isn't built in on Android.

### Unchanged on purpose

- Jellyfin, Emby, Plex and Silo API use, the Moonbase plugin protocol,
  SyncPlay, and the client name sent to servers ("Moonfin for …"). The
  same servers serve both apps with no server changes.
