# Recall

**Your clipboard, always within reach.**

Recall is a beautiful, native macOS clipboard manager. Press a global shortcut from anywhere and your clipboard history appears instantly — search it, navigate with the keyboard, paste with one keystroke, and dismiss. It lives quietly in the menu bar and never gets in your way.

---

## Features

### Core
- **Instant access** — global ⌘⇧V shortcut (fully customizable) opens the panel from any app
- **Full history** — captures text, URLs, rich text, images, and files automatically
- **Smart paste** — presses ⌘V into the previously active app so you never break your flow
- **Keyboard-first** — arrow keys navigate, Enter pastes, Escape dismisses; no mouse needed
- **Fuzzy search** — results filter as you type, case-insensitively
- **Filter tabs** — view All, Text, Links, Images, Files, Code, Email, or Pinned at a glance
- **Pin items** — pinned items survive automatic history pruning and are always findable
- **Quick Actions** — right-click any item to copy, paste, pin, or delete without leaving the panel

### Smart Content Recognition
Recall automatically classifies clipboard content:

| Icon | Type | Detection |
|------|------|-----------|
| 🔗 | URL | `http://`, `https://`, `ftp://` |
| ✉️ | Email | RFC 5322 pattern |
| 📞 | Phone | Standard number formats |
| `<>` | Code | Language-aware heuristics |
| 🖼 | Image | PNG, TIFF, JPEG, screenshots |
| 📄 | File | Finder file/folder copies |

### Privacy
- All data is stored **locally on your Mac** — nothing is ever uploaded
- **Sensitive content filter** automatically skips OTPs, credit card numbers, and password-manager output
- **App exclusions** — exclude any installed app (e.g. 1Password, Bitwarden) so its clipboard is never captured
- **Auto-expiration** — automatically delete items older than 1 hour, 1 day, 7 days, or 30 days
- No analytics, no telemetry, no internet connection required

### Settings
- History limit: 50 / 100 / 250 / 500 / 1000 / Unlimited
- Color scheme: System / Light / Dark
- Customizable global shortcut
- Launch at login
- Show/hide menu bar icon
- Screenshot redirection (captures ⌘⇧3/⌘⇧4 directly to history)

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘⇧V | Open Recall (configurable) |
| ↑ / ↓ | Move selection |
| ↖ / ↘ | Jump to first / last item |
| ↵ | Copy & paste selected item |
| ⌘P | Pin / unpin selected item |
| ⌘⌫ | Delete selected item |
| ⌘F | Focus search field |
| ⌘← / ⌘→ | Switch filter tab |
| ⌘1–6 | Jump directly to filter tab |
| 1–9 | Quick-select item by position |
| ⎋ | Dismiss |

---

## Architecture

Recall is structured as a clean, modular Swift/SwiftUI/AppKit project. Each concern lives in its own layer:

```
Recall/
├── AppDelegate.swift          # App lifecycle, menu bar, hotkey, panel orchestration
├── RecallApp.swift            # SwiftUI App entry point (minimal — delegates to AppDelegate)
│
├── Core/
│   ├── ClipboardMonitor.swift # NSPasteboard polling, content extraction, sensitive-data filter
│   ├── ClipboardStore.swift   # In-memory history, pinning, search indexing, persistence
│   ├── HotkeyManager.swift    # Carbon RegisterEventHotKey wrapper for global shortcuts
│   ├── PanelController.swift  # Keyboard cursor state (selected index, navigation)
│   ├── PasteEngine.swift      # Restores items to NSPasteboard + triggers ⌘V smart paste
│   ├── SearchEngine.swift     # Fuzzy search and category filtering
│   └── AdManager.swift        # Remote sponsor ad fetching and rotation
│
├── Models/
│   ├── ClipboardItem.swift    # Value type: id, contentType, textContent, imageData, filePaths, timestamp, isPinned
│   └── AppSettings.swift      # @AppStorage-backed settings + HistoryLimit / HistoryExpiration enums
│
├── Extensions/
│   ├── String+ContentType.swift   # ContentTypeDetector — classifies text as url/email/code/etc.
│   ├── NSImage+Thumbnail.swift    # Downscale helper for large image captures
│   └── Notifications.swift        # Notification.Name constants + RecallKeyEvent enum
│
├── Persistence/
│   └── HistoryStore.swift         # JSON encode/decode to ~/Library/Application Support/Recall/
│
└── UI/
    ├── ClipboardPanel/
    │   ├── ClipboardPanelWindow.swift  # NSPanel (.nonactivatingPanel) — becomes key without activating app
    │   ├── ClipboardPanelView.swift    # Main panel SwiftUI view (search, filter, list, bottom bar)
    │   ├── ClipboardItemRow.swift      # Per-item row: icon, preview, timestamp, hover states
    │   ├── FilterTabsView.swift        # Animated filter tab strip
    │   └── QuickActionsOverlay.swift   # Right-click action menu overlay
    ├── Components/
    │   └── SponsorBanner.swift         # Non-intrusive sponsor ad banner (hidden when Pro)
    ├── Onboarding/
    │   └── OnboardingView.swift        # First-launch welcome + shortcut setup
    └── Settings/
        └── SettingsView.swift          # Multi-pane settings: General, Appearance, Privacy, Keyboard
```

