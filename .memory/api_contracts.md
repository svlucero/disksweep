# Application Contracts

DiskSweep has no network API, command-line API, or external service integration. `FolderAccessStore` persists one user-selected folder bookmark in `UserDefaults`; its important internal and operating-system contracts are:

- `FolderAccessStore.save(_:)` stores an app-scoped security bookmark; `restore()` resolves it on launch, refreshes stale bookmark data, and clears unusable bookmark data. The view model starts security-scoped access and keeps it active while scanning, expanding, and deleting within the selected folder.
- The app uses the system folder picker to obtain read/write access. Scanning remains idle until a valid folder is authorized; a missing or revoked bookmark requires selecting a folder again.
- `DiskVolume.mounted(using:)` lists browsable mounted volumes with stable path identifiers; simulator images and internal support mounts are excluded. `DiskVolume` also labels the user-selected scan root.
- `DiskScanner.scan(progress:) async -> [DiskItem]` scans directories below its configured volume root to `maxDepth`, reports progress in `0.0...1.0`, skips unreadable entries and nested mount points, and returns descending-size results.
- `DiskScanner.children(of:) async -> [DiskEntry]` lists the immediate readable children of a directory, includes files and directories, calculates their sizes, and sorts them by descending size.
- `DiskSweepViewModel.authorizeFolder(_:)` activates and remembers a selected folder, then clears results from the previous root. `scan()` does nothing until access is valid, then publishes scan state, results, progress, filtered root nodes, and selected-folder usage.
- `SizeThreshold` uses decimal byte boundaries from 10 MB through 1 GB; changing it re-filters loaded content without rescanning.
- `effectiveSelection` removes descendants when an ancestor is selected, preventing duplicate deletion work and double-counted sizes.
- `deleteSelected()` permanently removes selected filesystem items with `FileManager.removeItem(at:)`; the UI must obtain confirmation first. Failures remain visible through `deleteError`.
- Disk capacity comes from the selected folder's containing volume total capacity and capacity available for important usage. The header reports that volume's percent used, formatted free capacity, and formatted total capacity.
- The generated macOS application targets macOS 13+, uses English as its development language and `com.disksweep.app` as its bundle identifier. App and build versions come from `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`; `make release` builds `dist/DiskSweep.zip`.
- `scripts/install.sh` consumes the public `DiskSweep.zip` asset at GitHub's latest-release download URL, installs to `~/Applications` unless a destination is passed, and removes the app's quarantine attribute because published builds are ad-hoc signed and not notarized.
- Public source distributions are licensed under MIT. Security reports use GitHub private vulnerability reporting rather than public issues.

See also [architecture](architecture.md) and [coding standards](coding_standards.md).
