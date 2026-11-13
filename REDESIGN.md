# REDESIGN.md — Personal Boring Notch

Status: **Done:** Part 1 (strip-down), the expanded Island music player, the lock/unlock padlock animation, and the battery / charging popups (plugged in, on battery, charging, on power, fully charged, low power). **Dropped:** the volume/brightness HUD replacement (code, XPC helper process and Accessibility requirement all removed, macOS handles volume and brightness itself) and the Focus popup. **Not done:** final polish. This file is the spec; each remaining part starts only when explicitly asked.

### Decisions made (override anything below that says otherwise)

- **Music source: Apple Music only.** Now Playing, Spotify and YouTube Music are gone, along with the `mediaremote-adapter` framework.
- **Control centre = the system HUD replacement for volume and brightness.** No persistent sliders in the expanded view (so the "HUD + sliders" default in D2 and §4.2 is dropped).
- **No keyboard backlight**, and no mic HUD.
- **Battery = battery and charging indicator** (header capsule plus the plug-in / unplug event).

### Part 1 result (what the strip-down actually did)

- Removed the shelf (and AirDrop/QuickShare, drag detection), calendar/reminders, webcam mirror, downloads activity, tabs, extras menu, edit panel, test view, tips, what's-new, onboarding, hello animation and sound, face animation, Lottie, Sparkle updater, lyrics, favourites, per-slot music controls, and the Spotify / YouTube Music / Now Playing controllers.
- Removed the keyboard backlight code (`KeyboardBacklightManager`, the `.backlight` and `.mic` HUD types, and the XPC helper's keyboard methods). The keyboard brightness keys are no longer intercepted, so macOS handles them natively.
- Removed packages from the Xcode project: Sparkle, Lottie, SwiftUIIntrospect, Pow, swift-collections. Remaining: AsyncXPCConnection, MacroVisionKit, SkyLightWindow, LaunchAtLogin-Modern, KeyboardShortcuts, Defaults.
- Deleted the `mediaremote-adapter/` and `updater/` folders.
- `SettingsView.swift` went from 1,799 lines to a single short form (general, notch, Apple Music, volume/brightness HUD, battery). `SettingsWindowController` no longer needs Sparkle.
- Entitlements are now: sandbox, Apple events, and a temporary Apple-events exception for `com.apple.Music`. Info.plist is empty (Sparkle and App Transport Security keys gone). Camera, calendar and reminders usage strings removed from the build settings. No network use remains, so `network.client` / `network.server` were dropped.
- Swift code went from about 17.7k lines to about 6.2k lines.
- Verified with a clean unsigned Debug build (`BUILD SUCCEEDED`). The only warnings are Swift 6 Sendable / actor-isolation warnings in `XPCHelperClient.swift` and one `rebuildCache()` call, none from removed code. **Not verified:** that the app launches and behaves, that the sandboxed signed build still talks to Music and the XPC helper, and that the HUD replacement still works. Those need running the app.

### Left over on purpose (small, harmless, remove in Part 2 if unwanted)

- Shuffle / repeat / volume plumbing in `MusicManager`, `AppleMusicController` and `PlaybackState` (no UI uses it now).
- `Localizable.xcstrings` still has strings from removed screens.
- `.github/`, `Configuration/dmg/`, `crowdin.yml`, `.devcontainer`, `THIRD_PARTY_LICENSES` (still lists removed packages).
- `ContentView.swift` has some odd indentation where the hello-animation branch was removed. It will be rewritten in Part 2.
- Multi-display support, the toggle-notch and sneak-peek keyboard shortcuts, and hover / tap / pan gestures are still there (D3–D5 defaults).

Base: Boring Notch v2.7.3 (SwiftUI, macOS 14+, ~17.7k lines of Swift). This is a personal fork. It will never be distributed, so we do not need onboarding, auto-update, localisation, or feature breadth.

## 1. Goal

Turn Boring Notch into a small, calm, Dynamic-Island-style companion with exactly three jobs:

1. **Music player** — redesigned to feel like iPhone's Dynamic Island.
2. **Control centre** — volume and brightness only.
3. **Battery indicator.**

Plus one new flourish: a **lock / unlock animation** in the notch.

Everything else goes.

---

## 2. Part 1 — Strip down

Rule: remove a feature completely (files, Defaults keys, settings UI, entitlements, packages), not just hide it behind a toggle. Before deleting each item, grep for its type names. Several removed features are referenced from the files we keep (`ContentView`, `BoringViewModel`, `BoringViewCoordinator`, `BoringHeader`).

### 2.1 Keep

| Feature | Where it lives today | Notes |
|---|---|---|
| Music state and controls | `managers/MusicManager.swift`, `MediaControllers/*`, `models/PlaybackState.swift` | Trim lyrics, favourites and the YouTube Music controller (see 2.2). |
| Closed-state music live activity | `ContentView.MusicLiveActivity()` | Rebuilt in Part 3. |
| Volume | `managers/VolumeManager.swift` | Core Audio. `setAbsolute`, `increase`, `decrease`, `toggleMuteAction` already exist. |
| Brightness | `managers/BrightnessManager.swift` | The screen-brightness part only (see keyboard backlight below). |
| HUD replacement | `observers/MediaKeyInterceptor.swift`, `components/Live activities/{InlineHUD,OpenNotchHUD,SystemEventIndicatorModifier}.swift` | Needs the Accessibility permission, which the XPC helper handles. |
| Battery | `managers/BatteryActivityManager.swift`, `models/BatteryStatusViewModel.swift`, `components/Live activities/BoringBattery.swift` | Both the header icon and the plug-in event. |
| Notch window and shape | `components/Notch/{BoringNotchWindow,BoringNotchSkyLightWindow,NotchShape}.swift`, `managers/NotchSpaceManager.swift`, `private/CGSSpace.swift`, `sizing/matters.swift` | The lock-screen animation depends on the SkyLight window. |
| XPC helper | `BoringNotchXPCHelper/`, `XPCHelperClient/` | Accessibility authorisation and brightness through the helper. |
| Fullscreen auto-hide | `observers/FullscreenMediaDetection.swift` (MacroVisionKit) | Keep so the island does not sit over fullscreen video. |
| Core plumbing | `boringNotchApp.swift`, `ContentView.swift`, `BoringViewModel`, `BoringViewCoordinator` | Heavily simplified. |
| Shared UI bits | `HoverButton`, `MarqueeTextView`, `MusicVisualizer` (Metal `visualizer.metal`), `CustomSlider` (inside `NotchHomeView.swift`) | Reuse as starting points. |
| Launch at login | `LaunchAtLogin-Modern` | Used only in `SettingsView`. |

### 2.2 Remove

| Feature | Files and symbols | Knock-on cleanup |
|---|---|---|
| **Shelf and AirDrop / QuickShare** | `components/Shelf/**` (all), `observers/DragDetector.swift`, `models/SharingStateManager.swift`, `FullScreenDropDelegate` / `GeneralDropTargetDelegate` in `ContentView`, `dragDetector` view | Drop-target state in `BoringViewModel` (`dragDetectorTargeting`, `generalDropTargeting`, `dropZoneTargeting`, `dropEvent`, `anyDropZoneTargeting`). `ShelfStateViewModel` refs in `BoringViewModel.close()`, `BoringViewCoordinator`, `BoringHeader`. `setupDragDetectors` in `AppDelegate`. Shelf Defaults keys. User-selected-file and bookmark entitlements. |
| **Calendar and Reminders** | `components/Calendar/BoringCalendar.swift`, `managers/CalendarManager.swift`, `models/{CalendarModel,EventModel}.swift`, `Providers/CalendarServiceProviding.swift` | `isHoveringCalendar`. Calendar Defaults keys. Calendar entitlement and Info.plist usage strings. |
| **Webcam mirror** | `components/Webcam/WebcamView.swift`, `managers/WebcamManager.swift` | `isCameraExpanded`, `toggleCameraPreview()`, the camera slot in `NotchHomeView`. Camera entitlement and usage string. |
| **Downloads live activity** | `components/Live activities/DownloadView.swift`, download sneak-peek type | `enableDownloadListener` and related Defaults. |
| **Tabs (Home/Shelf)** | `components/Tabs/*`, `NotchViews` enum, `coordinator.currentView` | The notch has one view now. |
| **Extras menu / edit panel / test view** | `BoringExtrasMenu`, `EditPanelView`, `ListItemPopover`, `TestView` | — |
| **Face animation** | `AnimatedFace.swift`, `BoringFaceAnimation()` in `ContentView` | `showNotHumanFace`. |
| **Onboarding, hello animation, what's-new, tips** | `components/Onboarding/*`, `animations/HelloAnimation.swift`, `WhatsNewView`, `Tips/TipStore`, `boring.m4a`, `AudioPlayer.playWelcomeSound` | `firstLaunch`, `helloAnimationRunning`, `showWhatsNew`. **Caveat:** onboarding is also what asks for music permission (`PermissionsRequestView`, `MusicControllerSelectionView`). Replace it with a tiny first-run prompt or a button in Settings. |
| **Sparkle auto-update** | `SoftwareUpdater.swift`, `updater/appcast.xml`, `SPUStandardUpdaterController` in `boringNotchApp`, `CheckForUpdatesView`, the Sparkle package | The menu bar "Check for updates" item. |
| **Lyrics** | Lyrics fetch/parse in `MusicManager` (`fetchLyricsFromWeb`, `parseLRC`, `lyricLine`), `enableLyrics` | Outbound network use, which is why `network.client` may become removable (see 2.5). |
| **Favourite, dislike, shuffle, repeat, skip ±15s, per-app volume slot** | `FavoriteControlButton`, shuffle/repeat in `MusicManager`, `MusicControlButton`, `MusicSlotConfigurationView`, `VolumeControlView` | The Island has a fixed layout: previous, play/pause, next. System volume lives in the control centre. |
| **YouTube Music controller** | `MediaControllers/YouTube Music Controller/*` (4 files) | Network and auth code. Also drop the `YouTubeMusic` case in `MediaControllerType`. |
| **Lottie** | `components/LottieView.swift`, `Music/LottieAnimationView.swift`, `useMusicVisualizer` fallback branch, the `lottie-spm` package | We keep only the Metal spectrum visualiser. |
| **Keyboard-backlight HUD** | `KeyboardBacklightManager` (in `BrightnessManager.swift`), `.backlight` sneak type, XPC keyboard-brightness methods | Not part of "volume and brightness". |
| **Mic HUD, shortcuts, extra settings** | `.mic` sneak type, `Shortcuts/*`, `KeyboardShortcutsHelper` | Decide in 2.4 whether to keep one "toggle notch" shortcut. |
| **Dead or likely-dead packages** | `Pow`, `swift-collections` (no `import` found in app code), `SwiftUIIntrospect` (only used by `ContentView`, `WelcomeView`, `SettingsView`), `LaunchAtLogin` if Settings shrinks | Re-run the import grep after each removal. |
| **Release tooling** | `Configuration/dmg/`, `.github/workflows/*` (except maybe a build check), `crowdin.yml`, `.devcontainer`, issue templates, `CONTRIBUTING.md` | Optional. These don't affect the app. Keep `LICENSE`. |

### 2.3 Settings window

`SettingsView.swift` is 1,799 lines. Replace it with a small window with only:

- **Music source:** Now Playing / Apple Music / Spotify.
- **Control centre:** HUD replacement on/off (this triggers the Accessibility prompt).
- **Lock animation:** on/off, plus "Reduce motion" follow-system.
- **Battery:** show percentage, plug-in event on/off.
- **Display:** which screen. Keep a single-display choice, or "all displays" if you use an external monitor (decision D3).
- **Launch at login.**
- **Hide in fullscreen.**

### 2.4 Decisions to confirm before stripping

| # | Question | Default if you don't answer |
|---|---|---|
| D1 | ~~Which media sources?~~ **Decided: Apple Music only.** | Done in Part 1. |
| D2 | ~~Control centre shape.~~ **Decided: system HUD replacement for volume and brightness only. No sliders, no keyboard backlight.** | See Part 3 (§4). |
| D3 | Multi-display (`showOnAllDisplays`, a window and view model per screen in `AppDelegate`). | Keep as is. It is entangled with window code, so removing it is risk with no benefit. |
| D4 | Keep any keyboard shortcut (toggle notch open)? | Keep one, drop the rest. |
| D5 | Hover-to-open, tap-to-open, pan gestures (`enableGestures`, `panGesture`). | Keep hover and tap. Keep the pan-down/up gestures if they feel good. They are cheap. |

### 2.5 Entitlements and Info.plist after stripping

`boringNotch/boringNotch.entitlements` currently grants: sandbox, Apple events (Spotify + Apple Music exceptions), camera, calendars, bookmarks (app + document scope), user-selected files read/write, network client, network server, and two Mach lookup names (`-spks`, `-spki`, which are Sparkle's installer services).

After stripping:

- **Remove:** camera, calendars, bookmarks, user-selected files, Sparkle Mach lookups.
- **Keep:** sandbox, Apple events (for whichever of Spotify/Music remain).
- **Verify before removing:** `network.client`. Album art may be fetched by URL and cached. `network.server` looks unused once the shelf is gone.
- Remove camera and calendar usage-description strings from `Info.plist`.

---

## 3. Part 2 — Dynamic Island music player

### 3.1 What "Dynamic Island" means here

On iPhone the Island is a black capsule that **morphs**: it never swaps between separate screens, it grows and shrinks, and its contents blur and scale in and out of the same shape. A MacBook notch is a hardware cutout, so the black shape can only grow **outward from the notch** (sideways into the menu bar and downward over the screen). The design target is that feel on that constraint.

The app already contains the pieces: `NotchShape`, a shared `Namespace` with `matchedGeometryEffect` on album art and spectrum, and spring animations in `ContentView`. The redesign is mostly a **re-spec of shape, size, motion and layout**, not new plumbing.

### 3.2 States

The island has four states. They replace today's closed / sneak-peek / inline / open set.

| State | When | Shape |
|---|---|---|
| **Idle** | Nothing playing, no events | Exactly the hardware notch. Invisible. |
| **Compact** | Music playing or paused-but-loaded | Notch plus a "wing" on each side. Left: 20 pt rounded album art. Right: live spectrum, tinted by album colour. This is today's `MusicLiveActivity`, but with the wings merged into the notch silhouette. |
| **Minimal** | A transient event (volume/brightness, charging) takes priority while music plays | Compact collapses to a small leading dot of art plus the event glyph, like iOS handing the island to another activity. |
| **Expanded** | Hover or click | Rounded rectangle hanging below the notch. Large album art, title/artist, scrubber, previous / play-pause / next, and the control centre sliders (Part 4). Battery pill in the top-right corner. |

Event priority (highest first): volume/brightness HUD → charging event → lock/unlock → music compact → idle. Only one owner at a time. Replace the scattered `sneakPeek` / `expandingView` / `musicLiveActivityEnabled` logic in `ContentView` and `BoringViewCoordinator` with a single **island state enum** that these cases map onto.

### 3.3 Geometry

Starting numbers, to tune on the real notch. Every one of them is a visual guess until seen on screen.

- **Hardware notch** width and height: read from `getClosedNotchSize()` (≈ 185 + 4 pt wide; height from `safeAreaInsets.top`). Never hard-code.
- **Compact:** the wings are about notch height wide each. The art is `notchHeight − 12` square (today's value). Total width = notch + 2 wings.
- **Expanded:** about 400 × 170 pt, down from today's 640 × 190 (`openNotchSize`), since the calendar and camera panes are gone. `windowSize` is derived from this, so the hosting window shrinks too. Keep the 20 pt `shadowPadding`.
- **Corner radii:** today closed = 6 top / 14 bottom, open = 19 top / 24 bottom (`cornerRadiusInsets`). The Island look wants a **much rounder bottom** when expanded (about 36–40 pt) while keeping the small top radius that blends into the bezel. Try it and judge by eye.
- Pure black fill (`.black`), no border, no material. That is what makes it read as the same object as the hardware notch. Keep the existing 1 pt top overlay that hides the seam.

### 3.4 Expanded layout

```
┌────────────────────────────────────────────┐   ← flush with the notch at top
│ ┌──────┐  Song title (marquee)        🔋 82%│
│ │ art  │  Artist · tinted by art colour     │
│ │ 72pt │                                    │
│ └──────┘  ━━━━━━━●━━━━━━━━━━━  1:12 / 3:40  │
│                                              │
│            ⏮     ⏯     ⏭                    │
│   🔊 ━━━━━━━●━━━         ☀ ━━━━●━━━━━━      │
└────────────────────────────────────────────┘
```

- **Album art:** about 72 pt, 16 pt corner radius, with a soft glow of its colour behind it (the existing `lightingEffect` blur, kept subtle). Art scales to about 0.85 while paused, as today.
- **Text:** title in `.headline` white, artist in the `avgColor` tint (`ensureMinimumBrightness`), both through `MarqueeText`.
- **Scrubber:** Island-style. It grows taller while dragging (the existing `CustomSlider` already does 5 → 9 pt), with elapsed and remaining time under it.
- **Transport:** previous, play/pause, next. Large play/pause in the middle. Press-scale haptic feel.
- **Control centre row:** two sliders, volume and brightness (Part 4).
- **Battery:** small capsule, top-right, beside the notch. It keeps the existing popover behaviour.
- Fixed layout. No configurable slots.

### 3.5 Motion spec

Use a few named springs rather than ad-hoc numbers. Today `ContentView` mixes `interactiveSpring(0.38, 0.8)`, `spring(0.42, 0.8)` for open and `spring(0.45, 1.0)` for close.

| Token | Use | Starting values |
|---|---|---|
| `island.morph` | Shape size/radius changes between states | spring, response ≈ 0.45, damping ≈ 0.78 (slight overshoot) |
| `island.content` | Content fade/scale in a state | `.smooth(duration: 0.3)` |
| `island.close` | Collapse | spring, response ≈ 0.4, damping ≈ 0.95 (no bounce) |
| `island.press` | Button press | interactive spring, response 0.25, damping 0.7 |

Transitions:

- **Idle → Compact:** wings extend from the notch edges; art and spectrum fade in with a blur-to-sharp transition (blur 12 → 0) after the shape has started to grow.
- **Compact → Expanded:** the shape morphs and the art travels via `matchedGeometryEffect` from the small wing to the large slot. Text and controls fade in staggered by about 40 ms, from the top down. Content that is leaving blurs out fast (about 120 ms) so it never overlaps.
- **Expanded → Compact:** reverse. Content blurs out first, then the shape shrinks.
- **Track change:** art cross-dissolves with a small scale pulse (0.96 → 1). Title/artist slide up and fade. The existing `isFlipping` / `isTransitioning` flags in `MusicManager` can drive this.
- **Play ↔ pause:** art scale 1 ↔ 0.85, the spectrum freezes to a flat line and then fades.
- Hover feedback in Compact: a 1–2 pt grow plus the haptic that already exists (`enableHaptics`).

Respect **Reduce Motion**: replace the morph and blur with a simple cross-fade (`accessibilityReduceMotion`).

### 3.6 What changes in the code (for later, not now)

- `ContentView.swift` is 660 lines and mixes layout, event routing, hover logic and music UI. Split it into: island container (shape + state), `CompactMusicView`, `ExpandedMusicView`, event overlays.
- `NotchHomeView.swift`: rewrite `MusicPlayerView` / `MusicControlsView` for the layout above. Keep `CustomSlider` and `MusicSliderView`'s playhead interpolation logic (`estimatedPlaybackPosition`).
- `sizing/matters.swift`: new `openNotchSize`, radii, and image sizes.
- `NotchShape.swift`: confirm it can animate its radii (`animatableData`). If not, that is a small change.

---

## 4. Part 3 — Control centre (volume and brightness)

Reality check: **this app has no standing volume/brightness controls.** `toggleSneakPeek` (in `BoringViewCoordinator`) drops non-music HUDs unless `hudReplacement` is on. The HUDs only appear when `MediaKeyInterceptor` catches a media key. The only "volume" in the music view is a per-app slider that talks to Music/Spotify, not the system.

So the control centre needs two parts:

### 4.1 Transient HUD (exists, restyle)

Pressing volume/brightness keys → the island shows a pill: glyph on the left, a thin fill bar, optional percentage. Uses `InlineHUD`, restyled to the Island look and morphing from whatever state the island is in (Minimal if music is playing).

- Keep `MediaKeyInterceptor`'s event tap and feedback sound.
- Fix the glyph by level (`speaker.1/2/3.fill`, `speaker.slash.fill`, `sun.min/max.fill`).
- Auto-dismiss after about 1.5 s (the current default).

### 4.2 Persistent sliders in the Expanded view — **dropped**

> You decided on the HUD replacement only. The text below is kept for reference and is not planned. Also ignore the Expanded layout's slider row in §3.4.

Two horizontal sliders: **volume** (🔊) and **brightness** (☀).

- Volume: bind to `VolumeManager.shared.rawVolume`; write with `setAbsolute(_:)`; mute toggle on tapping the glyph (`toggleMuteAction`).
- Brightness: bind to `BrightnessManager.shared.rawBrightness`; write with `setAbsolute(value:)`.
- Reuse `CustomSlider`. Throttle writes while dragging (the existing music volume slider throttles at 0.1 s).
- While you drag a slider, the island must not auto-close. The hover logic in `ContentView.handleHover` closes it after 100 ms of no hover; confirm drags keep it open.

Open question for later (not blocking): internal-display brightness goes through the XPC helper (`setScreenBrightness`). External monitors usually won't respond. Show the slider disabled when `isScreenBrightnessAvailable` is false.

---

## 5. Part 4 — Battery indicator

Keep `BatteryActivityManager` and `BatteryStatusViewModel` as they are. Redesign only the presentation.

- **Always (Expanded):** small capsule top-right with percentage. Charging bolt when charging, a leaf when in Low Power Mode, and red at or below 20 %. This is `BoringBatteryView`, reskinned.
- **Event (plug-in / unplug / full):** an Island activity. The island widens (today it forces a 640 pt chin for this, which is far too big). Left shows the status text ("Charging", "Fully charged"), right shows the battery glyph, and it holds for about 2.5 s, then collapses. Plug-in uses the Minimal → Compact morph so it doesn't feel like a different component.
- Drop: `showPowerStatusIcons`, the popover with time-to-full if you don't want it (D6, optional), and the `batterySneakSize` constant.

---

## 6. Part 5 — Lock / unlock animation

### 6.1 What is available today

`AppDelegate` already subscribes to the system lock notifications:

- `com.apple.screenIsLocked` → `onScreenLocked`. When `showOnLockScreen` is false it calls `cleanupWindows()` (the notch window is closed). When true it calls `enableSkyLightOnAllWindows()`.
- `com.apple.screenIsUnlocked` → `onScreenUnlocked`. When `showOnLockScreen` is false it re-creates the window with `adjustWindowPosition(changeAlpha: true)`. When true it disables SkyLight after a 150 ms delay "to avoid flicker".

`BoringNotchSkyLightWindow` + `CGSSpace` are what let the notch window draw above the lock screen. `showOnLockScreen` defaults to **false**.

### 6.2 Design

A short, quiet padlock moment. It is not a full-screen effect.

**Lock**

1. The island morphs from Idle/Compact into a small centred pill the width of the notch plus a little (the Minimal shape).
2. A padlock glyph appears in the pill. It starts open (`lock.open.fill`) and **closes** (`lock.fill`) using SF Symbols' replace transition with a short bounce.
3. A 1-frame brightening pulse on the pill outline, in white at about 20 % opacity.
4. Hold about 0.6 s, then collapse back to Idle (or Compact if music is playing).
5. Total ≈ 1.0 s.

**Unlock**

1. The island appears as the same pill with the padlock **closed**.
2. The padlock **opens** (`lock.fill` → `lock.open.fill`) with a small shackle lift.
3. A soft accent-coloured pulse (use `Color.effectiveAccent`) spreads once from the centre to the edges of the pill.
4. Hold about 0.4 s, then collapse back to Idle / Compact.
5. Total ≈ 0.9 s.

Rules:

- Lock and unlock animations are interruptible. A new event cancels the running one cleanly.
- If music is playing, the Compact wings come back as the pill collapses, so there is no flash of empty notch.
- **Reduce Motion:** no bounce, no pulse; the padlock simply cross-fades between states.
- No sound.

### 6.3 The hard parts (verify on a real machine before promising anything)

1. **Visibility at the moment of lock.** The window only draws over the lock screen if SkyLight is enabled. The lock animation therefore needs `showOnLockScreen` to be effectively **on**. It should be implied by the "lock animation" setting, not a separate toggle. When the animation is on, the app must keep its window across the lock (never run `cleanupWindows()` on lock).
2. **Timing of the notifications.** `screenIsLocked` may fire after the lock screen is already up, so the "closing" animation might begin a beat late. Plan to test on the real machine and offset the animation if needed. We can't assume the timing from reading code.
3. **Unlock flicker.** `onScreenUnlocked` disables SkyLight after 150 ms. The unlock animation runs for about 0.9 s, so that delay has to be extended until the animation finishes. The window must stay SkyLight-enabled for the whole animation, or the island will pop in or out of the lock-screen layer mid-animation.
4. **No "authenticating" signal.** macOS gives us locked and unlocked events only. We cannot show a progress or Touch ID state. The unlock animation plays *after* success.
5. **Display asleep.** If the display is off when the lock event fires, the lock animation is wasted. Consider `NSWorkspace.screensDidSleepNotification` / `screensDidWakeNotification` to skip or defer it. Needs testing.
6. **Multi-display.** With `showOnAllDisplays`, each window has its own view model. The animation should run on every notch window, or only the primary one. (Default: all.)
7. **Private API.** SkyLight / CGS space calls are private macOS API and can break on OS updates. This is an existing risk in the project, not a new one.

### 6.4 Implementation shape (for later)

A new island state `.lockTransition(.locking | .unlocking)` set from `onScreenLocked` / `onScreenUnlocked`, with a timed return to the previous state. `AppDelegate` stops owning window lifecycle decisions for lock events beyond SkyLight on/off.

---

## 7. Suggested order of work

Each phase should leave the app building and running.

1. **Strip.** Remove features in this order: Shelf → Calendar → Webcam → Downloads → Tabs → Lottie → face/onboarding/what's-new → lyrics/favourites/YouTube Music → Sparkle → backlight/mic → entitlements and packages. Build after each. Shrink `SettingsView`.
2. **Island state model.** One enum, one owner, existing visuals. No design change yet.
3. **Compact + Expanded music UI** (Part 2) with the new geometry and motion tokens.
4. **Control centre** (Part 3): restyle the HUD, then add sliders.
5. **Battery** restyle (Part 4).
6. **Lock / unlock animation** (Part 5), tested on the real machine.
7. **Polish:** Reduce Motion, haptics, app icon, performance check.

## 8. Acceptance checklist

- [x] Builds with Xcode, no warnings from removed code, no unused packages (Part 1).
- [ ] Only music, volume/brightness and battery are reachable anywhere in the UI.
- [ ] Idle notch is indistinguishable from the bare hardware notch.
- [ ] Compact → Expanded → Compact morphs without a visible swap or jump.
- [ ] Media keys show the HUD; the expanded sliders move the real system volume and brightness.
- [ ] Plug and unplug show the battery event, then collapse.
- [ ] Lock and unlock each play the padlock animation once, with no flicker, with and without music playing.
- [ ] Reduce Motion turns the animation into a cross-fade.
- [ ] Hide-in-fullscreen still works.
- [ ] Idle CPU is low (spectrum and scrubber timelines only run while visible and playing).

## 9. Out of scope

Weather, Bluetooth activity, extension system, notifications, widgets, themes, localisation, distribution/notarisation, any new data source.

## 10. Risks

- **Private APIs** (SkyLight, CGSSpace, MediaRemote via `mediaremote-adapter`) can break on any macOS update. The app is a hobby tool, so accept that.
- **Stripping coupling.** `BoringViewModel`, `BoringViewCoordinator`, `ContentView` and `BoringHeader` all reference features we're removing. Work in small steps and build often.
- **No git history.** The folder has no `.git`. Run `git init` and commit the pristine copy **before** step 1 of the plan so every removal is reversible.
- **Licence.** The project is GPL-3.0. A personal fork is fine, but keep `LICENSE` and the notices in `THIRD_PARTY_LICENSES` if you ever share it.

## 10. Update: HUD replacement removed

The system HUD replacement was removed after it could not be made reliable. Removed: `MediaKeyInterceptor`, the inline / open-notch / indicator HUD views, `VolumeManager`, `BrightnessManager`, the whole `BoringNotchXPCHelper` target (and its embedded XPC service), the AsyncXPCConnection package, the HUD settings, and the Accessibility prompt. The app now has one target and no helper process. Parts 3 (§4) above no longer apply.

## 11. Update: track-change popup

The old track-change popup (wide 380pt bar, restarting marquee text, stray characters) was replaced. When the song changes the closed notch grows two symmetric wings: art and title on the left, artist and spectrum on the right. The shape grows first with a spring, then the text fades in after about 0.16 s, then it collapses. Text uses plain single-line labels with tail truncation (no marquee). The "standard" sneak-peek style and its setting were removed. The invisible window is now at least 540pt wide so the wings are not squeezed.

## 12. Update: expanded music view, second pass

Rebuilt to Apple's grid. Hierarchy: title 15 semibold white; artist 13 regular at 60% white (neutral, no longer tinted); a 4 pt progress capsule that grows to 8 pt while dragging, tinted by the album colour; times below the bar in 11 pt tabular numerals; transport row with prev / play-pause / next and a quiet AirPlay button; small visualizer beside the title. The header band is balanced around the notch: settings gear on the left, battery on the right, both on the same 20 pt margins as the content. The open notch body is 400 x 184 pt. Note for layout work: the notch shape's top "ears" make the visible body 19 pt narrower per side than its frame, so horizontal padding is `opened.top + margin`.

## 13. Update: planned additions (approved 2026-11-12)

Chosen from a longer list; built one at a time, in order. Rule for all of them: the notch shows one thing at a time and music stays the main job, so nothing here may add a permanent element to the closed or open view.

1. **Swipe to skip (closed pill).** Horizontal swipe on the music pill = previous / next track, with the artwork and text nudging in the swipe direction and springing back (interruptible). Tap still opens. Only active while music is playing or just paused.
2. **Mic / camera dot.** Small orange (mic) or green (camera) dot next to the notch while a device is in use; shape must differ from colour alone (e.g. dot beside a mic or camera glyph in the popup). Verify the sandbox allows reading device "in use" state before building; if not, drop it rather than add entitlements without asking.
3. **Paused state.** When playback pauses, the closed pill swaps the visualizer for a pause glyph and holds for the idle wait interval, then hides. No new settings.
4. **Timer.** Global shortcut starts a countdown shown as a closed-notch live activity (time in tabular digits, tinted ring or bar). Open questions to ask the user first: how the duration is entered, and what the shortcut is.

Explicitly not planned: next-meeting (Calendar permission), weather, clipboard / file shelf, volume and brightness.

## 14. Update: track-change roll peek

Every real track change (swipe, media keys, song ending) now shows the title popup, always on: the "Show the song name when it changes" setting and its `enableSneakPeek` key were removed. Resuming from pause no longer triggers it. The closed pill widens, and artwork, title and artist rise 12 pt from below with a 50 ms / 90 ms stagger (spring, response 0.34, no bounce); the old content just fades in 100 ms. Hold is 2 to 3.5 s depending on title length, then it collapses. Reduce Motion handling still to verify in the app.

### 14.1 Swipe direction glyph

While swiping the closed pill, the content shifts up to 10 pt and a skip glyph (SF Symbols `forward.fill` on the right for next, `backward.fill` on the left for previous) fades in on the opposite side, tied to finger progress. At the 36 pt threshold the skip fires, the glyph pulses once (spring 0.3 / 0.55), holds about 0.65 s, then everything eases back over 0.4 to 0.55 s. Reduce Motion: no slide or pulse, glyph still fades.

## 15. Update: lock and battery popups, second pass

Lock and unlock: one custom padlock drawn from shapes, always white (no green). Locking: shackle drops with a spring and the body presses in 0.5 pt. Unlocking: shackle lifts 3 pt and swings open 22 degrees. Label ("Locked" / "Unlocked") on the left, padlock on the right, same wing width (98 pt) as the battery popups. Reduce Motion: final state only.

Battery popups: label left, percentage plus a shape-drawn battery on the right. The fill sweeps from empty to the real level (spring 0.6, no bounce) while the percentage rolls up; the mark lands once afterwards (bolt, plug, check, warning). Nothing loops (the old charging pulse is gone). Labels: Charging, Plugged in, Not charging, On battery, Low battery, Fully charged, Low Power On / Off. Plugging in waits 0.6 s so "Charging" replaces "Plugged in" (one popup, not two). Low battery now warns at 20% and again at 10% while unplugged. Fills: green for charging and fully charged, white for plugged / on battery, red at 20% or below, yellow for Low Power Mode.

