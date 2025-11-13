# Repository Guidelines

## Project Structure & Module Organization
The primary Flutter client resides in `insign_flutter/`; place production code under `lib/` and group features by folders such as `screens/`, `providers/`, and `services/` for predictable ownership. Every file in `lib/` should have a mirrored spec under `insign_flutter/test/` (e.g., `lib/providers/user_provider.dart` ↔ `test/providers/user_provider_test.dart`). Keep shared imagery, fonts, and Lottie files inside `insign_flutter/assets/` and register each asset path in `insign_flutter/pubspec.yaml` to avoid runtime bundle misses; coordinate with legacy owners before touching `expo_insign/`, `nestjs_app/`, or `web/`.

## Build, Test, and Development Commands
Run `cd insign_flutter && flutter pub get` whenever `pubspec.yaml` changes to refresh dependencies. `flutter analyze` blocks lint regressions, while `dart format .` enforces two-space indentation and trailing commas—run both before pushing. Use `flutter test` for the suite, `flutter test test/screens/login_screen_test.dart` for a focused spec, and pass `--update-goldens` only when intentionally regenerating visuals; launch manual sessions with `flutter run -d <device-id>` after confirming the device via `flutter devices`.

## Coding Style & Naming Conventions
Adopt Flutter defaults: two-space indents, trailing commas in multiline literals, and formatter-managed import ordering. Name files with `snake_case.dart`, classes with UpperCamelCase, members with lowerCamelCase, and shared constants with SCREAMING_SNAKE_CASE. Reuse style tokens from `lib/theme/` instead of scattering color or spacing literals to keep theming centralized.

## Testing Guidelines
Author widget and provider specs with `package:flutter_test/flutter_test.dart`, grouping related cases via `group('description', ...)` for readability. Mirror production structure so new flows automatically gain a predictable test location, and keep golden images beside their widgets under `test/screens/`. Before opening a PR, run `flutter test --coverage`, review the HTML report, and plug gaps around auth, checkout, provider mutations, and any service talking to external I/O.

## Commit & Pull Request Guidelines
Write imperative commit titles such as `Add contract detail screen`, referencing issues with `Closes #123` where relevant. PR descriptions should summarize scope, list validation commands (`flutter analyze`, `flutter test`, device runs), and attach screenshots or videos for UI-facing work. Call out schema or env-var changes explicitly, include rollout notes when platform tweaks affect `android/` or `ios/`, and wait for lint/test greenlights before requesting review.

## Security & Configuration Tips
Never commit secrets (keystores, OAuth keys, service accounts); document required environment variables in `README.md` or secure vaults. Platform-specific edits belong in their respective `android/` or `ios/` directories, and changes must be verified on representative devices/emulators before merging. When assets shift, ensure `.gitignore` and `pubspec.yaml` stay aligned so Flutter bundles the intended files.
