<p align="center">
  <img src="logo.svg" width="80" alt="open-wispr logo">
</p>

<h1 align="center">open-wispr</h1>

<p align="center">
  Local, private voice dictation for macOS. Press a key, speak, press again -- your words appear at the cursor.<br>
  Everything runs on-device. No audio or text ever leaves your machine.
</p>

<p align="center">Powered by <a href="https://github.com/ggml-org/whisper.cpp">whisper.cpp</a> with Metal acceleration on Apple Silicon.</p>

<p align="center"><em>Fork of <a href="https://github.com/human37/open-wispr">human37/open-wispr</a> with additional features.</em></p>

## What's new in this fork

- **Floating indicator** -- draggable on-screen circle that shows recording/transcribing state. Tap to stop recording. Remembers position across restarts.
- **Word tracking stats** -- tracks words dictated today, this week, and all time. Visible in the menu bar dropdown and via CLI.
- **Hotkey fix** -- ignores key repeats and enforces exact modifier matching to prevent accidental triggers.

## Install

```bash
git clone https://github.com/1shanpanta/open-wispr.git
cd open-wispr
brew install whisper-cpp
swift build -c release
.build/release/open-wispr start
```

A waveform icon appears in your menu bar when it's running. A floating indicator also appears on screen (drag it anywhere).

The default hotkey is **Shift+Space** in toggle mode (press to start, press again to stop).

## Configuration

Edit `~/.config/open-wispr/config.json`:

```json
{
  "hotkey": { "keyCode": 49, "modifiers": ["shift"] },
  "modelSize": "base.en",
  "language": "en",
  "spokenPunctuation": false,
  "maxRecordings": 0,
  "toggleMode": true
}
```

Then restart: `pkill -f "open-wispr start" && open "/Applications/Open Wispr.app"`

| Option | Default | Values |
|---|---|---|
| **hotkey** | `49` | Space (`49`), Globe (`63`), Right Option (`61`), F5 (`96`), or any key code |
| **modifiers** | `["shift"]` | `"cmd"`, `"ctrl"`, `"shift"`, `"opt"` -- combine for chords |
| **modelSize** | `"base.en"` | `tiny.en`, `base.en`, `small.en`, `medium.en`, `large-v3-turbo`, `large` |
| **language** | `"en"` | `"auto"` for auto-detect, or any ISO 639-1 code |
| **toggleMode** | `true` | Press once to start, again to stop. Set `false` for hold-to-talk. |

## Word tracking

```bash
open-wispr stats
```

```
Today:     1,247 words
This week: 4,832 words
All time:  34,521 words
```

Stats persist to `~/.config/open-wispr/stats.json` and are also visible in the menu bar dropdown.

## Floating indicator

Draggable on-screen circle. Drag it anywhere -- position saved across restarts. Click while recording to stop.

<p align="center">
  <img src="docs/floating-idle.png" width="80" alt="Idle">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/floating-recording.png" width="80" alt="Recording">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/floating-transcribing.png" width="80" alt="Transcribing">
</p>
<p align="center"><sub>Idle &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Recording &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Transcribing</sub></p>

## LLM setup instructions

Want an AI assistant to set this up as a native macOS app (launchable from Raycast/Spotlight)? Copy the contents of **[llms.txt](llms.txt)** into Claude, ChatGPT, or any LLM.

## Credits

Originally created by [human37](https://github.com/human37/open-wispr). This fork adds the floating indicator, word tracking, and hotkey improvements.

## License

MIT
