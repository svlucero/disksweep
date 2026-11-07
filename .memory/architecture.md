# Architecture

- DiskSweep is a native macOS 13+ SwiftUI application with no third-party runtime dependencies.
- `DiskSweepApp` creates the single application window and injects `DiskSweepViewModel` into the view hierarchy.
- Views in `DiskSweep/Views/` render the mounted-disk selector, capacity summary, on-demand system access panel, flattened expandable file tree, selection summary, and destructive-delete confirmation.
- `DiskSweepViewModel` is `@MainActor`; it owns mounted-volume selection, scan-time authorization, scan state, filtering, tree expansion, selection de-duplication, deletion, and volume usage reporting.
- `FolderAccessStore` persists an app-scoped security bookmark and grant date per mounted volume. The view model activates a valid scope when scanning or accessing files; each grant expires after one calendar month.
- `DiskVolume` discovers mounted volumes macOS marks as browsable, excluding support mounts such as simulator images and internal APFS helper volumes. `DiskScanner` scans a configured volume root to depth two, measures allocated file sizes, and avoids crossing into nested mounted volumes.
- The home volume is selected initially, but no folder access is active by default. Pressing Scan requests access to the selected volume root if its grant is missing, revoked, or expired. Valid grants are remembered across launches; selecting another volume clears prior results. Expanding a directory loads its immediate children lazily and rechecks grant validity.
- `DiskItem` represents initial directory results; `DiskEntry` crosses the scanner actor boundary; `FileNode` is the observable UI tree node.
- `project.yml` is the XcodeGen source of truth for target settings and app/build versions; `make release` creates the distributable ZIP. The generated `DiskSweep.xcodeproj` and build artifacts are ignored.
- `scripts/install.sh` downloads the latest GitHub release ZIP and installs `DiskSweep.app` under `~/Applications` by default; README documents manual install and the ad-hoc signing/quarantine behavior.
- `DiskSweepTests/` contains XCTest coverage for scanning, filtering, formatting, sorting, progress, and lazy tree behavior.
- `.github/workflows/ci.yml` builds and tests pull requests and pushes to `main` on a pinned macOS 15 runner.
- Root-level community files define the MIT license, contribution process, conduct expectations, and private security-reporting path.

See also [coding standards](coding_standards.md) and [application contracts](api_contracts.md).
