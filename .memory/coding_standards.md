# Coding Standards

- Use Swift 5 and Apple frameworks only unless a dependency is explicitly justified.
- Keep UI state and filesystem mutations in the `@MainActor` view model; keep directory traversal in the `DiskScanner` actor.
- Scan the selected mounted volume to depth two; do not cross into nested mounted volumes.
- Let macOS manage protected-file permissions. Do not open a folder picker when access is denied; explain how to review permissions in System Settings.
- Keep mounted-volume discovery and disk-capacity reporting independent of protected-folder access.
- The app target is not App Sandbox enabled.
- Permanent deletion must always require explicit UI confirmation and surface failures.
- Use descriptive Swift names, four-space indentation, `MARK` sections for larger types, and documentation comments for non-obvious behavior.
- Format byte quantities with the shared `ByteFormatter`; keep user-facing copy and repository documentation in English.
- Add XCTest coverage for new non-UI behavior. Filesystem tests use isolated temporary directories and clean them up.
- Generate the project with `xcodegen generate`; use `make build`, `make test`, and `make release` for standard workflows. `make run` should restart an existing app process so users see the freshly built binary.
- Keep generated projects, build output, release archives, and macOS metadata out of commits. Use conventional commit prefixes such as `feat:`, `fix:`, `docs:`, `test:`, and `chore:`.

See also [architecture](architecture.md) and [application contracts](api_contracts.md).
