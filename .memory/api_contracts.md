# Application Contracts

DiskSweep has no network API, command-line API, or external service integration. Its internal and operating-system contracts are:

- `DiskVolume.mounted(using:)` lists browsable mounted volumes with stable path identifiers; the disk picker remains available before scanning.
- `DiskScanner.scan(expiredFolderPaths:progress:) throws -> [DiskItem]` scans the configured volume root to depth two, reports progress in `0.0...1.0`, skips nested mount points, and returns size-sorted results. A denied or expired folder throws `DiskScannerError.accessRequired(URL)` so the view can request that folder.
- `DiskScanner.children(of:expiredFolderPaths:) throws -> [DiskEntry]` lists and sizes immediate children; denied or expired access uses the same error.
- `FolderAccessStore.save(_:at:)` stores the user-selected folder bookmark and approval date keyed by standardized path. `restore(forFolderURL:at:calendar:)` and `validFolderURLs(at:calendar:)` resolve grants during their one-calendar-month lifetime; `expiredFolderPaths(at:calendar:)` identifies paths that must be authorized again.
- `DiskSweepViewModel.scan()` begins without a prior volume grant. On `accessRequired`, it sets `pendingAccessURL`, increments `authorizationRequestID`, and returns `.authorizationRequired`; the UI asks the user to select that exact folder and restarts the scan after approval.
- Lazy expansion and deletion re-check expired approvals. Deletion permanently removes selected items via `FileManager.removeItem(at:)`; the UI must confirm first, and failures remain visible.
- Disk capacity uses the selected mounted volume's total and available capacity and is shown independently of folder access.
- `SizeThreshold` uses decimal byte boundaries from 10 MB through 1 GB; `effectiveSelection` removes descendants to avoid duplicate deletion work and size counts.
- The generated macOS app targets macOS 13+, uses `com.disksweep.app`, and takes version numbers from `project.yml`; `make release` creates `dist/DiskSweep.zip`.
- `scripts/install.sh` installs the public latest-release ZIP to `~/Applications` unless a destination is passed. Releases are ad-hoc signed and not notarized.
- Public source distributions use the MIT license; security reports use GitHub private vulnerability reporting.

See also [architecture](architecture.md) and [coding standards](coding_standards.md).
