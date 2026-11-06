# Coding Standards

- Use Swift 5 and Apple frameworks only unless a dependency is explicitly justified.
- Keep UI state and filesystem mutations in the `@MainActor` view model; keep directory traversal in the `DiskScanner` actor.
- Scan only the user-authorized folder, to depth two for initial results; do not cross into mounted volumes nested below its root.
- Obtain filesystem access through the system folder picker; persist it with an app-scoped security bookmark and keep the security scope active while using that folder.
- Keep App Sandbox enabled and limit filesystem entitlements to the user-selected read/write folder and app-scoped bookmarks.
- Permanent deletion must always require an explicit confirmation alert and surface failures to the user.
- Use descriptive Swift names, four-space indentation, `MARK` sections for larger types, and documentation comments for non-obvious behavior.
- Format user-facing byte quantities with the shared `ByteFormatter`.
- Keep identifiers, comments, user-facing copy, and repository documentation in English.
- Add XCTest coverage for new non-UI behavior. Filesystem tests must use isolated temporary directories and clean them up.
- Generate the project with `xcodegen generate`; use `make build`, `make test`, and `make release` for standard workflows.
- Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` for releases; keep README installation and usage guidance aligned with app behavior.
- GitHub Actions must use read-only permissions by default and run the same `make test` command contributors use locally.
- Do not commit generated Xcode projects, derived data, build output, release archives, or macOS metadata.
- Use conventional commit prefixes such as `feat:`, `fix:`, `docs:`, `test:`, and `chore:`.

See also [architecture](architecture.md) and [application contracts](api_contracts.md).
