<p align="center">
  <img src="assets/icon.png" width="128" alt="Moonpool app icon">
</p>

<h1 align="center">Moonpool</h1>

<p align="center">
  A calm, Dynamic-Island-style notch for Apple Music on your Mac.<br>
  Free and open source, based on <a href="https://github.com/TheBoredTeam/boring.notch">Boring Notch</a>.
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black">
  <img alt="License: GPL-3.0" src="https://img.shields.io/badge/license-GPL--3.0-blue">
</p>

---

## What it is

Moonpool turns the notch (or the top edge of any display) into a small, quiet live area, in the spirit of the iPhone's Dynamic Island. It does a few things and tries to do them well: it shows what Apple Music is playing, lets you control it, and tells you about the battery and the lock screen. It does not try to be a widget board.

It is a personal redesign of [Boring Notch](https://github.com/TheBoredTeam/boring.notch) by the Boring Team. See [Credits and licensing](#credits-and-licensing) for exactly what that means.

## Features

### Apple Music in the closed notch
- A small pill beside the notch shows the album art on one side and a live visualizer, tinted from the artwork, on the other.
- **Track changes announce themselves.** Whenever the song changes (a swipe, the media keys, or the song ending), the pill widens and the new artwork, title and artist roll up into place, hold for a moment, then fold away.
- **Swipe to skip.** Swipe left on the pill (two fingers on the trackpad, or click and drag) for the next track, right for the previous one. A skip arrow appears while you swipe, you get a firm haptic tick, and one swipe always skips exactly one song.
- **Pause and play states.** Pausing swaps the visualizer for a pause glyph and dims the artwork. After a short wait the pill folds back into the notch. Resuming shows a play glyph before the visualizer returns.

### The expanded player
Click the notch, swipe down on it, or press the shortcut to open a compact player:
- Album art, a scrolling title and the artist.
- A scrubber you can drag, with the elapsed time on the left and the time remaining on the right.
- Previous, play/pause and next, with a soft pressed animation.
- It only opens while Apple Music is playing (or has just been paused). With nothing playing, the notch stays out of the way.

### Lock and unlock animation
When you lock or unlock your Mac, a padlock appears beside the notch. Locking drops the shackle and fills the body in; unlocking lifts the shackle and leaves the body hollow, so the two states look different without relying on colour. It can also stay visible over the lock screen (optional).

### Battery and charging
The closed notch shows a short popup when your power state changes, with a drawn battery whose fill sweeps up to the real level:
- **Charging**, **Not charging**, **Plugged in**, **On battery**, **Fully charged**
- **Low battery**, at 20% and again at 10%
- **Low Power Mode on or off**

The open notch can also show the battery percentage. Colour is never the only signal: states also use a mark (bolt, plug, check, warning) and a label.

### Everywhere else
- Works on notched MacBooks and on other displays, on one display or all of them.
- Hides itself over fullscreen video.
- Menu bar icon (a cratered moon), launch at login, optional haptics.
- Respects macOS **Reduce Motion**: movement is replaced with simple fades.
- Animations are driven by the system where possible, so the notch uses almost no CPU while idle.

### What it deliberately does not do
No volume or brightness HUD, no file shelf, no clipboard manager, no calendar, no weather, and no support for music apps other than Apple Music. Fewer things, done carefully, is the whole idea.

## Requirements
- macOS 14 (Sonoma) or later
- Apple Music (the Music app)

## Install
Download the latest `.dmg` from the [Releases](https://github.com/khushalv21/Moonpool/releases) page, open it and drag the app to **Applications**.

The first time you play music, macOS asks whether Moonpool may control **Music**. Allow it: that is how the app reads the current song and sends play, pause and skip. You can change this later in **System Settings → Privacy & Security → Automation**.

## Build from source
You need Xcode and, for a signed build, an Apple Developer certificate.

```bash
git clone https://github.com/khushalv21/Moonpool.git
cd Moonpool
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch \
  -destination "generic/platform=macOS" build CODE_SIGNING_ALLOWED=NO
```

Or open `boringNotch.xcodeproj` in Xcode, choose your signing team, and run. (The Xcode project and source folder keep their original names for now.)

## Settings
Open **Settings** from the menu bar icon or by right-clicking the notch.

| Tab | What you can change |
|---|---|
| General | Menu bar icon, launch at login, which display to use, follow the active display |
| Notch | Haptics, lock animation, show on the lock screen, hide from screen recording, notch height |
| Music | Tint text with the album colour, colour the visualizer, glow behind the artwork, progress bar colour |
| Battery | Show the battery and percentage in the open notch, show power-change popups |

## Keyboard shortcuts
| Shortcut | Action |
|---|---|
| ⌘⇧I | Open or close the notch |
| ⌘⇧H | Preview the track-change popup |

## Privacy
Moonpool has **no network access** (the app sandbox is on and no network permission is requested) and collects no data. It reads your Music app's current track and controls playback through macOS Apple Events, and it reads battery and power state from the system. Nothing leaves your Mac.

## Credits and licensing

**This project is a fork. I did not write it from scratch, and I am not claiming otherwise.**

Moonpool is built on **[Boring Notch](https://github.com/TheBoredTeam/boring.notch)**, created by the **Boring Team ([TheBoredTeam](https://github.com/TheBoredTeam))** and its contributors. The window handling around the notch, the lock-screen overlay, the Apple Music plumbing and much of the project structure come from their work. My changes are a redesign on top of it: a stripped-down feature set, a new expanded player, the track-change, swipe, pause/resume, lock and battery interactions described above, and the rebrand. Huge thanks to the Boring Team for making the original and giving it away.

### License
Boring Notch is licensed under the **GNU General Public License v3.0**, and so is this project. That means:

- You may use, study, change and share this code, including commercially, under the terms of the GPL-3.0.
- If you distribute the app or a modified version, you must make the corresponding source code available under the same license.
- The original copyright notices stay in the source files, and the full license text is in [`LICENSE`](LICENSE). I have not removed them and I will not.
- There is **no warranty**.

I have renamed and redrawn the product, so the Boring Notch name and logo are not used here, and this project is **not affiliated with or endorsed by** the Boring Team. Boring Notch and its authors keep their own copyrights; my modifications are released under the same GPL-3.0.

### Third-party software
This app uses open-source libraries, each under its own license:
[Defaults](https://github.com/sindresorhus/Defaults), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) and [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) by Sindre Sorhus, [SkyLightWindow](https://github.com/Lakr233/SkyLightWindow) by Lakr233, and [MacroVisionKit](https://github.com/TheBoredTeam/MacroVisionKit) by theboringhumane. Their license notices are in [`THIRD_PARTY_LICENSES`](THIRD_PARTY_LICENSES).

### Copyright
Moonpool is a modified version of Boring Notch.

- Original Boring Notch code: © [TheBoredTeam](https://github.com/TheBoredTeam) and its contributors. The copyright notices in each source file are unchanged.
- Third-party libraries: © their respective authors, see [`THIRD_PARTY_LICENSES`](THIRD_PARTY_LICENSES) and the project links above.
- Moonpool's own changes are released under the same GPL-3.0 license.
