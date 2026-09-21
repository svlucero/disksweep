# Architecture

- DiskSweep is a native macOS 13+ SwiftUI application with no third-party runtime dependencies.
- `DiskSweepApp` creates the single application window and injects `DiskSweepViewModel` into the view hierarchy.
- Views in `DiskSweep/Views/` render the toolbar, flattened expandable file tree, selection summary, and destructive-delete confirmation.
- `DiskSweepViewModel` is `@MainActor`; it owns scan state, filtering, tree expansion, selection de-duplication, deletion, and disk-usage reporting.
- `DiskScanner` is an actor. It scans directories outside the main actor, measures allocated file sizes, and returns entries sorted by descending size.
- The initial scan is restricted to the user's home directory at depth two. Expanding a directory loads its immediate children lazily.
- `DiskItem` represents initial directory results; `DiskEntry` crosses the scanner actor boundary; `FileNode` is the observable UI tree node.
- `project.yml` is the XcodeGen source of truth and sets English as the development language. The generated `DiskSweep.xcodeproj` and build artifacts are ignored.
- `DiskSweepTests/` contains XCTest coverage for scanning, filtering, formatting, sorting, progress, and lazy tree behavior.
- `.github/workflows/ci.yml` builds and tests pull requests and pushes to `main` on a pinned macOS 15 runner.
- Root-level community files define the MIT license, contribution process, conduct expectations, and private security-reporting path.

See also [coding standards](coding_standards.md) and [application contracts](api_contracts.md).
