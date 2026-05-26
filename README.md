# ⏱ FocusTimer

**A beautiful, minimal Pomodoro timer that lives in your macOS menu bar.**

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?logo=apple)](https://github.com/lumenworksco/FocusTimer/releases)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Release](https://img.shields.io/github/v/release/lumenworksco/FocusTimer?color=red)](https://github.com/lumenworksco/FocusTimer/releases/latest)

---

## Features

- **Menu bar native** — always one click away, never clutters your dock
- **Animated progress ring** — smooth arc with a pulsing glow while your session runs
- **Auto-advance** — transitions automatically from work → break → work
- **Pomodoro dots** — track completed sessions in the current cycle
- **Fully customizable** — adjust work, short break, and long break durations
- **macOS notifications** — get alerted when each session completes
- **Zero accounts, zero tracking** — everything stored locally

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
2. Open it and drag `FocusTimer.app` into the **Applications** folder
3. Launch it — the `⏱` icon appears in your menu bar

> **First launch:** macOS may show a security prompt. Go to **System Settings → Privacy & Security** and click **Open Anyway**.

### Build from Source

```bash
# Clone
git clone https://github.com/lumenworksco/FocusTimer.git
cd FocusTimer

# Build (requires Xcode 15+)
xcodebuild -scheme FocusTimer -configuration Release \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# The built app is at:
# ~/Library/Developer/Xcode/DerivedData/FocusTimer-.../Build/Products/Release/FocusTimer.app
```

Or open `FocusTimer.xcodeproj` in Xcode and press **⌘R**.

## Usage

| Action | How |
|--------|-----|
| Open timer | Click `⏱ 25:00` in the menu bar |
| Start / Pause | Click **Start** or **Pause** in the popup |
| Skip session | Click **Skip** |
| Reset session | Click **Reset** |
| Change durations | Click the ⚙️ gear icon |

Sessions follow the classic Pomodoro cycle:
`Work → Short Break → Work → Short Break → Work → Short Break → Work → Long Break → repeat`

## Customization

Click the **⚙️ gear icon** to open Settings:

| Setting | Default | Range |
|---------|---------|-------|
| Work session | 25 min | 1–90 min |
| Short break | 5 min | 1–30 min |
| Long break | 15 min | 5–60 min |
| Sessions before long break | 4 | 2–8 |
| Notifications | On | — |

## Contributing

Pull requests are welcome! For major changes, please open an issue first.

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

## License

[MIT](LICENSE) © 2026 lumenworksco
