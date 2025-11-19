# Repository Guidelines

## Project Structure & Module Organization
- Primary Flutter client lives in `insign_flutter/`. Place production code in `lib/` and group by feature: `screens/`, `providers/`, `services/`, etc.
- Mirror every `lib/` file with a spec in `insign_flutter/test/` (e.g., `lib/providers/user_provider.dart` ↔ `test/providers/user_provider_test.dart`).
- Store shared imagery, fonts, and Lottie files under `insign_flutter/assets/` and register paths in `insign_flutter/pubspec.yaml` to avoid bundle misses.
- Treat `expo_insign/`, `nestjs_app/`, and `web/` as legacy areas—coordinate with owners before edits.

## Build, Test, and Development Commands
- `cd insign_flutter && flutter pub get` — refresh dependencies after `pubspec.yaml` changes.
- `flutter analyze` — enforce lints; run before pushing.
- `dart format .` — apply two-space indentation and trailing commas.
- `flutter test` or `flutter test test/screens/login_screen_test.dart` — run the full suite or a focused spec; add `--update-goldens` only when intentionally regenerating visuals.
- `flutter run -d <device-id>` after `flutter devices` — manual verification on a chosen device/emulator.

## Coding Style & Naming Conventions
- Follow Flutter defaults: two-space indents, trailing commas in multiline literals, and formatter-managed import ordering.
- File names: `snake_case.dart`; classes: UpperCamelCase; members: lowerCamelCase; shared constants: SCREAMING_SNAKE_CASE.
- Reuse tokens from `lib/theme/` instead of hard-coding colors/spacing.

## Testing Guidelines
- Use `package:flutter_test/flutter_test.dart`; group related cases with `group('description', ...)` for readability.
- Keep tests structure-aligned with production; place golden images beside their widgets under `test/screens/`.
- Before PRs, run `flutter test --coverage`, review the HTML report, and shore up auth, checkout, provider mutations, and I/O-driven services.

## Commit & Pull Request Guidelines
- Commit titles are imperative (e.g., `Add contract detail screen`); reference issues with `Closes #123` when relevant.
- PRs should summarize scope, list validation commands (`flutter analyze`, `flutter test`, device runs), and attach screenshots/videos for UI-facing changes.
- Call out schema or env-var changes explicitly; include rollout notes when platform tweaks touch `android/` or `ios/`. Wait for lint/test greenlights before requesting review.

## Security & Configuration Tips
- Never commit secrets (keystores, OAuth keys, service accounts); document required env vars in `README.md` or a secure vault.
- Keep `.gitignore` and `pubspec.yaml` aligned with asset updates so Flutter bundles the intended files.
- Verify platform-specific edits on representative Android and iOS devices/emulators before merging.
