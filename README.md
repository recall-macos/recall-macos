# Recall

**Native macOS clipboard manager. Press a shortcut, search your history, paste — and it's gone.**

[![Download](https://img.shields.io/badge/Download-v1.0-black?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/recall-macos/recall-macos/releases/latest/download/Recall.dmg)

[![macOS](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square)](LICENSE)
[![Stars](https://img.shields.io/github/stars/recall-macos/recall-macos?style=flat-square&color=yellow)](https://github.com/recall-macos/recall-macos/stargazers)

---

## Install

> [!WARNING]
> **First launch:** macOS may block Recall with "Apple could not verify…". Click Done, then go to **Applications → right-click Recall → Open → Open**. One-time only.

1. Click **Download** above to get `Recall.dmg`
2. Open the DMG and drag `Recall` into your **Applications** folder
3. Open **Applications**, find Recall, and **right-click → Open**
4. Click **Open** on the "Apple could not verify" prompt — this is a one-time step for apps outside the App Store
5. Press **⌘⇧V** from any app

> Recall is not notarized. After the right-click Open step, it launches normally forever.

---

## What it does

Recall runs silently in your menu bar and captures everything you copy. Hit the global shortcut from anywhere — a panel appears over whatever you're doing, your full history already loaded.

Type to search. Arrow keys to navigate. **↵** to paste back into whatever you were doing. **⎋** to dismiss without touching your clipboard. That's it.

---

## Features

| | |
|---|---|
| **Clipboard history** | Text, URLs, images, files, rich text. Up to 1000 items, auto-deduplicated. |
| **Smart content detection** | Automatically tags URLs, emails, phone numbers, code, images, and files. |
| **Instant search** | Fuzzy, case-insensitive, searches content and filenames as you type. |
| **Filter tabs** | All · Text · Links · Images · Files · Code · Email · Pinned |
| **Smart paste** | ↵ copies and immediately pastes into the previous app — no manual ⌘V. |
| **Pinning** | Pin items to keep them through pruning and at the top of search. |
| **Privacy controls** | OTP codes, credit cards, and password manager output are skipped automatically. |
| **App exclusions** | Block any installed app from being monitored — 1Password, Bitwarden, etc. |
| **Auto-expire** | Clear history after 1 hour, 1 day, 7 days, 30 days, or never. |
| **Adaptive icon** | Light, Dark, and Tinted variants — switches with your system appearance. |

---

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| ⌘⇧V | Open Recall (configurable) |
| ↑ / ↓ | Navigate history |
| ↵ | Copy + paste into previous app |
| ⌘P | Pin / unpin selected item |
| ⌘⌫ | Delete selected item |
| ⌘F | Focus search |
| ⌘← / ⌘→ | Switch filter tab |
| ⌘1–6 | Jump to filter tab |
| 1–9 | Quick-select by position |
| ⎋ | Close without pasting |

---

## Settings

- Launch at login
- History limit: 50 / 100 / 250 / 500 / 1000 / Unlimited
- Auto-expire: 1 hour / 1 day / 7 days / 30 days / Never
- Customizable global shortcut
- App exclusions
- Screenshot capture toggle
- Color scheme: System / Light / Dark

---

## Privacy

Everything is stored locally in `~/Library/Application Support/Recall/`. Nothing is ever uploaded, synced, or logged remotely. The sensitive content filter runs on-device and blocks:

- One-time passwords (6–8 digit codes)
- Credit card numbers
- Strings copied from 1Password, Bitwarden, and similar password managers (via app exclusions)

---

## Architecture

```
Recall/
├── AppDelegate.swift               # Lifecycle, menu bar, hotkey registration, panel
├── Core/
│   ├── ClipboardMonitor.swift      # NSPasteboard polling every 0.5s
│   ├── ClipboardStore.swift        # History, pinning, deduplication, pruning
│   ├── HotkeyManager.swift         # Carbon RegisterEventHotKey wrapper
│   ├── PanelController.swift       # Keyboard cursor + selection state
│   ├── PasteEngine.swift           # Smart paste via CGEvent
│   └── SearchEngine.swift          # Fuzzy search + category filter
├── Models/
│   ├── ClipboardItem.swift         # Core data model
│   └── AppSettings.swift           # @AppStorage-backed settings
├── Extensions/
│   ├── String+ContentType.swift    # Content type detection heuristics
│   ├── NSImage+Thumbnail.swift     # Downscaling for display
│   └── Notifications.swift         # Notification names + key event constants
├── Persistence/
│   └── ClipboardStorage.swift      # JSON encode/decode to ~/Library
└── UI/
    ├── ClipboardPanel/             # Main floating panel (NSPanel + SwiftUI)
    ├── Settings/                   # Settings window
    ├── Onboarding/                 # First-launch walkthrough
    └── Components/                 # Shared UI components
```

**Key technical decisions**

**`.nonactivatingPanel`** — The panel becomes key window (receives keyboard events) without making Recall the frontmost app. This keeps the previous app active so smart paste can immediately fire ⌘V into it.

**`RegisterEventHotKey`** — Carbon API instead of `NSEvent.addGlobalMonitorForEvents`. Carbon fires synchronously inside the key-press event context, which is required for `NSApp.activate()` to work reliably on macOS 14+.

**NSPasteboard polling** — Polls every 0.5s on a background `DispatchSourceTimer`. `NSPasteboard` change notifications are unreliable; polling is the standard approach used by every clipboard manager.

**Gated rich text** — `NSAttributedString.readObjects(forClasses:)` silently synthesizes attributed strings from plain text, which would misclassify everything as rich text. Recall gates this path on an explicit RTF/RTFD type check on `pasteboard.types` first.

---

## Build from source

**Requirements:** macOS 14+, Xcode 16+, Swift 5.9+. No external dependencies.

```bash
git clone https://github.com/recall-macos/recall-macos.git
cd recall-macos
open Recall.xcodeproj
```

Press **⌘R**. Grant Accessibility permission when prompted — required for smart paste.

---

## License

MIT — see [LICENSE](LICENSE) for details.

Built by [Neel Verma](https://github.com/Neel2code)
