# Coding Standards

- Use Swift 5 and Apple frameworks only unless a dependency is explicitly justified.
- Keep UI state and filesystem mutations in the `@MainActor` view model; keep directory traversal in the `DiskScanner` actor.
- Scan the selected mounted volume to depth two; do not cross into nested mounted volumes.
- Request folder access only when a directory is blocked. Persist approved folder bookmarks for one calendar month and ask again after expiration.
- Keep mounted-volume discovery and disk-capacity reporting independent of folder access.
- The app target is not App Sandbox enabled; use user-selected folder access when macOS blocks traversal.
- Permanent deletion must always require explicit UI confirmation and surface failures.
- Use descriptive Swift names, four-space indentation, `MARK` sections for larger types, and documentation comments for non-obvious behavior.
- Format byte quantities with the shared `ByteFormatter`; keep user-facing copy and repository documentation in English.
- Add XCTest coverage for new non-UI behavior. Filesystem tests use isolated temporary directories and clean them up.
- Generate the project with `xcodegen generate`; use `make build`, `make test`, and `make release` for standard workflows. `make run` stops existing app processes before launch so users see the freshly built binary.
- Keep generated projects, build output, release archives, and macOS metadata out of commits. Use conventional commit prefixes such as `feat:`, `fix:`, `docs:`, `test:`, and `chore:`.

See also [architecture](architecture.md) and [application contracts](api_contracts.md).
