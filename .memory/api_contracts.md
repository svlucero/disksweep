# Application Contracts

DiskSweep has no network API, command-line API, or external service integration. Its internal contracts are:

- `DiskVolume.mounted(using:)` lists browsable mounted volumes with stable path identifiers; the disk picker remains available before scanning.
- `DiskScanner.scan(progress:) -> [DiskItem]` scans the configured volume root to depth two, reports progress in `0.0...1.0`, skips nested mount points and unreadable folders, and returns size-sorted results.
- `DiskScanner.children(of:) -> [DiskEntry]` lists readable immediate children and their sizes; inaccessible folders or entries are omitted.
- `DiskSweepViewModel.scan()` starts immediately without a permission dialog. The UI displays readable results and continues past folders the current user cannot read.
- Deletion permanently removes selected items via `FileManager.removeItem(at:)`; the UI must confirm first, and failures remain visible.
- Disk capacity uses the selected mounted volume's total and available capacity and is shown independently of scan results.
- `SizeThreshold` uses decimal byte boundaries from 10 MB through 1 GB; `effectiveSelection` removes descendants to avoid duplicate deletion work and size counts.
- The generated macOS app targets macOS 13+, uses `com.disksweep.app`, and takes version numbers from `project.yml`; `make release` creates `dist/DiskSweep.zip`.
- `make run` terminates existing DiskSweep processes before opening the newly built app.
- `scripts/install.sh` installs the public latest-release ZIP to `~/Applications` unless a destination is passed. Releases are ad-hoc signed and not notarized.
- Public source distributions use the MIT license; security reports use GitHub private vulnerability reporting.

See also [architecture](architecture.md) and [coding standards](coding_standards.md).
