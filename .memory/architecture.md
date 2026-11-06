# Architecture

- DiskSweep is a native macOS 13+ SwiftUI application with no third-party runtime dependencies.
- `DiskSweepApp` creates the single application window and injects `DiskSweepViewModel` into the view hierarchy.
- Views in `DiskSweep/Views/` render the toolbar, flattened expandable file tree, selection summary, and destructive-delete confirmation.
- `DiskSweepViewModel` is `@MainActor`; it owns mounted-volume selection, scan state, filtering, tree expansion, selection de-duplication, deletion, and selected-volume usage reporting.
- `DiskVolume` discovers mounted volumes macOS marks as browsable, excluding support mounts such as simulator images and internal APFS helper volumes. `DiskScanner` scans a configured volume root to depth two, measures allocated file sizes, and avoids crossing into nested mounted volumes.
- The home volume is selected initially. Selecting another mounted volume clears old results; expanding a directory loads its immediate children lazily.
- `DiskItem` represents initial directory results; `DiskEntry` crosses the scanner actor boundary; `FileNode` is the observable UI tree node.
- `project.yml` is the XcodeGen source of truth and sets English as the development language. The generated `DiskSweep.xcodeproj` and build artifacts are ignored.
- `DiskSweepTests/` contains XCTest coverage for scanning, filtering, formatting, sorting, progress, and lazy tree behavior.
- `.github/workflows/ci.yml` builds and tests pull requests and pushes to `main` on a pinned macOS 15 runner.
- Root-level community files define the MIT license, contribution process, conduct expectations, and private security-reporting path.

See also [coding standards](coding_standards.md) and [application contracts](api_contracts.md).
