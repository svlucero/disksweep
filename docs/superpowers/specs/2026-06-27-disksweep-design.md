# DiskSweep — Design Spec
_Date: 2026-06-27_

## Overview

A native macOS desktop app (SwiftUI, macOS 13+) that scans the user's home directory, displays folders above a configurable size threshold, and lets the user select and delete them individually with confirmation.

## Goals

- Show what's consuming disk space in `~/` at depth 2
- Filter by configurable size threshold (re-filters instantly without re-scanning)
- Select and delete items one at a time with a confirmation alert
- No external dependencies

## Non-Goals

- System-level scanning (outside `~/`)
- Scheduling or automated cleanup
- Moving to Trash (hard-delete only, same as `rm -rf`)

---

## Architecture

Single-window SwiftUI app. Three layers:

```
View (SwiftUI)
  └── ViewModel (ObservableObject)
        └── DiskScanner (Actor)
```

### DiskScanner (Actor)

Async actor that walks `~/` to depth 2 using `FileManager` and `URLResourceValues(.totalFileSizeKey)`. Returns an array of `DiskItem` sorted by size descending. Runs entirely off the main thread.

### ViewModel

`@MainActor ObservableObject` that:
- Owns the `DiskScanner`
- Publishes `allItems: [DiskItem]` (full scan results)
- Publishes `filteredItems: [DiskItem]` (allItems filtered by threshold)
- Holds `threshold: Int64` (bytes) — changing it refilters instantly
- Holds `scanState: ScanState` (idle / scanning / done / error)
- Exposes `deleteItem(_ item: DiskItem)` — removes from disk, then from allItems

### DiskItem Model

```swift
struct DiskItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String          // last path component
    let parentLabel: String   // abbreviated parent path shown in UI
    let size: Int64           // bytes
    var isSelected: Bool
}
```

---

## UI

### Single window layout

```
┌─────────────────────────────────────────────────┐
│  DiskSweep      Show >[ 50 MB ▾]      [Scan]    │
│                 Disk: 71% used · 56 GB free     │
├─────────────────────────────────────────────────┤
│  ☐  .android          ~/             17 GB       │
│  ☐  com.docker.docker Library/       17 GB       │
│  ☐  .ollama           ~/             13 GB       │
│  ...                                             │
├─────────────────────────────────────────────────┤
│  2 items selected · 30 GB             [Delete]   │
└─────────────────────────────────────────────────┘
```

### Toolbar (top)
- App title
- Threshold picker: `10 MB / 50 MB / 100 MB / 500 MB / 1 GB`
- Disk usage summary: `XX% used · YY GB free` (updated after each delete)
- "Scan" button — triggers scan, shows spinner while running

### Item list
- Each row: checkbox · name · parent path (abbreviated, muted) · size (right-aligned)
- Sorted by size descending
- Filtered live by threshold (no re-scan needed)
- Empty state: "No items larger than X MB" if nothing matches

### Bottom bar
- Left: `N items selected · X GB`
- Right: `[Delete]` button — enabled only when ≥1 item selected

### Delete flow
1. User checks one or more items
2. Clicks "Delete"
3. Alert: "Delete [name] (X GB)? This action cannot be undone."
4. On confirm: `rm -rf` via `FileManager.removeItem(at:)`
5. Item removed from list, disk summary updated

---

## Threshold Options

| Label  | Bytes       |
|--------|-------------|
| 10 MB  | 10_000_000  |
| 50 MB  | 50_000_000  |
| 100 MB | 100_000_000 |
| 500 MB | 500_000_000 |
| 1 GB   | 1_000_000_000 |

Default: 50 MB.

---

## Scan Behavior

- Scans `~/` to depth 2 only (not recursive beyond that)
- Skips items where `URLResourceValues` returns nil size (permission denied, symlinks, etc.)
- Skips files (only directories)
- Reports progress via a published `scanProgress: Double` (0.0–1.0) for the progress bar

---

## Error Handling

- Permission denied on a folder: skip silently, continue scan
- Delete fails: show an Alert with the error message, item stays in list
- Scan finds 0 items above threshold: show empty state message

---

## Project Structure

```
DiskSweep/
├── DiskSweepApp.swift          # @main entry point
├── Models/
│   └── DiskItem.swift
├── Scanner/
│   └── DiskScanner.swift       # Actor
├── ViewModels/
│   └── DiskSweepViewModel.swift
├── Views/
│   ├── ContentView.swift       # root layout
│   ├── ItemRow.swift           # single list row
│   └── BottomBar.swift         # selection summary + delete button
└── docs/
    └── superpowers/specs/
        └── 2026-06-27-disksweep-design.md
```

---

## Out of Scope (v1)

- Sorting by other columns (name, path)
- Search/filter by name
- "Select all" button
- Moving to Trash instead of hard-delete
- Dark mode customization (SwiftUI handles it automatically)
