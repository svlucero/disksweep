# Application Contracts

DiskSweep has no network API, command-line API, or external service integration. `FolderAccessStore` persists one user-selected folder bookmark in `UserDefaults`; its important internal and operating-system contracts are:

- `FolderAccessStore.save(_:forVolumeID:at:)` stores an app-scoped security bookmark and grant date per mounted volume. `restore(forVolumeID:at:calendar:)` resolves valid bookmarks, refreshes stale data without extending the grant, and clears grants after one calendar month or when unusable. Undated legacy bookmarks are discarded.
- The app displays browsable mounted volumes independently from folder access. Pressing Scan checks for a current grant; if missing or expired, an `NSOpenPanel` opens at the selected volume and requires the user to choose its root. The app starts security-scoped access only after the user grants it.
- Scanning, lazy expansion, and deletion each revalidate the selected volume's grant and require its active security scope. A selected volume's capacity summary is shown independently of scan authorization.
- `DiskVolume.mounted(using:)` lists browsable mounted volumes with stable path identifiers; simulator images and internal support volumes are excluded. The disk selector uses this list and labels each volume by name and path.
- `DiskScanner.scan(progress:) async -> [DiskItem]` scans directories below its configured volume root to `maxDepth`, reports progress in `0.0...1.0`, skips unreadable entries and nested mount points, and returns descending-size results.
- `DiskScanner.children(of:) async -> [DiskEntry]` lists the immediate readable children of a directory, includes files and directories, calculates their sizes, and sorts them by descending size.
- `DiskSweepViewModel.authorizeFolder(_:)` accepts only the selected volume root, saves a one-month grant, and clears results from the previous root. `scan()` returns an authorization-required result without reading files when the selected volume has no valid grant; otherwise it publishes scan state, results, progress, filtered root nodes, and volume usage.
- `SizeThreshold` uses decimal byte boundaries from 10 MB through 1 GB; changing it re-filters loaded content without rescanning.
- `effectiveSelection` removes descendants when an ancestor is selected, preventing duplicate deletion work and double-counted sizes.
- `deleteSelected()` permanently removes selected filesystem items with `FileManager.removeItem(at:)`; the UI must obtain confirmation first. Failures remain visible through `deleteError`.
- Disk capacity comes from the selected folder's containing volume total capacity and capacity available for important usage. The header can show that volume's percent used, formatted free capacity, and formatted total capacity before scan-folder authorization; scanning still requires authorization.
- The generated macOS application targets macOS 13+, uses English as its development language and `com.disksweep.app` as its bundle identifier. App and build versions come from `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`; `make release` builds `dist/DiskSweep.zip`.
- `scripts/install.sh` consumes the public `DiskSweep.zip` asset at GitHub's latest-release download URL, installs to `~/Applications` unless a destination is passed, and removes the app's quarantine attribute because published builds are ad-hoc signed and not notarized.
- Public source distributions are licensed under MIT. Security reports use GitHub private vulnerability reporting rather than public issues.

See also [architecture](architecture.md) and [coding standards](coding_standards.md).
