# My Calendar Widget

A small macOS menu-bar–style calendar widget with countdown and date-based todos. Built with SwiftUI and AppKit.

## Features

- **Countdown** — Set a target date and see days left; tap the date to change it.
- **Todos by date** — Add todos for today, yesterday, or future days; navigate with arrows or "Today".
- **Floating window** — Drag from anywhere to move; resize via the grip in the bottom-right corner.
- **Settings** (gear icon) — Float above other windows; Launch at Login.

## Requirements

- macOS 14+ (Sonoma or later)
- Xcode 15+ (to build)

## Build & Run

```bash
cd MyCalendar
xcodebuild -project MyCalendar.xcodeproj -scheme MyCalendar -configuration Release -sdk macosx build
open build/Release/MyCalendar.app
```

Or open `MyCalendar.xcodeproj` in Xcode and run (⌘R).

## Install to Applications

```bash
cp -R build/Release/MyCalendar.app /Applications/
open /Applications/MyCalendar.app
```

## License

[Choose a license — e.g. MIT, Apache 2.0 — and add a LICENSE file.]
