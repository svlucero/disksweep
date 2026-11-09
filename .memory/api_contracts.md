# Application Contracts

DiskSweep has no network API, command-line API, or external service integration. Its internal and operating-system contracts are:

- `DiskVolume.mounted(using:)` lists browsable mounted volumes with stable path identifiers; the disk picker remains available before scanning.
- `DiskScanner.scan(progress:) throws -> [DiskItem]` scans the configured volume root to depth two, reports progress in `0.0...1.0`, skips nested mount points, and returns size-sorted results. An OS access denial throws `DiskScannerError.accessRequired(URL)`.
- `DiskScanner.children(of:) throws -> [DiskEntry]` lists and sizes immediate children; denied access uses `DiskScannerError.accessRequired(URL)`.
- `DiskSweepViewModel.scan()` starts without a prior folder selection. On access denial it returns `.permissionDenied`, publishes Full Disk Access guidance, and the UI opens no folder picker. After the user enables DiskSweep in System Settings, they can retry.
- `SystemSettingsLink.fullDiskAccess` opens the macOS 13+ Privacy & Security > Full Disk Access pane directly. Granting permission remains a user action in System Settings.
- Lazy expansion directs denied access to the same settings pane. Deletion permanently removes selected items via `FileManager.removeItem(at:)`; the UI must confirm first, and failures remain visible.
- Disk capacity uses the selected mounted volume's total and available capacity and is shown independently of protected-folder access.
- `SizeThreshold` uses decimal byte boundaries from 10 MB through 1 GB; `effectiveSelection` removes descendants to avoid duplicate deletion work and size counts.
- The generated macOS app targets macOS 13+, uses `com.disksweep.app`, and takes version numbers from `project.yml`; `make release` creates `dist/DiskSweep.zip`.
- `make run` signs local Debug builds with Apple Development to provide a stable code identity for macOS privacy permissions; the release target retains its own signing behavior.
- `scripts/install.sh` installs the public latest-release ZIP to `~/Applications` unless a destination is passed. Releases are ad-hoc signed and not notarized.
- Public source distributions use the MIT license; security reports use GitHub private vulnerability reporting.

See also [architecture](architecture.md) and [coding standards](coding_standards.md).
