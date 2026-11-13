# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

A **personal fork of Boring Notch** (v2.7.3): a macOS menu-bar app (SwiftUI + AppKit, macOS 14+) that draws a widget area around the MacBook notch. It is being redesigned into a minimal Dynamic-Island-style app with only an **Apple Music player**, a **battery and charging indicator** (the volume / brightness HUD replacement was removed), plus a lock/unlock animation.

**`REDESIGN.md` is the source of truth for what to build.** Read it before changing anything. If the code and `REDESIGN.md` disagree, ask.

## Current phase

**Done and building:** the strip-down, the expanded Island music player, the lock/unlock animation and the battery / charging popups (`REDESIGN.md` top section has details). **Remaining:** polish only. **Dropped:** the HUD replacement (and its XPC helper) and the Focus popup. Do not start remaining work until the user asks for it. Follow the phase order in `REDESIGN.md` §7, one phase at a time, and keep the app building after each.

## Planned additions (approved, one at a time, in this order)

The user picked these on 2026-11-12. Start one only when they say so; build and let them look at it before moving to the next. Details and constraints are in `REDESIGN.md` §13.

1. **Swipe to skip on the closed pill.** Built; the user confirmed it works (strong double haptic). The track-change "roll" peek (REDESIGN.md §14) is built and awaiting their check. Swipe left = next, right = previous (two-finger trackpad swipe or click-drag); a tap still opens the notch.
2. **Mic and camera in-use dot.** Orange (mic) / green (camera) dot beside the notch, as on the iPhone island. Must be checked against the App Sandbox before promising it works (public CoreMediaIO / CoreAudio "running somewhere" properties).
3. **Paused state.** Built, awaiting the user's check. A quiet pause glyph in the closed pill before it hides, instead of a plain fade.
4. **Timer.** Countdown started from a global shortcut, shown in the closed notch. Needs an input UI and a shortcut; ask before choosing either.

