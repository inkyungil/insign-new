# Repository Guidelines

## Project Structure & Module Organization
`insign_flutter/` is the only actively maintained app; all shipping code lives under `lib/`, where `lib/screens/` drives UI flows, `lib/providers/` hosts state, `lib/services/` centralizes integration logic, and `lib/theme/` exposes tokens. Each Dart file in `lib/` must have a mirror under `test/` (for example `lib/providers/user_provider.dart` pairs with `test/providers/user_provider_test.dart`) to keep coverage steady. Assets belong in `insign_flutter/assets/` and must be registered in `pubspec.yaml`. Legacy projects (`expo_insign/`, `nestjs_app/`, `web/`) are reference-only; consult their maintainers before editing.

## Build, Test, and Development Commands
Run `cd insign_flutter && flutter pub get` whenever dependencies or assets change. Use `flutter analyze` for static checks, `dart format .` for the canonical two-space format, and `flutter test` (or `flutter test test/screens/login_screen_test.dart`) to execute suites. Validate devices with `flutter devices` and launch with `flutter run -d <id>`.

## Coding Style & Naming Conventions
Follow Flutter defaults: files use `snake_case.dart`, classes UpperCamelCase, members lowerCamelCase, and constants SCREAMING_SNAKE_CASE. Prefer `final` and `const` where possible, keep imports sorted, and avoid unused exports. Pull typography, spacing, and color from `lib/theme/` instead of embedding literals so that design tokens remain authoritative.

## Testing Guidelines
All specs rely on `package:flutter_test/flutter_test.dart` and should group scenarios with descriptive `group()` names. Widget goldens belong beside their subjects in `test/screens/`; refresh intentional changes with `flutter test --update-goldens`. Run `flutter test --coverage` before merging and focus regression passes on auth, payments, and provider mutations.

## Commit & Pull Request Guidelines
Commits use imperative subjects such as `Add contract detail screen` and should reference tickets (`Closes #123`). Pull requests must recap what changed, list commands executed (`flutter analyze`, `flutter test`, device runs), and attach screenshots or recordings for UI adjustments. Call out schema, environment, or release-impacting shifts so QA can schedule verification.

## Security & Configuration Tips
Never commit secrets, API keys, or keystores. Keep `.gitignore`, `pubspec.yaml`, and `insign_flutter/assets/` in sync to avoid stray artifacts. Test Android and iOS builds on representative hardware after any platform change, and capture new toggles or configuration flags in release notes.