### Key Technical Decisions

**`.nonactivatingPanel` for the floating window**
The clipboard panel uses `NSPanel` with the `.nonactivatingPanel` style mask. This lets the panel become the key window (and receive all keyboard events) without making Recall the active/frontmost application. The previous app stays active in the Dock — so "smart paste" can activate it and send ⌘V immediately after the panel closes.

**Carbon `RegisterEventHotKey` for the global shortcut**
`NSEvent.addGlobalMonitorForEvents` can't be used for a global keyboard shortcut that intercepts events. Recall uses the Carbon `RegisterEventHotKey` API, which fires synchronously on the main thread inside the user-interaction context of the key press — important because `NSApp.activate()` only works reliably within that context on macOS 14+.

**NSPasteboard polling instead of change notification**
`NSPasteboard` doesn't post reliable change notifications. Recall polls every 0.5 s on a background `DispatchQueue` using a `DispatchSourceTimer`, comparing `changeCount` to detect new content.

**Gated rich text extraction**
`NSAttributedString.readObjects(forClasses:options:)` silently synthesizes an `NSAttributedString` from plain text, which caused all text to be mis-classified as `.richText`. Recall gates the RTF extraction path on checking `pasteboard.types` for actual RTF/RTFD type declarations first.

**Image size cap**
Images are capped at 8 MB. If a screenshot or paste exceeds that, Recall downscales it to a thumbnail using `NSImage` rather than refusing to store it.

---

## Building from Source

**Requirements**
- macOS 14.0+
- Xcode 16+
- Swift 5.9+

```bash
git clone https://github.com/recall-macos/recall-macos.git
cd Recall
open Recall.xcodeproj
```

Hit **⌘R** in Xcode to build and run. No external dependencies — pure Apple frameworks only.

**Permissions required at runtime**
- Accessibility (for smart paste via `CGEvent`)
- Screen Recording (optional, for screenshot capture redirect)

---

## Advertising

Recall is free and ad-supported. A small, tasteful sponsor banner appears at the bottom of the clipboard panel — similar to how [Carbon Ads](https://www.carbonads.net) or [EthicalAds](https://www.ethicalads.io) work on developer websites. Sponsors get their product in front of a focused audience of developers and power users who interact with their clipboard dozens of times a day.

### How it works

```
Advertiser pays  →  you update ads/current.json  →  pushed to GitHub
       ↓
  App fetches it every hour  →  banner updates live for all users
       ↓
  User clicks banner  →  lands on advertiser's site
```

No SDK, no tracking, no third-party data collection. You control the ad directly.

### For advertisers

One sponsor slot at a time. The banner shows:
- Your logo (32×32px)
- A headline (≤ 50 chars)
- A one-line description (≤ 80 chars)
- A CTA button with a custom label and accent color

→ **Email [neel@vermaclub.com](mailto:neel@vermaclub.com?subject=Recall%20Sponsorship)** to book a slot.

### Changing the active ad

Edit `ads/current.json` and push:

```bash
git add ads/current.json && git commit -m "Update sponsor" && git push
```

The app picks it up within an hour. JSON schema:

```json
{
  "id": "sponsor-1",
  "headline": "Supercharge your workflow",
  "body": "The fastest launcher for Mac — try it free",
  "cta": "Get Raycast",
  "url": "https://raycast.com",
  "logoURL": "https://example.com/logo.png",
  "accentColor": "#FF6B35"
}
```

### Removing ads (users)

Users who want an ad-free experience can purchase a license key in **Settings → General → Enter License**. The key sets a local `isPro` flag — no server call, works offline, hides all banners permanently.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

*Built by [Neel Verma](https://github.com/Neel2code)*