Not approved (don't add): next meeting / Calendar, weather, clipboard or file shelf, volume or brightness.

## Rebrand: the product is **Moonpool**

Launch plan is deliberately small: a **public GitHub repo only**, a side project. No website page, DMG hosting, notarization or Mac App Store work unless the user asks later. Open source under GPL-3.0. Credit goes to the original authors: the README's copyright section credits TheBoredTeam and contributors and names no individual; do not add personal names, personal websites or local paths to the README, source or this file.

Done: display name, `PRODUCT_NAME`, menu title, settings window title and Quit/Restart strings are "Moonpool"; bundle ID `xyz.kvrma.moonpool` (settings from the old ID do not carry over); the menu bar icon is a drawn cratered moon (`MoonIcon` in `boringNotch/boringNotchApp.swift`, a template image) which the user likes; the README is rewritten with credits and licensing; upstream leftovers are deleted; unused clipboard / microphone / backlight shortcuts are removed.

README repo links use `khushalv21/Moonpool`; fix them if the real repo differs.

The app icon is option A "Midnight": a near-black macOS squircle with the cratered moon (same geometry as `MoonIcon`), rendered to `Assets.xcassets/AppIcon.appiconset` (10 PNGs, 16 to 1024 px); the unused upstream image sets were deleted. Still to do: `git init`, and a "Moonpool" name / trademark check by the user. Internal type and folder names (`BoringNotchSkyLightWindow`, `boringNotch/`, the scheme) keep their old names on purpose.

## Repo facts

- Git repository initialized on branch `main` (no commits yet). The pre-strip history of the upstream project is not included. Don't commit, push or create branches unless asked.
- Xcode project: `boringNotch.xcodeproj`, one target and scheme, `boringNotch`.
- **Project file editing:** source files are listed explicitly in `project.pbxproj` (only `boringNotch/private/` is a synchronized folder). Adding or deleting a Swift file means editing the pbxproj too, otherwise it silently isn't compiled or the build breaks. Run `plutil -lint boringNotch.xcodeproj/project.pbxproj` after any hand edit.
- README says building needs macOS 15.6+ and Xcode 26+. The deployment target is macOS 14.0.
- License is GPL-3.0 (inherited from Boring Notch, so the fork must stay GPL-3.0 and publish its source). Keep `LICENSE`, `THIRD_PARTY_LICENSES`, and the original copyright lines in source file headers; add the user's own line beside them, never replace them.
- There is no CI. The upstream `.github`, `Configuration/` (DMG scripts), `.devcontainer`, `crowdin.yml`, `CONTRIBUTING.md` and `SECURITY.md` were deleted on purpose (this becomes the user's own GitHub repo). A backup is in the session scratchpad only.
- Verified build: clean `BUILD SUCCEEDED`, one old Swift 6 warning (`rebuildCache()` in `NSScreen+UUID.swift`). The signed release build installs to `/Applications/Moonpool.app` (Apple Development certificate; pass `CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=<your team id>`). First build resolves packages over the network.

```bash
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -destination "generic/platform=macOS" build CODE_SIGNING_ALLOWED=NO
```

## Layout

| Path | Purpose |
|---|---|
| `boringNotch/boringNotchApp.swift` | `@main` app plus `AppDelegate`: creates the notch window(s), screen changes, **lock/unlock notification handling**, global shortcuts. |
| `boringNotch/ContentView.swift` | Root notch view: shape, hover/gesture handling, closed/open layout, music live activity, lock and battery popups. The biggest coupling point. |
| `boringNotch/BoringViewCoordinator.swift` | Shared `@MainActor` singleton for `sneakPeek` / `expandingView` state, lock/unlock transition, screen selection. |
| `boringNotch/models/BoringViewModel.swift` | Per-screen notch state: `open()` / `close()`, sizes, fullscreen hiding. |
| `boringNotch/models/Constants.swift` | **All `Defaults` keys** (settings) and shared enums. |
| `boringNotch/sizing/matters.swift` | Notch geometry: `openNotchSize`, `cornerRadiusInsets`, `getClosedNotchSize()`. |
| `boringNotch/components/Notch/` | `NotchShape`, `BoringHeader`, `NotchHomeView` (music UI and `CustomSlider`), `BoringNotchSkyLightWindow`. |
| `boringNotch/components/Settings/` | `SettingsView` (one short form) and `SettingsWindowController`. |
| `boringNotch/components/Live activities/` | Battery views and marquee text. |
| `boringNotch/managers/` | `MusicManager`, `BatteryActivityManager`, `NotchSpaceManager`. |
| `boringNotch/observers/` | `FullscreenMediaDetection` (hides the notch over fullscreen video). |
| `boringNotch/MediaControllers/` | `MediaControllerProtocol` and `AppleMusicController` (AppleScript based). The only music source. |
| `boringNotch/private/CGSSpace.swift` | Private-API window space used to draw over the lock screen. |

## Conventions (follow what's there)

- SwiftUI views with `@ObservedObject` / `@EnvironmentObject`; shared state in `@MainActor` singletons exposed as `.shared` (`MusicManager.shared`, `VolumeManager.shared`, `BoringViewCoordinator.shared`).
- Settings use the **Defaults** package. Add keys to `Defaults.Keys` in `Constants.swift`; read with `Defaults[.key]` or `@Default(.key)`.
- Cross-object events go through `NotificationCenter` names declared at the bottom of `boringNotchApp.swift` and in `Constants.swift`.
- Concurrency: `Task` / `async`/`await`; UI work on `@MainActor`. Existing code uses `Task.sleep(for:)`, not `DispatchQueue.asyncAfter`, for new timers.
- Animation: springs live in `ContentView`. New motion should use the named tokens in `REDESIGN.md` §3.5 rather than new ad-hoc numbers.
- Notch geometry always comes from `getClosedNotchSize()`. Never hard-code the notch width or height.
- Match existing file headers, 4-space indent, and the surrounding comment density. Don't add comments that restate the code.

## Gotchas

- **App Sandbox is on.** Anything touching new system resources needs an entitlement in `boringNotch/boringNotch.entitlements` and, where relevant, a usage string in the build settings (`INFOPLIST_KEY_*`; `Info.plist` itself is empty). Current entitlements: sandbox, Apple events, and a temporary Apple-events exception for `com.apple.Music` only. There is no network entitlement, so any new network code needs `com.apple.security.network.client` added.
- **Private APIs** (SkyLight, CGS spaces, MediaRemote) can break with macOS updates. Don't "clean up" `CGSSpace.swift` or `BoringNotchSkyLightWindow.swift` without testing on a real lock screen.
- **Lock/unlock timing.** `onScreenUnlocked` deliberately waits 150 ms before disabling SkyLight to avoid flicker. Any lock animation has to account for that delay (`REDESIGN.md` §6.3).
- **Multi-display** support (`showOnAllDisplays`) creates one window and `BoringViewModel` per screen in `AppDelegate`. Keep per-screen state out of singletons.
- The `components/Live activities` folder name contains a space. Quote paths in shell commands.
- `README.md` is the user's own and reads as a personal side project. Keep it short: credit to Boring Notch is a single line under the tagline (plus the GPL-3.0 badge); there is deliberately no install, build or long credits/licensing section. The legal side lives in `LICENSE`, `THIRD_PARTY_LICENSES` and the original copyright headers in source files, which must stay.

## Working rules for this project

1. Plan first. For anything larger than a one-file fix, say which `REDESIGN.md` section it implements.
2. Small steps, build after each. Don't batch a whole phase into one unverifiable change.
3. Visual changes can't be verified by compiling. Say so plainly, and ask the user to look at the notch or run the app (`run` skill) before calling UI work done.
4. Never claim a lock-screen behaviour works without it being tested on the machine. The user has tested lock/unlock, plug/unplug and multiple displays on their Mac and says they work; anything new still needs their check.
5. Don't add features outside `REDESIGN.md` §1 without asking.
   Source-of-truth decisions so far: Apple Music only, no HUD replacement, no keyboard backlight, no Focus popup. The only approved additions are the four under "Planned additions".
6. Don't commit, push or create branches unless asked.
