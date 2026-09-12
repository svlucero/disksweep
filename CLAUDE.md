# CLAUDE.md

Guidance for Claude agents (and humans) working in this repository.

## Project Overview

**DiskSweep** is a native macOS desktop app (SwiftUI, macOS 13+) that helps the
user reclaim disk space. It scans the user's home directory (`~/`) to depth 2,
lists directories above a configurable size threshold, and lets the user select
and hard-delete them individually with a confirmation alert.

The UI is in **English**. There are **no external dependencies** — only Apple
frameworks (SwiftUI, Foundation).

The authoritative design lives in
[`docs/superpowers/specs/2026-06-27-disksweep-design.md`](docs/superpowers/specs/2026-06-27-disksweep-design.md).

## Architecture

Single-window SwiftUI app with three layers:

```
View (SwiftUI)
  └── ViewModel (@MainActor ObservableObject)
        └── DiskScanner (actor)
```

- **DiskScanner** (`Scanner/DiskScanner.swift`) — an `actor` that walks `~/` to
  depth 2 using `FileManager` + `URLResourceValues(.totalFileSizeKey)`, off the
  main thread. Returns `[DiskItem]` sorted by size descending. Skips files,
  nil-size entries, and permission-denied folders. Reports progress (0.0–1.0).
- **DiskSweepViewModel** (`ViewModels/DiskSweepViewModel.swift`) — a
  `@MainActor ObservableObject` that owns the scanner, publishes `allItems`,
  `filteredItems`, `threshold`, `scanState`, `scanProgress`, and disk-usage
  summary; exposes `deleteSelected()`. Changing the threshold re-filters
  instantly without re-scanning.
- **Views** (`Views/`) — `ContentView` (root layout), `ItemRow` (one list row),
  `BottomBar` (selection summary + delete button).
- **DiskItem** (`Models/DiskItem.swift`) — `Identifiable, Hashable` value type.

## Project Structure

```
DiskSweep/
├── DiskSweepApp.swift          # @main entry point
├── Models/DiskItem.swift
├── Scanner/DiskScanner.swift    # actor
├── ViewModels/DiskSweepViewModel.swift
├── Views/
│   ├── ContentView.swift
│   ├── ItemRow.swift
│   └── BottomBar.swift
DiskSweepTests/                  # unit tests (XCTest)
project.yml                      # XcodeGen project definition (source of truth)
docs/superpowers/specs/          # design spec
```

## Build System

The Xcode project is generated from `project.yml` via
[XcodeGen](https://github.com/yonsm/XcodeGen). The generated `DiskSweep.xcodeproj`
is **gitignored** — `project.yml` is the source of truth. Always regenerate
after pulling or editing `project.yml`.

## Commands

```bash
# Generate the Xcode project from project.yml (run after clone or project.yml edits)
xcodegen generate

# Build the app
xcodebuild -project DiskSweep.xcodeproj -scheme DiskSweep -destination 'platform=macOS' build

# Run the unit tests
xcodebuild -project DiskSweep.xcodeproj -scheme DiskSweep -destination 'platform=macOS' test
```

Requires Xcode 16+ and the `xcodegen` CLI (`brew install xcodegen`).

## Conventions

- **Language:** Swift; UI strings and repository documentation in English.
- **Concurrency:** keep scanning off the main thread (actor); the ViewModel is
  `@MainActor`. Swift language mode 5 is used to avoid strict-concurrency
  friction.
- **Deletes are destructive** — hard-delete via `FileManager.removeItem(at:)`
  (no Trash), always gated behind a confirmation alert. Never remove this guard.
- Scanning is limited to `~/` at depth 2 — do not broaden scope to the system.
- Commit style: conventional commits (`feat:`, `fix:`, `docs:`, `chore:`).
