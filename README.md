# DiskSweep

[![CI](https://github.com/svlucero/disksweep/actions/workflows/ci.yml/badge.svg)](https://github.com/svlucero/disksweep/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black.svg)](https://www.apple.com/macos/)

DiskSweep is a native macOS app that helps you find and remove files and folders
that consume significant disk space. It scans your home directory, presents the
results as a navigable tree, and requires confirmation before permanently
deleting anything.

DiskSweep is built with SwiftUI and Foundation and has no runtime dependencies.

## Features

- Scans the first two levels of your home directory without blocking the UI.
- Displays scan progress and current disk usage.
- Expands folders lazily so you can inspect their contents before deleting them.
- Filters every tree level using a configurable threshold from 10 MB to 1 GB.
- Supports native macOS multiple selection with Command-click and Shift-click.
- Shows the full path and combined size of the effective selection.
- Sorts entries by size at every level.
- Requires explicit confirmation before deletion and reports deletion failures.

## Important: deletion is permanent

DiskSweep uses `FileManager.removeItem(at:)`, which is equivalent to permanently
deleting the selected items. Files are **not moved to Trash**, and the action
cannot be undone. Review every selected path carefully before confirming.

## Installation

1. Download `DiskSweep.zip` from the
   [latest release](https://github.com/svlucero/disksweep/releases/latest).
2. Unzip it and drag `DiskSweep.app` into `/Applications`.
3. The release is ad-hoc signed rather than notarized with an Apple Developer ID.
   On first launch, either right-click the app and choose **Open**, or remove the
   quarantine attribute from Terminal:

   ```bash
   xattr -dr com.apple.quarantine /Applications/DiskSweep.app
   ```

## Usage

1. Click **Scan** to analyze your home directory.
2. Choose a threshold from **Show >** to hide smaller entries immediately.
3. Expand folders with the disclosure chevron to inspect their contents.
4. Select files or folders. Use Command-click or Shift-click for multiple items.
5. Review the path and total size, click **Delete**, and confirm the warning.

## Development

### Requirements

- macOS 13 or newer
- Xcode 16 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), installable with
  `brew install xcodegen`

`project.yml` is the source of truth for the Xcode project. The generated
`DiskSweep.xcodeproj` is intentionally not committed.

### Commands

```bash
make run       # Generate the project, build in Debug mode, and open the app
make build     # Build the app in Release mode
make test      # Run the unit tests
make release   # Create dist/DiskSweep.zip
make clean     # Remove generated and build artifacts
make help      # List available commands
```

To work directly in Xcode:

```bash
xcodegen generate
open DiskSweep.xcodeproj
```

## Architecture

DiskSweep is a single-window SwiftUI app with three layers:

```text
View (SwiftUI)
  └── ViewModel (@MainActor ObservableObject)
        └── DiskScanner (actor)
```

- `DiskScanner` scans the home directory to depth two and loads expanded folder
  contents on demand, off the main actor.
- `DiskSweepViewModel` owns scan state, threshold filtering, tree state,
  selection, permanent deletion, and disk-usage reporting.
- `FileNode` represents an observable node whose children are loaded lazily.
- `ContentView`, `NodeRow`, and `BottomBar` render the application.

The detailed behavior is documented in the
[design specification](docs/superpowers/specs/2026-06-27-disksweep-design.md).

## Testing

```bash
make test
```

The XCTest suite covers size formatting, threshold filtering, ordering, scan
progress, tree navigation, and filesystem scanning against temporary fixtures.
It does not scan or modify your real home directory.

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md), the
[Code of Conduct](CODE_OF_CONDUCT.md), and the [Security Policy](SECURITY.md)
before opening an issue or pull request.

## License

DiskSweep is available under the [MIT License](LICENSE).
