# Architecture

High-level map of how open-wispr works, intended for an LLM (or human) picking up the codebase cold.

## What it is

A local macOS menu-bar daemon that turns speech into pasted text. Press a global hotkey, speak, press the hotkey again, the transcript pastes into whatever has focus. All processing is on-device via [whisper-cpp](https://github.com/ggerganov/whisper.cpp); nothing hits the network.

## Runtime data flow

```
┌──────────────┐  Carbon HIToolbox event tap  ┌───────────────┐
│ Global hotkey│ ───────────────────────────▶ │ HotkeyMonitor │
│ (Shift+Space)│                              └──────┬────────┘
└──────────────┘                                     │ toggle
                                                     ▼
                              ┌────────────────────────────────┐
                              │ AppDelegate (state machine)    │
                              ├────────────────────────────────┤
                              │ idle ─▶ recording ─▶ transcribing ─▶ idle │
                              └─┬────────────┬────────────┬────┘
                                │            │            │
                ┌───────────────┘            │            └──────────────┐
                ▼                            ▼                           ▼
        ┌─────────────┐             ┌──────────────┐           ┌─────────────────┐
        │ Recorder    │  audio.wav  │ Transcriber  │  text     │ TextInserter    │
        │ (AVAudio    │ ──────────▶ │ (whisper-cpp │ ────────▶ │ pasteboard +    │
        │  Engine)    │             │  via FFI)    │           │ synthetic ⌘V    │
        └─────────────┘             └──────────────┘           └────────┬────────┘
                                                                        │
                                                                        ▼
                                                           ┌─────────────────────┐
                                                           │ Focused app receives │
                                                           │ paste, transcript    │
                                                           │ appears in text area │
                                                           └─────────────────────┘
```

Side channels:

- `StatusBarController` shows the current state in the menu bar icon.
- `FloatingIndicator` (optional) is a draggable circle that mirrors state visually.
- `Stats` increments a daily word counter after every successful transcription.

## Modules at a glance

| Module                    | Responsibility                                                        |
|---------------------------|-----------------------------------------------------------------------|
| `OpenWispr/main.swift`    | CLI dispatch (`start`, `status`, `stats`, `set-hotkey`, ...)         |
| `AppDelegate`             | App lifecycle, state machine, glues hotkey → record → transcribe → insert |
| `HotkeyMonitor`           | CGEventTap listener for the global hotkey                             |
| `Recorder`                | AVAudioEngine audio capture, writes a temp WAV                        |
| `Transcriber`             | whisper-cpp wrapper, returns text from a WAV                          |
| `TextInserter`            | Save pasteboard → set transcription → post ⌘V → restore               |
| `StatusBarController`     | Menu bar icon + menu, animates per-state                              |
| `FloatingIndicator`       | NSWindow with custom drawing for visual feedback                      |
| `Permissions`             | TCC checks (AX, Input Monitoring, Microphone) and prompts             |
| `Config`                  | `~/.config/open-wispr/config.json` read/write with default fallback   |
| `Stats`                   | Daily / weekly / all-time word counters in `stats.json`               |
| `KeyCodes`                | Carbon virtual keycode ↔ human-readable name                          |
| `RecordingStore`          | Optional retention/pruning of `~/.config/open-wispr/recordings/`      |
| `TextPostProcessor`       | Spoken-punctuation pass ("comma" → ",")                               |

## Data on disk

```
~/.config/open-wispr/
├── config.json     hotkey, modelSize, language, audioInputDeviceID, toggleMode, spokenPunctuation
├── stats.json      totalWords + dailyHistory[]
├── .last-version   tag for upgrade detection
├── models/         whisper-cpp .bin model weights (downloaded lazily)
└── recordings/     raw WAV audio (typically empty after transcription)
```

## Bundle identity (matters for TCC)

| Field                 | Value                                                  |
|-----------------------|--------------------------------------------------------|
| Bundle ID             | `com.ishan.open-wispr`                                 |
| Code-signing identity | Apple Development: Ishan Panta (M8456FDZST)            |
| Team ID               | F8X5B9PV88                                             |
| Install path          | `~/Applications/OpenWispr.app`                         |
| `LSUIElement`         | `true` (menu-bar agent, no Dock icon)                  |
| Min macOS             | 13.0                                                   |

macOS TCC tracks signed apps by `bundle ID + team ID`. Keeping both stable across rebuilds (which `macship` enforces) is what lets Accessibility / Input Monitoring / Microphone grants persist. Path moves do not invalidate grants for signed apps; identity changes do.

## Key implementation choices

- **whisper-cpp via FFI, not Apple Speech**. Fully on-device, supports many languages, no quota or rate limit. The trade-off is a ~140MB model download (`base.en`) on first use.
- **Carbon HIToolbox for global hotkeys**. CGEventTap also works but Carbon is simpler for one hotkey and battle-tested. The build links Carbon explicitly.
- **Pasteboard + synthetic ⌘V for text insertion**, rather than AXUIElement direct insertion. The pasteboard path works in every text field across every app; AX direct insertion is fragile and app-specific. The trade-off is a clipboard-restore race window (mitigated by a 500ms restore delay; see `TextInserter.swift`).
- **AppKit, not SwiftUI**. AppKit is more straightforward for menu-bar apps that don't need a real window, and removes the SwiftUI runtime dependency for a tool that targets older macOS versions.
- **Toggle mode by default** (press to start, press to stop), not push-to-talk. Hands-free of the keyboard while speaking.
- **No telemetry, no network**. Everything except the initial whisper model download runs offline.

## Build & install

See [development.md](development.md). Single command: `macship` from the repo root. Pipeline summarized: build with Swift PM → sign with Apple Dev cert → assemble bundle → re-sign bundle → rsync to `~/Applications/OpenWispr.app` → relaunch.

## What's NOT here

- No GUI for configuration. All settings live in `config.json` and are changed via the CLI (`open-wispr set-hotkey`, etc.) or by editing the JSON directly.
- No iCloud sync. Stats and config stay local.
- No streaming transcription. Whisper-cpp processes the full recording after stop, not while recording.
- No automatic launch at login. The user starts the daemon manually via `open ~/Applications/OpenWispr.app` or by re-running `macship`. (Adding LaunchAgent setup is a candidate enhancement.)
