# Repository Guidelines

## Project Structure & Module Organization
- `lib/` hosts production code; scope features to `lib/features/<feature>` and share reusable logic via `lib/services/`, `lib/core/`, and `lib/utils/`. Entry points live in `lib/main.dart` and `lib/app.dart`.
- Mirror runtime code in `test/`, naming counterparts `<file_name>_test.dart`. Keep shared fixtures in `test/fixtures/` when created.
- Asset bundles (images, fonts, lottie) belong under `assets/`; declare additions in `pubspec.yaml` so they ship in builds.
- Platform runners (`android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`) are primarily for build configuration—coordinate platform-specific tweaks with mobile/web maintainers.

## Build, Test, and Development Commands
- `flutter pub get` — install declared dependencies before running or analyzing code.
- `flutter run -d <device_id>` — launch the app for interactive debugging on emulators or hardware.
- `flutter analyze` — enforce `analysis_options.yaml`, stopping on lint or style regressions.
- `flutter test` — run unit and widget tests; prefer `--coverage` locally when touching core logic.
- `flutter build apk --release` / `flutter build ios --release` — produce store-ready binaries only after green analyze + test runs.

## Coding Style & Naming Conventions
- Adopt Flutter defaults: two-space indentation, trailing commas for multi-line literals, concise `//` comments.
- File names stay `snake_case.dart`; classes in `UpperCamelCase`, methods and locals in `lowerCamelCase`, and shared constants in `SCREAMING_SNAKE_CASE`.
- Let `dart format` and `flutter analyze` guide structure—resolve warnings rather than ignoring them.

## Testing Guidelines
- Create tests alongside new features; use `group` blocks to mirror the folder hierarchy.
- Prefer `flutter_test` for widget coverage and mock shared services via lightweight fakes under `test/support/` if needed.
- Document skipped tests with TODOs referencing an issue; revisit before release branches are cut.

## Commit & Pull Request Guidelines
- Follow Conventional Commits (`feat:`, `fix:`, `chore:`) in present tense; bundle only related changes.
- Before committing, run `flutter analyze && flutter test` and stage generated files intentionally.
- Pull requests should summarize scope, link issues or tasks, list manual/automated checks, and attach UI screenshots or screen recordings when visuals change.

## Security & Configuration Tips
- Treat root-level OAuth and keystore JSON files as sensitive; never rename or replace them without credential rotation.
- Execute `get_keyhash.ps1` only on trusted machines and keep resulting hashes out of version control.
