# Repository Guidelines

## Project Structure & Module Organization
`insign_flutter/` hosts the production Flutter app, with UI flows split into `lib/screens/`, state in `lib/providers/`, shared services in `lib/services/`, and tokens plus theming helpers in `lib/theme/`. Every Dart source under `lib/` needs a matching spec in `test/` (for example `lib/providers/user_provider.dart` pairs with `test/providers/user_provider_test.dart`) so coverage dashboards remain stable. Asset pipelines expect fonts, images, and Lottie clips inside `insign_flutter/assets/` and registered in `pubspec.yaml`. Historical projects (`expo_insign/`, `nestjs_app/`, `web/`) are reference-only; coordinate with their owners before touching them.

## Build, Test, and Development Commands
Run `cd insign_flutter && flutter pub get` after dependency bumps or asset updates. Use `flutter analyze` for static checks and `dart format .` to enforce two-space indenting with trailing commas. Execute `flutter test` for the full suite or target modules such as `flutter test test/screens/login_screen_test.dart`. Validate flows locally with `flutter run -d <device>` after confirming targets via `flutter devices`.

## Coding Style & Naming Conventions
Rely on Flutter defaults: files use `snake_case.dart`, classes UpperCamelCase, members lowerCamelCase, and constants SCREAMING_SNAKE_CASE. Keep imports sorted by the formatter and avoid unused exports. Pull typography, spacing, and color tokens from `lib/theme/` rather than embedding raw values so that design tokens remain the single source of truth.

## Testing Guidelines
All specs rely on `package:flutter_test/flutter_test.dart` and should be grouped with descriptive `group()` names. Widget goldens live beside their subject in `test/screens/`; refresh intentional updates via `flutter test --update-goldens`. Run `flutter test --coverage` before merging and verify high-risk areas (auth, payments, provider mutations) for regression gaps.

## Commit & Pull Request Guidelines
Commits follow imperative subjects such as `Add contract detail screen` and should link issues (`Closes #123`) when applicable. PRs need a concise summary, the commands executed (`flutter analyze`, `flutter test`, device runs), and fresh screenshots or screen recordings for UI shifts. Document schema, environment, or release-impacting changes explicitly so QA can plan validation.

## Security & Configuration Tips
Never commit secrets, API keys, or keystores. Keep `.gitignore`, `pubspec.yaml`, and the contents of `insign_flutter/assets/` synchronized to avoid shipping stray files. Review Android and iOS builds on representative hardware whenever platform folders change, and note any config toggles in release notes.
