# ⏱ FocusTimer

**A beautiful, minimal Pomodoro timer that lives in your macOS menu bar.**

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?logo=apple)](https://github.com/lumenworksco/FocusTimer/releases)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Release](https://img.shields.io/github/v/release/lumenworksco/FocusTimer?color=red)](https://github.com/lumenworksco/FocusTimer/releases/latest)

---

## Download

<div align="center">

<a href="https://github.com/lumenworksco/FocusTimer/releases/latest">
  <img src="https://img.shields.io/badge/Download_for_macOS-%23000000?style=for-the-badge&logo=apple&logoColor=white" alt="Download for macOS" height="48"/>
</a>

<br/>
<sub>macOS 13.0 Ventura or later &nbsp;·&nbsp; Apple Silicon &amp; Intel &nbsp;·&nbsp; Free &amp; open source</sub>

</div>

<br/>

1. Download **FocusTimer.dmg** from the [latest release](https://github.com/lumenworksco/FocusTimer/releases/latest)
2. Open the DMG and drag `FocusTimer.app` to **Applications**
3. Launch it — the `⏱` icon appears in your menu bar

> **First launch:** macOS may show a security prompt. Go to **System Settings → Privacy & Security** and click **Open Anyway**.

---

## Features

### Timer
- **Menu bar native** — one click away, never clutters the Dock
- **Animated progress ring** — smooth arc with a pulsing glow while your session runs
- **Session types** — Work, Short Break, and Long Break with distinct colors
- **Pomodoro dots** — track completed sessions in the current cycle at a glance
- **Auto-advance** — transitions automatically work → break → work
- **Idle detection** — auto-pauses when you step away, auto-resumes when you return

### Task management
- **Task label** — name what you're working on; shows next to the timer in the menu bar
- **Task autocomplete** — recent labels appear as suggestions when you click the field
- **Session log** — every session recorded with task label, time, and duration

### Stats & insights
- **Activity heatmap** — 16-week GitHub-style day grid showing your focus history
- **Daily bar chart** — sessions or focus time over 1, 2, or 4 weeks
- **Time-of-day patterns** — hourly distribution chart revealing your peak focus hours
- **Streak tracking** — current focus streak shown in the main window and Stats
- **Daily goal** — set a session target; a progress bar tracks you toward it

### Notifications
- **Session alerts** — notification with optional sound when each session completes
- **Weekly digest** — Sunday evening summary of sessions, focus time, and streak
- **Milestone celebrations** — one-time notifications at 10, 50, 100, 500, and 1,000 sessions

### Comfort
- **Break prompts** — a rotating micro-action suggestion on every break (stand up, breathe, etc.)
- **Global hotkeys** — customizable keyboard shortcuts to start/pause and skip from anywhere
- **Launch at login** — start automatically with macOS
- **Auto-update** — checks for new releases and updates in-app with a single click

---

## Usage

| Action | How |
|--------|-----|
| Open timer | Click the `⏱` icon in the menu bar |
| Start / Pause | Click **Start** or press the global hotkey (default `⌃⌥Space`) |
| Skip session | Click **Skip** or press `⌃⌥S` |
| Reset session | Click **Reset** |
| Open full window | Click the app icon in the Dock |
| View stats | Click the chart icon `⊞` in the popover header |
| Settings | Click the gear icon `⚙` or right-click the menu bar icon |

The classic Pomodoro cycle:  
`Work → Short Break → Work → Short Break → Work → Short Break → Work → Long Break → repeat`

---

## Settings

| Setting | Default |
|---------|---------|
| Work session | 25 min |
| Short break | 5 min |
| Long break | 15 min |
| Sessions before long break | 4 |
| Daily goal | 8 sessions |
| Auto-advance | On |
| Show task label in menu bar | Off |
| Pause when idle | On (5 min threshold) |
| Global hotkeys | On |
| Notifications | On |
| Weekly digest | On |
| Launch at login | Off |

---

## Building from Source

**Requirements:** Xcode 15+, macOS 13.0+

```bash
git clone https://github.com/lumenworksco/FocusTimer.git
cd FocusTimer

xcodebuild -scheme FocusTimer -configuration Release \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

Or open `FocusTimer.xcodeproj` in Xcode and press **⌘R**.

---

## Contributing

Pull requests are welcome. For significant changes please open an issue first to discuss the approach.

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes
4. Push and open a Pull Request

---

## License

[MIT](LICENSE) © 2026 lumenworksco
