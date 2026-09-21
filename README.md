# Recall

**A beautiful, native macOS clipboard manager.**

Press a global shortcut from anywhere and your entire clipboard history appears instantly. Search it, navigate with the keyboard, and paste in one keystroke — then it's gone. Recall lives quietly in the menu bar and never gets in your way.

[![Download](https://img.shields.io/badge/Download-Recall_1.0-blue?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/recall-macos/recall-macos/releases/latest/download/Recall.zip)

[![macOS](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square)](LICENSE)

---

## Install

1. Click **Download** above
2. Unzip `Recall.zip`
3. Drag `Recall.app` to your Applications folder
4. Open it — press **Allow** if macOS asks about security
5. Press **⌘⇧V** from any app to open your clipboard history

> **macOS security note:** Recall is not yet notarized. If you see "unidentified developer", right-click the app → Open → Open to bypass it once.

---

## What it does

Recall sits in your menu bar and silently captures everything you copy. The moment you press the global shortcut, a panel appears over whatever you're doing:

- Type to search — results filter instantly
- Arrow keys navigate, Enter pastes into the previous app
- Right-click any item for quick actions (copy, pin, delete)
- Escape closes it without pasting anything

That's the whole interaction. No setup, no configuration required to start.

---

## Features

**Clipboard history**
Captures text, URLs, rich text, images, and files. Newest items first. Deduplicates automatically. Stores up to 1000 items (configurable).

**Smart content detection**
Automatically classifies what you copied:

| Type | Detection |
|------|-----------|
| URL | `http://`, `https://`, `ftp://` |
| Email | Standard address format |
| Phone | Common number formats |
| Code | Language-aware heuristics |
| Image | PNG, TIFF, JPEG, screenshots |
| File | Finder copies and drag-and-drop |

**Search**
Fuzzy, case-insensitive, instant. Searches text content, filenames, and URLs.

**Filter tabs**
All — Text — Links — Images — Files — Code — Email — Pinned

**Pinning**
Pin important items. Pinned items survive automatic history pruning and filtering.

**Smart paste**
Pressing Enter copies the item and immediately pastes it into whatever app you were in before opening Recall. No manual ⌘V required.

**Privacy**
- Everything stored locally — nothing uploaded, ever
- Sensitive content filter skips OTPs, credit card numbers, and password-manager output automatically
- Exclude any app from monitoring (e.g. 1Password, Bitwarden) in Settings
- Auto-delete history after 1 hour, 1 day, 7 days, or 30 days

---

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| ⌘⇧V | Open Recall (configurable) |
| ↑ / ↓ | Move selection |
| ↵ | Copy and paste into previous app |
| ⌘P | Pin / unpin |
| ⌘⌫ | Delete item |
| ⌘F | Focus search |
| ⌘← / ⌘→ | Switch filter tab |
| ⌘1–6 | Jump to filter tab |
| 1–9 | Quick-select item by position |
| ⎋ | Dismiss |

---

## Settings

- Launch at login
- History limit: 50 / 100 / 250 / 500 / 1000 / Unlimited
- Auto-expire: 1 hour / 1 day / 7 days / 30 days / Never
- Customizable global shortcut
- App exclusions (any installed app)
- Screenshot capture redirect
- Color scheme: System / Light / Dark
- Show / hide menu bar icon

---

## Architecture

```
Recall/
├── AppDelegate.swift               # Lifecycle, menu bar, hotkey, panel
├── Core/
│   ├── ClipboardMonitor.swift      # NSPasteboard polling + extraction
│   ├── ClipboardStore.swift        # History, pinning, persistence
│   ├── HotkeyManager.swift         # Carbon RegisterEventHotKey wrapper
│   ├── PanelController.swift       # Keyboard cursor state
│   ├── PasteEngine.swift           # Smart paste via CGEvent
│   └── SearchEngine.swift          # Fuzzy search + category filter
├── Models/
│   ├── ClipboardItem.swift         # Data model
│   └── AppSettings.swift           # @AppStorage settings
├── Extensions/
│   ├── String+ContentType.swift    # Content type detection
│   ├── NSImage+Thumbnail.swift     # Image downscaling
│   └── Notifications.swift         # Notification names + key events
├── Persistence/
│   └── ClipboardStorage.swift      # JSON encode/decode to ~/Library
└── UI/
    ├── ClipboardPanel/             # Main floating panel
    ├── Settings/                   # Settings window (4 panes)
    ├── Onboarding/                 # First-launch screen
    └── Components/                 # Shared UI components
```

**Key technical decisions**

`.nonactivatingPanel` — The panel becomes the key window (receives keyboard events) without making Recall the frontmost app. This is what makes smart paste work: the previous app stays active so Enter can trigger ⌘V into it immediately.

`RegisterEventHotKey` — Uses the Carbon API instead of `NSEvent.addGlobalMonitorForEvents`. Carbon fires synchronously inside the key-press event context, which is required for `NSApp.activate()` to work reliably on macOS 14+.

NSPasteboard polling — Polls every 0.5s on a background `DispatchQueue` using `DispatchSourceTimer`. `NSPasteboard` does not post reliable change notifications.

Gated rich text — `NSAttributedString.readObjects(forClasses:)` silently synthesizes attributed strings from plain text, causing everything to be misclassified as rich text. Recall gates this path on checking `pasteboard.types` for actual RTF declarations first.

---

## Build from source

**Requirements:** macOS 14+, Xcode 16+, Swift 5.9+

```bash
git clone https://github.com/recall-macos/recall-macos.git
cd recall-macos
open Recall.xcodeproj
```

Press **⌘R** in Xcode. No external dependencies.

**Permissions required at runtime**
- Accessibility — for smart paste
- Screen Recording — optional, for screenshot capture redirect

---

## License

MIT — see [LICENSE](LICENSE) for details.

Built by [Neel Verma](https://github.com/Neel2code)
