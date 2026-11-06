# Architecture

- DiskSweep is a native macOS 13+ SwiftUI application with no third-party runtime dependencies.
- `DiskSweepApp` creates the single application window and injects `DiskSweepViewModel` into the view hierarchy.
- Views in `DiskSweep/Views/` render the toolbar, selected-folder capacity summary, folder picker, flattened expandable file tree, selection summary, and destructive-delete confirmation.
- `DiskSweepViewModel` is `@MainActor`; it owns selected-folder access, scan state, filtering, tree expansion, selection de-duplication, deletion, and selected-folder usage reporting.
- `FolderAccessStore` persists a user-selected folder as an app-scoped security bookmark. The app restores and activates that scope on launch; the sandbox grants read/write access only to user-selected folders.
- `DiskVolume` discovers mounted volumes macOS marks as browsable, excluding support mounts such as simulator images and internal APFS helper volumes. `DiskScanner` scans a configured volume root to depth two, measures allocated file sizes, and avoids crossing into nested mounted volumes.
- The home folder is shown initially, but scanning is disabled until the user selects a folder. The selected folder is remembered across launches; selecting another folder clears prior results. Expanding a directory loads its immediate children lazily.
- `DiskItem` represents initial directory results; `DiskEntry` crosses the scanner actor boundary; `FileNode` is the observable UI tree node.
- `project.yml` is the XcodeGen source of truth for target settings and app/build versions; `make release` creates the distributable ZIP. The generated `DiskSweep.xcodeproj` and build artifacts are ignored.
- `DiskSweepTests/` contains XCTest coverage for scanning, filtering, formatting, sorting, progress, and lazy tree behavior.
- `.github/workflows/ci.yml` builds and tests pull requests and pushes to `main` on a pinned macOS 15 runner.
- Root-level community files define the MIT license, contribution process, conduct expectations, and private security-reporting path.

See also [coding standards](coding_standards.md) and [application contracts](api_contracts.md).
