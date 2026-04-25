# Development Guide

This is for working *on* open-wispr. For installing it as a user, see [install-guide.md](install-guide.md).

## Quick start

```bash
git clone git@github.com:1shanpanta/open-wispr.git
cd open-wispr
brew install whisper-cpp
macship   # see "Build pipeline" below
```

## Build pipeline

The repo uses [macship](https://github.com/1shanpanta/macship) (private) as its single-command build/sign/install tool. Configuration lives in `.macship` at the repo root.

```bash
macship
```

What that does, in order:

1. Reads `.macship` (a sourced shell file: `NAME`, `BUNDLE_ID`, `BUILD_CMD`, `BINARY`, plus optional `ICON`, `LS_UI_ELEMENT`, `MIC_USAGE`, etc.)
2. Runs `swift build -c release`
3. Signs `.build/release/open-wispr` with the Apple Developer cert in `MACSHIP_CERT` (defaults to "Apple Development: Ishan Panta (M8456FDZST)")
4. Stages a fresh `.app` bundle in `/tmp` (Info.plist, icon, executable)
5. Re-signs the bundle with the same dev cert (ad-hoc signing would invalidate TCC grants on install)
6. Stops any running daemon (`pkill -f open-wispr`)
7. `rsync -a --delete` the staged bundle into `~/Applications/OpenWispr.app`
8. Refreshes Launch Services + Spotlight (`lsregister -f`, `mdimport`)
9. Relaunches via `open`

Why this matters: the bundle ID + signing identity stay constant across rebuilds, so macOS TCC keeps Accessibility, Input Monitoring, and Microphone grants permanently. Without stable signing, you re-grant in System Settings every build.

The legacy `scripts/dev-rebuild.sh` does the same thing as a fallback if `macship` isn't installed.

## Bundle identity

| Key                   | Value                                                  |
|-----------------------|--------------------------------------------------------|
| Bundle ID             | `com.ishan.open-wispr`                                 |
| Display name          | `OpenWispr`                                            |
| Installed at          | `~/Applications/OpenWispr.app`                         |
| Code-signing identity | Apple Development: Ishan Panta (M8456FDZST)            |
| Team ID               | F8X5B9PV88                                             |
| Default hotkey        | Shift+Space, toggle mode                               |

Changing the bundle ID resets all TCC grants once (re-grant Accessibility + Input Monitoring + Microphone in System Settings → Privacy & Security). After that they persist.

## Source layout

```
Sources/
├── OpenWispr/
│   └── main.swift                Entry point, CLI command dispatch (start, status, set-hotkey, stats, ...)
└── OpenWisprLib/
    ├── AppDelegate.swift         App lifecycle, hotkey wiring, recording → transcription → insert pipeline
    ├── Recorder.swift            AVAudioEngine capture
    ├── Transcriber.swift         whisper-cpp wrapper
    ├── TextInserter.swift        Pasteboard save → set → simulate ⌘V → restore (with race-safe delay)
    ├── StatusBarController.swift Menu bar UI, state machine (idle/recording/transcribing/error/etc)
    ├── FloatingIndicator.swift   Optional draggable indicator window
    ├── Permissions.swift         AX, Input Monitoring, Microphone TCC checks + prompts
    ├── KeyCodes.swift            Carbon keycode <-> human-readable name lookup
    ├── HotkeyMonitor.swift       CGEventTap-based global hotkey listener
    └── Config.swift              ~/.config/open-wispr/config.json read/write
```

## Persistence

```
~/.config/open-wispr/
├── config.json     # hotkey, model, language, audio device id
├── stats.json      # daily word counts, total
├── .last-version   # used to detect upgrades
├── models/         # whisper-cpp .bin files
└── recordings/     # raw audio (typically empty; pruned by maxRecordings)
```

## Permission model

OpenWispr needs three TCC grants:

| Permission         | Why                                                                   | Where granted in System Settings              |
|--------------------|-----------------------------------------------------------------------|-----------------------------------------------|
| Microphone         | Capture speech via AVAudioEngine                                      | Privacy & Security → Microphone               |
| Accessibility      | Post synthetic ⌘V keystrokes to paste transcribed text                | Privacy & Security → Accessibility            |
| Input Monitoring   | CGEventTap listening for the global hotkey                            | Privacy & Security → Input Monitoring         |

These are checked at startup in `AppDelegate.applicationDidFinishLaunching`. If any are missing, the menu bar shows a "Waiting for X permission" state and surfaces a deep link to the right Settings pane.

Input Monitoring requires a process restart after granting (CGPreflightListenEventAccess only re-evaluates on relaunch). The menu hint says so.

## Recent fixes (2026-04)

Two bugs that bit during development:

### Paste race (`Sources/OpenWisprLib/TextInserter.swift`)

`insert(text:)` puts the transcription on the pasteboard, posts a synthetic ⌘V, then restores the previous pasteboard contents on a delayed dispatch. The original delay was 100ms — too short. The synthetic ⌘V is just *posted* to the system event tap; the focused app reads `NSPasteboard.general` whenever it processes the event. Slow apps (loading, animating, throttled) lose the race, and the app reads the *restored* clipboard, pasting old content (or nothing).

Fix: bumped the restore delay to 500ms. Robust alternative if 500ms is still tight in practice: poll `pasteboard.changeCount` and only restore once it's incremented.

### Default to daemon when launched as `.app` (`Sources/OpenWispr/main.swift`)

The binary doubles as a CLI (`open-wispr status`, `open-wispr stats`, etc.) and a daemon (`open-wispr start`). When macOS or Raycast or Finder launches the `.app`, no args are passed. The original behavior was to print usage and exit, so the daemon never started.

Fix: `case nil: cmdStart()` so a bare `open-wispr` (or a click on the bundle) starts the daemon. `--help` / `-h` / `help` still print usage.

## Common dev tasks

```bash
# Rebuild + reinstall
macship

# Quick CLI checks
open-wispr status         # config + permission state
open-wispr stats          # daily/weekly/all-time word counts
open-wispr get-hotkey

# Change runtime config (writes ~/.config/open-wispr/config.json)
open-wispr set-hotkey shift+space
open-wispr set-model small.en
open-wispr set-language en

# Reinstall a Whisper model
open-wispr download-model small.en
```

## Testing changes

There's no unit-test scaffolding for the daemon path because it depends on AppKit + audio + TCC. The realistic test loop:

1. Edit code
2. `macship`
3. Open TextEdit, click into a doc
4. Shift+Space, speak clearly (avoid noisy environments — Whisper falls back to "you" on near-silence)
5. Shift+Space, expect text to appear

Verbose logs go to stderr. Run the binary directly to see them: `~/Applications/OpenWispr.app/Contents/MacOS/open-wispr start`.
