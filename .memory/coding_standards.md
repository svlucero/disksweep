# Coding Standards

- Use Swift 5 and Apple frameworks only unless a dependency is explicitly justified.
- Keep UI state and filesystem mutations in the `@MainActor` view model; keep directory traversal in the `DiskScanner` actor.
- Preserve the home-directory and depth-two scan boundary. Do not silently expand scanning to system paths.
- Permanent deletion must always require an explicit confirmation alert and surface failures to the user.
- Use descriptive Swift names, four-space indentation, `MARK` sections for larger types, and documentation comments for non-obvious behavior.
- Keep user-facing copy and repository documentation in English.
- Add XCTest coverage for new non-UI behavior. Filesystem tests must use isolated temporary directories and clean them up.
- Generate the project with `xcodegen generate`; use `make build`, `make test`, and `make release` for standard workflows.
- Do not commit generated Xcode projects, derived data, build output, release archives, or macOS metadata.
- Use conventional commit prefixes such as `feat:`, `fix:`, `docs:`, `test:`, and `chore:`.

See also [architecture](architecture.md) and [application contracts](api_contracts.md).
