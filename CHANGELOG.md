# Changelog

All notable changes to Sili are listed here. Versions follow [Semantic Versioning](VERSIONING.md).

## [Unreleased]

### Fixed
- **Games not brought to the front when Steam wasn't running yet.** Pressing Play started Steam first, and
  Sili mistook Steam's own windows for the game's, so it stopped there and the game opened behind other
  windows. Sili now recognises Steam's processes and keeps going until the game's window appears.
- **Play could seem to do nothing.** If a game couldn't be started, or no game window appeared within two
  minutes, nothing told you. Sili now shows an alert, and you can press Play again straight away.
- The Library's double-click guard no longer resets when you switch away from the Library and back.

## [1.3.1] - 2026-10-22

Patch release: fix from testing more games.

### Fixed
- **Steam's first-launch dialogs were hidden.** Some games show a Steam dialog the first time you play them
  (choosing a launch option, or accepting the game's EULA). These opened behind other windows, so pressing
  Play seemed to do nothing. Sili now brings each new Steam dialog to the front during a launch, then the game
  window once it appears.

## [1.3.0] - 2026-10-22

Minor release: uninstall games from the Library.

### Added
- **Uninstall from the Library.** Each game card has a "…" button next to Play (and the same options when
  you right-click): Create Dock Shortcut, Show in Finder, Open Bottle, and **Uninstall…**. For Steam games,
  Sili asks first, then hands over to Steam's own uninstaller, which confirms again and deletes the files. Sili
  brings Steam's dialog to the front and removes the game from the Library once it's gone. Pinned programs get
  **Remove from Library** instead, which unpins them without touching their files.

## [1.2.2] - 2026-10-22

Patch release: fixes found in a full test pass.

### Fixed
- **"Game failed to initialize Steam."** Clicking Steam more than once could start two Steam clients, and games
  then couldn't connect. Sili now ignores repeat launches of the same program for 10 seconds. Before starting
  a game, it checks whether Steam is already running in the bottle and waits until Steam has signed in
  (instead of a fixed 3 seconds). Dock shortcuts wait for Steam in the same way.
- **Games opening behind other windows.** Sili now brings a game to the front when its first window appears.
  GTA San Andreas' screen picker no longer hides behind other apps, and fullscreen games hide the menu bar and
  Dock as they should.
- **Accessibility:** game cards in the Library work with VoiceOver (with Play and Open Bottle actions), and the
  refresh button is labelled "Refresh" instead of "Syncing".

## [1.2.1] - 2026-10-22

Patch release: per-game fixes for Age of Empires II: DE and Age of Mythology: EE.

### Fixed
- **Age of Empires II: DE:** gold menu text (button labels, player names) was cut in half. Sili now
  switches the game to its "Smooth Serif" font, which draws correctly and looks almost the same.
  Applies from the second launch, since the game creates its settings on the first one.
- **Age of Mythology: EE:** much less stutter. The game now draws through Vulkan (MoltenVK) instead of
  macOS's OpenGL, and the Steam overlay, which caused heavy stutter under Wine, is turned off for it.
- Per-game DLL overrides no longer replace Sili's default overrides.

## [1.2.0] - 2026-10-22

Minor release: a new engine and several fixes. Nothing breaking. Existing bottles move to the new engine
automatically, and Steam may ask you to sign in again once.

### Added
- **Sili Engine 4.0**: Wine built from CodeWeavers' open-source CrossOver 26.3 code (Wine 11.0),
  with DXMT, DXVK and MoltenVK. It handles games that make direct Windows system calls, plus many
  Mac-specific fixes. Age of Empires II: DE and Age of Mythology: EE (Windows versions) now reach
  their main menus. Both crashed or froze on engine 3.x.
- **Steam black-window fix, applied automatically.** Steam's built-in browser is wrapped so it
  draws in one process, and the fix is reapplied after every Steam self-update.
- **Settings > Graphics:** switch DirectX 10/11 between DXMT (default) and Wine's own WineD3D.
- **Per-game fixes:**
  - GTA San Andreas is limited to 2 CPU cores (it hangs at startup on many-core Macs).
  - Known games launch directly, skipping Steam's launch-options dialog, which doesn't render under Wine.
- **Double-launch guard:** Play in the Library ignores repeat clicks for 20 seconds.

### Changed
- Engine downloads now come from the `engine-4` release. Sili 1.1.x stays on engine 3.x.
- Wine Mono/Gecko install prompts are skipped (they hung bottle setup), and Wine no longer adds Mac
  menu entries for installed programs.

### Fixed
- Bottle creation hanging on the Wine Mono prompt.
- Steam's window staying black.

## [1.1.0] - 2026-10-21

### Added
- **Game Library**: a new sidebar section showing every game across all bottles in one grid.
  - Finds Windows Steam games automatically (including extra Steam library folders on other drives) plus pinned programs.
  - Cover art from Steam's local cache, then Steam's CDN, then the program's own icon.
  - Hover to Play, or double-click. Steam games launch through the bottle's Steam (`steam://rungameid/`).
  - Search, sort by name, recently played or bottle, and right-click to Show in Finder, Open Bottle or Create Dock Shortcut.
- Dock shortcuts for Steam games, with the game's cover art as the icon.
- Unit tests for the library scanner (`swift test` in `WhiskyKit`).

### Changed
- WhiskyKit now fetches SemanticVersion over HTTPS instead of SSH, so it builds without GitHub SSH keys.

## [1.0.0] - 2026-10-21

The first release of Sili, a maintained fork of [Whisky](https://github.com/Whisky-App/Whisky).

### Added
- Sili name, glossy chilli app icon and bundle ID (`com.mayonstudios.sili`).
- Automatic app updates through Sparkle, signed with Sili's own key.
- `scripts/build-engine.sh` to build the Wine engine from upstream releases.
- `scripts/release.sh` to version, build, sign and publish releases.

### Changed
- Wine engine updated to Wine Staging 11.18 (from a 2022 CrossOver 22-based build).
- DirectX 10/11 games now go through DXMT (Direct3D to Metal).
- The engine now downloads from this repo's `engine` release instead of the offline `data.getwhisky.app`.
- The command-line tool is now `sili`.

### Fixed
- First-run setup failing because the original engine server is offline.
- Wine 9+ compatibility: use the unified `wine` loader instead of `wine64`.
- Crash at launch for self-built copies: ad-hoc builds now turn off hardened runtime so the embedded Sparkle framework loads.
