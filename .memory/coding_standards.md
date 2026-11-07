# Coding Standards

- Use Swift 5 and Apple frameworks only unless a dependency is explicitly justified.
- Keep UI state and filesystem mutations in the `@MainActor` view model; keep directory traversal in the `DiskScanner` actor.
- Scan only the selected, user-authorized volume root, to depth two for initial results; do not cross into nested mounted volumes.
- Show mounted volumes independently of authorization. Request the selected volume root through the system access panel only when scanning or another filesystem operation needs access.
- Persist grants per volume as app-scoped security bookmarks with a one-calendar-month lifetime. Revalidate before every file operation and stop using the scope before any operation after expiry.
- Keep the selected volume's capacity summary independent of scan authorization; scanning and filesystem traversal still require a valid, active grant.
- Keep App Sandbox enabled and limit filesystem entitlements to user-selected read/write volumes and app-scoped bookmarks.
- Permanent deletion must always require an explicit confirmation alert and surface failures to the user.
- Use descriptive Swift names, four-space indentation, `MARK` sections for larger types, and documentation comments for non-obvious behavior.
- Format user-facing byte quantities with the shared `ByteFormatter`.
- Keep identifiers, comments, user-facing copy, and repository documentation in English.
- Add XCTest coverage for new non-UI behavior. Filesystem tests must use isolated temporary directories and clean them up.
- Generate the project with `xcodegen generate`; use `make build`, `make test`, and `make release` for standard workflows.
- Keep the macOS release installer in `scripts/`; default to a per-user install location and document any Gatekeeper/quarantine handling in README.
- Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` for releases; keep README installation and usage guidance aligned with app behavior.
- GitHub Actions must use read-only permissions by default and run the same `make test` command contributors use locally.
- Do not commit generated Xcode projects, derived data, build output, release archives, or macOS metadata.
- Use conventional commit prefixes such as `feat:`, `fix:`, `docs:`, `test:`, and `chore:`.

See also [architecture](architecture.md) and [application contracts](api_contracts.md).
