# Application Contracts

DiskSweep has no network API, command-line API, persistence layer, or external service integration. Its important internal and operating-system contracts are:

- `DiskScanner.scan(progress:) async -> [DiskItem]` scans directories below its configured root to `maxDepth`, reports progress in `0.0...1.0`, skips unreadable entries, and returns descending-size results.
- `DiskScanner.children(of:) async -> [DiskEntry]` lists the immediate readable children of a directory, includes files and directories, calculates their sizes, and sorts them by descending size.
- `DiskSweepViewModel.scan()` publishes scan state, results, progress, filtered root nodes, and refreshed disk usage.
- `SizeThreshold` uses decimal byte boundaries from 10 MB through 1 GB; changing it re-filters loaded content without rescanning.
- `effectiveSelection` removes descendants when an ancestor is selected, preventing duplicate deletion work and double-counted sizes.
- `deleteSelected()` permanently removes selected filesystem items with `FileManager.removeItem(at:)`; the UI must obtain confirmation first. Failures remain visible through `deleteError`.
- Disk capacity comes from the home volume's total capacity and capacity available for important usage.
- The generated macOS application targets macOS 13+, uses English as its development language and `com.disksweep.app` as its bundle identifier, and is distributed as `dist/DiskSweep.zip` by `make release`.
- Public source distributions are licensed under MIT. Security reports use GitHub private vulnerability reporting rather than public issues.

See also [architecture](architecture.md) and [coding standards](coding_standards.md).
