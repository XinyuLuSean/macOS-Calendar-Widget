# My Calendar Widget

A small macOS menu-bar–style calendar widget with countdown and date-based todos. Built with SwiftUI and AppKit.

## Features

- **Countdown** — Set a target date and see days left; tap the date to change it.
- **Todos by date** — Add todos for today, yesterday, or future days; navigate with arrows or "Today".
- **Editable todos** — Click todo text to edit, drag todo text to reorder, and use the trash button to delete.
- **Words For Today** — Generate one brief motivational line from the current todo list with an OpenAI-compatible LLM API.
- **Floating window** — Drag from anywhere to move; resize via the grip in the bottom-right corner.
- **Settings** (gear icon) — Float above other windows, Launch at Login, and configure the Words API.

## Requirements

- macOS 14+ (Sonoma or later)
- Xcode 15+ (to build)
- An OpenAI-compatible chat completions API key for Words For Today

## Build & Run

```bash
xcodebuild -project MyCalendar.xcodeproj -scheme MyCalendar -configuration Release -sdk macosx SYMROOT="$PWD/build" build
open build/Release/MyCalendar.app
```

Or open `MyCalendar.xcodeproj` in Xcode and run (⌘R).

## Words API Setup

The app does not store API keys in source code. After launching the app:

1. Open the gear menu.
2. Choose **Words API Settings**.
3. Paste your API key.
4. Keep the default endpoint/model or change them for another OpenAI-compatible provider.

The key is saved locally in macOS app preferences for `com.xinyulu.MyCalendar`.

## Install to Applications

```bash
cp -R build/Release/MyCalendar.app /Applications/
open /Applications/MyCalendar.app
```

## Repository Notes

- Build products, derived data, user-specific Xcode files, and temporary files are ignored by `.gitignore`.
- Do not commit API keys or generated app bundles.

