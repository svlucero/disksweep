# Contributing to DiskSweep

Thank you for helping improve DiskSweep. Bug reports, feature proposals,
documentation fixes, and code contributions are welcome.

## Before you begin

- Search existing issues before opening a new one.
- Use the provided issue form and include reproducible details for bugs.
- For substantial changes, open an issue first so the approach can be discussed.
- Follow the [Code of Conduct](CODE_OF_CONDUCT.md) and report security problems
  through the process in [SECURITY.md](SECURITY.md), not a public issue.

## Local setup

You need macOS 13+, Xcode 16+, and XcodeGen:

```bash
brew install xcodegen
git clone https://github.com/svlucero/disksweep.git
cd disksweep
make test
```

Run `make run` to build and open the app. The generated Xcode project and build
artifacts must remain untracked.

## Making a change

1. Fork the repository and create a focused branch from `main`.
2. Keep scanning outside the main actor and UI state on `@MainActor`.
3. Preserve the depth-two home scan boundary and deletion confirmation guard.
4. Keep user-facing text and documentation in English.
5. Add or update tests for non-UI behavior.
6. Run `make test` before submitting your pull request.

Use conventional commit messages such as `feat:`, `fix:`, `docs:`, `test:`, or
`chore:`. Pull requests should explain the user-visible impact, testing performed,
and any safety implications.
