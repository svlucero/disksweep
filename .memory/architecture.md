# Architecture

- DiskSweep is a native macOS 13+ SwiftUI application with no third-party runtime dependencies.
- `DiskSweepApp` creates the single application window and injects `DiskSweepViewModel` into the view hierarchy.
- Views in `DiskSweep/Views/` render mounted-disk selection, capacity summary, the expandable file tree, selection summary, and deletion confirmation.
- `DiskSweepViewModel` is `@MainActor`; it owns disk selection, scan state, filtering, tree expansion, selection de-duplication, deletion, and volume usage reporting.
- `DiskVolume` discovers browsable mounted volumes. `DiskScanner` scans the selected volume to depth two, measures allocated file sizes, avoids nested mounted volumes, and skips unreadable folders while continuing the scan.
- `DiskItem` represents initial directory results; `DiskEntry` crosses the scanner actor boundary; `FileNode` is the observable UI tree node.
- `project.yml` is the XcodeGen source of truth. The app target is not App Sandbox enabled; `make run` stops previous DiskSweep processes before launching the fresh app, and `make release` creates the distributable ZIP.
- `scripts/install.sh` downloads the latest GitHub release ZIP and installs `DiskSweep.app` under `~/Applications` by default.
- `DiskSweepTests/` contains XCTest coverage for scan behavior, unreadable-folder skipping, filtering, formatting, sorting, progress, and lazy tree navigation.
- `.github/workflows/ci.yml` builds and tests pull requests and pushes to `main` on a pinned macOS runner.

See also [coding standards](coding_standards.md) and [application contracts](api_contracts.md).
