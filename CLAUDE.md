# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a monorepo for "인싸인 (Insign)", a digital contract management and e-signature platform. It contains:

1. **Flutter Mobile App** (`insign_flutter/`) - Primary Android/iOS/Web app for contract management
2. **NestJS Backend** (`nestjs_app/`) - REST API server and admin portal
3. **Web Frontend** (`web/`) - Static web assets served via nginx
4. **Nginx Configuration** (`in-sign.conf`) - Reverse proxy and routing configuration
5. **Expo Project** (`expo_insign/`) - Alternative React Native implementation (if present)

**Production URL**: `https://dev.in-sign.shop`
**Backend API**: `https://in-sign.shop/api` (proxied to port 8083)
**Admin Portal**: `https://in-sign.shop/adm` (EJS-based admin UI)
**UI Language**: Korean with English code/comments

## Flutter Mobile App (`insign_flutter/`)

**Application ID**: `app.insign`
**Minimum SDK**: Android API 21+ (Android 5.0)
**Target SDK**: API 35 (Android 15)
**주요 기능**: 전자 계약서 작성, 관리, 디지털 서명, 블록체인 기반 검증, Google/Kakao 소셜 로그인

### Technology Stack (Flutter App)

- **Framework**: Flutter (version managed via system installation)
- **Language**: Dart
- **Dart SDK**: >=3.3.0 <4.0.0
- **Current Version**: 1.0.4 (as defined in pubspec.yaml)
- **Platform targets**: Android, iOS (primary), Web, Desktop (secondary)
- **State Management**: BLoC/Cubit pattern with `flutter_bloc ^9.0.0`
- **Navigation**: `go_router ^14.0.0` with declarative routing
- **Authentication**: Google Sign-In, Kakao Login, Direct Login (email/password)
- **Key dependencies**:
  - `flutter_bloc ^9.0.0` - State management with Cubit pattern
  - `go_router ^14.0.0` - Declarative navigation
  - `http ^1.1.0` - API communication
  - `shared_preferences ^2.2.2` - Local storage for session tokens
  - `google_sign_in ^6.2.1` - Google OAuth
  - `kakao_flutter_sdk ^1.9.0` - Kakao login integration
  - `signature ^5.3.2` - Digital signature pad for touch-based signing
  - `pdf ^3.10.6` - PDF generation for contracts
  - `printing ^5.12.0` - PDF printing support
  - `file_picker ^6.1.1` - File selection for attachments
  - `google_fonts ^6.2.0` - Custom typography (Bariol font family)
  - `intl ^0.18.1` - Internationalization and date formatting
  - `just_audio ^0.9.39` - Audio playback (legacy, used for notifications)
  - `firebase_core ^2.30.1` - Firebase initialization
  - `firebase_messaging ^14.9.1` - Push notifications (FCM)
  - `flutter_local_notifications ^17.1.0` - Local notification display
  - `cached_network_image ^3.3.1` - Network image caching
  - `flutter_widget_from_html_core ^0.14.11` - HTML rendering in contracts

## NestJS Backend (`nestjs_app/`)

**Framework**: NestJS 11.x with TypeScript
**Port**: 8083 (proxied via nginx)
**Database**: MySQL (TypeORM)
**Admin Portal**: EJS templates at `/adm/*`
**Authentication**: Passport Local Strategy with sessions

### Key Features (Backend)

- **API Endpoints**: RESTful API for contracts, templates, users, authentication
- **Admin Portal**: Server-rendered EJS views for admin management
- **Document Generation**: DOCX templating with `docxtemplater`, PDF conversion with Puppeteer
- **File Uploads**: Multer for contract attachments
- **Push Notifications**: Firebase Admin SDK integration for FCM token management and message sending
- **Email**: Nodemailer for notifications
- **Swagger Documentation**: Available at `/docs` (auto-generated from DTOs and decorators)

### Backend Modules

- `auth/` - JWT/Local authentication
- `api-auth/` - API authentication endpoints (Google, Kakao)
- `users/` - User management
- `contracts/` - Contract CRUD operations
- `templates/` - Contract template management
- `inbox/` - Notification/message system
- `policies/` - Privacy policy and terms of service
- `push-tokens/` - FCM token registration
- `admin/` - Admin portal controllers
- `mail/` - Email service

### NestJS Development Commands

**Working Directory**: `/mnt/c/android_prj/nestjs_app/`

```bash
# Install dependencies
npm install

# Development server with hot reload
npm run start:dev

# Production build
npm run build

# Start production server
npm run start:prod

# Run tests
npm run test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage
npm run test:cov

# Run E2E tests
npm run test:e2e

# Lint code
npm run lint

# Format code
npm run format

# Migrate contract templates (custom script)
npm run migrate:templates
```

### Backend Configuration

Environment variables (`.env`):
```
PORT=8083
DB_HOST=localhost
DB_PORT=3306
DB_USERNAME=root
DB_PASSWORD=<password>
DB_NAME=insign
SESSION_SECRET=<secret>

# Google OAuth Client IDs (required for Google Sign-In)
GOOGLE_WEB_CLIENT_ID=723715287873-8jp38k93ksspp7jkeljv4v0jr2eobcb7.apps.googleusercontent.com
GOOGLE_ANDROID_CLIENT_ID=723715287873-04874jd2a3533h1nqc76anaj7hu5q0ni.apps.googleusercontent.com
# GOOGLE_EXPO_CLIENT_ID=<if using Expo>
# GOOGLE_IOS_CLIENT_ID=<if using iOS>

# Firebase Admin SDK (for push notifications)
# FIREBASE_SERVICE_ACCOUNT_KEY_PATH=path/to/service-account-key.json
```

Default admin credentials: `admin / admin1234` (auto-created on first run)

## Flutter Development Commands

**Working Directory**: All commands should be run from `/mnt/c/android_prj/insign_flutter/` or use `cd insign_flutter` first.

**Note**: This project is developed in WSL2 (Windows Subsystem for Linux) environment. Flutter commands work the same as native Linux.

**Quick Start Workflow**:
```bash
cd /mnt/c/android_prj/insign_flutter
flutter pub get              # Install dependencies
flutter analyze              # Check for issues
flutter run -d chrome        # Run on web browser
# OR
flutter run                  # Run on connected device/emulator
```

### Setup and Installation
```bash
# Get dependencies
flutter pub get

# Run the app (debug mode)
flutter run

# Run on specific device
flutter run -d <device-id>

# List available devices
flutter devices
```

### Code Quality
```bash
# Analyze code for issues
flutter analyze

# Format code
flutter format .

# Check for outdated dependencies
flutter pub outdated
```

### Testing
```bash
# Run all tests
flutter test

# Run a specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage

# Update golden files for widget tests
flutter test --update-goldens
```

### Build Commands
```bash
# Android builds
flutter build apk                    # Release APK
flutter build apk --debug            # Debug APK
flutter build appbundle              # App Bundle for Play Store

# iOS builds (macOS only)
flutter build ios
flutter build ipa

# Web build
flutter build web

# Clean build artifacts
flutter clean
```

## Deployment Architecture

### Nginx Reverse Proxy Configuration

**File**: `in-sign.conf`
**Domain**: `dev.in-sign.shop` (HTTPS with Let's Encrypt)

**Routing**:
- `/` → Flutter web build (static files from `/home/insign/web`)
- `/api/*` → NestJS backend (127.0.0.1:8083)
- `/adm/*` → Admin portal EJS views (NestJS)
- `/static/*` → Backend static resources (NestJS)

**Features**:
- TLS 1.2/1.3 with automatic HTTPS redirect
- Client max body size: 15MB (for file uploads)
- Static asset caching (1 year for immutable assets)
- SPA routing support (`try_files` fallback to `index.html`)
- Gzip compression for text/CSS/JS/JSON/WASM

### Development vs Production

**Development** (WSL2 local):
- Flutter: `flutter run` or `flutter run -d chrome`
- NestJS: `npm run start:dev` on port 8083
- Direct API access: `http://localhost:8083/api`

**Production**:
- Flutter: Built as static web assets (`flutter build web`)
- NestJS: PM2 process manager on port 8083
- Nginx proxies all traffic through HTTPS
- Domain: `https://dev.in-sign.shop`

## Flutter App Architecture

### Project Structure

```
insign_flutter/
├── lib/
│   ├── main.dart                    # Entry point with repository/cubit providers
│   ├── app.dart                     # App shell with bottom navigation
│   ├── core/                        # Shared utilities and configuration
│   │   ├── config/
│   │   │   └── api_config.dart      # API base URL and endpoints
│   │   ├── router/
│   │   │   └── app_router.dart      # GoRouter configuration
│   │   ├── theme/                   # App theme and styling
│   │   ├── widgets/                 # Reusable widgets (CustomAppBar, etc.)
│   │   ├── reusable/                # Shared utilities
│   │   └── constants.dart           # App constants (colors, etc.)
│   ├── features/                    # Feature modules (feature-based architecture)
│   │   ├── auth/                    # Authentication
│   │   │   ├── cubit/              # AuthCubit, AuthState
│   │   │   ├── services/           # Auth service implementations
│   │   │   └── view/               # Login screens
│   │   ├── home/                    # Home screen
│   │   ├── contracts/               # Contract list/details
│   │   ├── templates/               # Contract templates
│   │   ├── profile/                 # User profile
│   │   ├── settings/                # App settings
│   │   ├── podcast/                 # Notifications (legacy naming)
│   │   ├── chatbot/                 # AI chatbot
│   │   └── ...
│   ├── data/                        # Repository pattern implementation
│   │   ├── services/
│   │   │   ├── api_client.dart      # HTTP client wrapper
│   │   │   ├── session_service.dart # Token management
│   │   │   ├── google_auth_service.dart
│   │   │   └── kakao_auth_service.dart
│   │   ├── auth_repository.dart
│   │   ├── contract_repository.dart
│   │   ├── template_repository.dart
│   │   └── ...
│   ├── models/                      # Data models (User, Contract, Template, etc.)
│   ├── services/                    # App-level services
│   ├── utils/                       # Utility functions
│   └── widgets/                     # Global widgets (AppDrawer, etc.)
├── test/                            # Unit and widget tests
├── android/                         # Android platform code (app.insign)
├── ios/                             # iOS platform code
├── web/                             # Web platform code
├── assets/                          # Images and fonts (Bariol font family)
└── pubspec.yaml                     # Dependencies and project configuration
```

**Architecture Pattern**: Feature-based architecture with BLoC/Cubit for state management, Repository pattern for data layer, and dependency injection via providers.

**Key Architectural Decisions**:
- **State Management**: BLoC/Cubit pattern (states do NOT extend Equatable)
- **Navigation**: GoRouter with ShellRoute for persistent bottom navigation
- **API Layer**: Repository pattern with ApiClient wrapper
- **Authentication**: Session-based with token persistence via SharedPreferences
- **Routing**: Declarative routing with route parameters via `state.extra`

### App Initialization Sequence

The app follows a specific initialization sequence in `main.dart`:

1. **Flutter Bindings**: `WidgetsFlutterBinding.ensureInitialized()`
2. **Web URL Strategy**: `usePathUrlStrategy()` for clean URLs (web only)
3. **Kakao SDK**: `KakaoAuthService.initialize()` with native app key
4. **Back Button Service**: `BackButtonService.initialize(appRouter)` for Android navigation
5. **Firebase Core**: `Firebase.initializeApp()` with platform-specific options
6. **Push Notifications**: `PushNotificationService.initialize()` for FCM setup
7. **System UI**: Status bar styling (transparent with dark icons)
8. **App Launch**: `runApp(InsignApp())`

**Provider Hierarchy** (in `InsignApp` widget):
```
MultiRepositoryProvider (PodcastRepository, StockRepository, AudioPlayer)
  └── MultiBlocProvider (AuthCubit, OnboardingCubit, StockCubit, PodcastPlayerCubit, PodcastPrefsCubit)
      └── MaterialApp.router with GoRouter
          └── AppShell (ShellRoute with BottomNavigationBar)
```

**Initial Route Flow**:
1. App starts at `/splash` (4-second splash screen)
2. `AuthCubit.checkSession()` restores authentication if valid token exists
3. `OnboardingCubit.checkStatus()` checks if first-time setup completed
4. GoRouter redirect logic:
   - Not logged in → `/auth/login`
   - Logged in but onboarding incomplete → `/onboarding`
   - Logged in and onboarded → `/home`


### Application Flow
```
/splash (4 second splash screen)
    ↓
/onboarding (First-time user onboarding, skipped if completed)
    ↓
/auth/login (Login screen with Google/Kakao/Direct login options)
    ↓
/home (Home screen with bottom navigation)
    ├→ /contracts (Contracts list)
    │   ├→ /contracts/create (Create new contract)
    │   ├→ /contracts/:id (Contract details)
    │   └→ /contracts/:id/sign (Sign contract)
    ├→ /templates (Templates list)
    ├→ /inbox (Messages/Notifications - "podcast" feature)
    ├→ /profile (Profile and settings)
    │   └→ /profile/member-info (Edit user information)
    └→ /settings/* (Various settings screens)
        ├→ /settings (Main settings)
        ├→ /settings/notifications (Notification preferences)
        ├→ /privacy-policy (Privacy policy)
        └→ /terms-of-service (Terms of service)
```

**Route Guards**:
- `AuthCubit` checks session status on app start via `checkSession()`
- `OnboardingCubit` checks if first-time setup is complete
- Unauthenticated users redirected to `/auth/login`
- First-time users redirected to `/onboarding` after authentication

### Key Features

1. **Authentication**: Email/password login, Google Sign-In, Kakao Login with automatic session restoration
2. **Onboarding**: First-time user setup flow (tracked via `OnboardingCubit`)
3. **Contract Templates**: Pre-defined templates for common contract types (e.g., employment, rental, sales agreements)
4. **Contract Creation**: Form-based contract creation with dynamic fields and multi-step wizard
5. **Contract Management**: View, edit, delete contracts with status tracking (draft/pending/signed/completed)
6. **Digital Signatures**: Touch-based signature pad for mobile signing with `signature` package
7. **Token-based Signing**: Shareable links for remote signature collection via `/sign/:token` endpoint
8. **PDF Generation**: Contract PDF generation and printing with `pdf` and `printing` packages
9. **Push Notifications**: Firebase Cloud Messaging for contract updates and reminders
10. **Dashboard**: Statistics and recent activity overview on home screen
11. **Profile Management**: User settings, account information, and notification preferences

### State Management

- **Pattern**: BLoC/Cubit with `flutter_bloc`
- **Key Cubits**:
  - `AuthCubit` (`features/auth/cubit/`) - Authentication state (login, logout, session management)
  - `OnboardingCubit` (`features/onboarding/cubit/`) - First-time user setup tracking
  - `StockCubit` (`features/invest/cubit/`) - Legacy name, being refactored to ContractCubit
  - `PodcastPlayerCubit` (`features/podcast/cubit/`) - Notification/message player (legacy naming)
  - `PodcastPrefsCubit` (`features/podcast/cubit/`) - Notification preferences
- **States**: Use `copyWith` pattern, do NOT extend Equatable (this is a project-wide convention)
- **Dependency Injection**: `MultiRepositoryProvider` and `MultiBlocProvider` in `main.dart`
- **Session Management**:
  - Tokens persisted via SharedPreferences through `SessionService`
  - `AuthCubit.checkSession()` called on app start to restore authentication
  - Bearer tokens automatically injected into API requests via `ApiClient`

### API Integration

**Backend**: `https://in-sign.shop/api`

**Common Endpoints** (defined in `lib/core/config/api_config.dart`):
- `POST /auth/login` - Email/password authentication
- `POST /auth/register` - New user registration
- `POST /auth/google` - Google OAuth login
- `POST /auth/logout` - Logout and invalidate session
- `GET /templates` - Fetch contract templates
- `GET /contracts` - List user contracts
- `POST /contracts` - Create new contract
- `GET /contracts/:id` - Get contract details
- `PUT /contracts/:id` - Update contract
- `DELETE /contracts/:id` - Delete contract
- `POST /contracts/:id/sign` - Add signature to contract
- `GET /sign/:token` - Get contract for external signing (token-based, no auth required)
- `POST /fcm/token` - Register Firebase Cloud Messaging token for push notifications

**Implementation**:
- `ApiClient` wrapper in `lib/data/services/api_client.dart`
- Generic methods: `request<T>()`, `requestList<T>()`, `requestVoid()`
- Automatic Bearer token injection from `SessionService` for authenticated requests
- Korean error messages for user-facing errors
- Repository pattern abstracts API calls (see `lib/data/*_repository.dart`)
- HTTP client uses `package:http` with JSON encoding/decoding

**Key Repositories**:
- `AuthRepository` (`lib/data/auth_repository.dart`) - Authentication and registration
- `ContractRepository` (`lib/data/contract_repository.dart`) - Contract CRUD operations
- `TemplateRepository` (`lib/data/template_repository.dart`) - Template fetching
- `InboxRepository` (`lib/data/inbox_repository.dart`) - Notification/message management
- `PolicyRepository` (`lib/data/policy_repository.dart`) - Privacy policy and terms of service
- `PodcastRepository` (`lib/data/podcast_repository.dart`) - Legacy notification system
- `PortfolioRepository` (`lib/data/portfolio_repository.dart`) - Legacy from stock app migration
- `StockRepository` (`lib/data/stock_repository.dart`) - Legacy from stock app migration

### Core Services

**Authentication & Session**:
- `SessionService` (`lib/data/services/session_service.dart`) - Token persistence with SharedPreferences
  - Methods: `saveSession()`, `getSession()`, `clearSession()`, `hasValidSession()`
  - Stores: `accessToken`, `user` object, `expiresAt` timestamp
- `GoogleAuthService` (`lib/data/services/google_auth_service.dart`) - Google Sign-In wrapper
  - Platform-specific: Uses `google_sign_in` package with web/mobile detection
- `KakaoAuthService` (`lib/data/services/kakao_auth_service.dart`) - Kakao login integration
  - Methods: `initialize()`, `login()`, `logout()`, `isLoggedIn()`, `getUserInfo()`
  - Includes SHA-1 key hash generation utilities

**Storage & Preferences**:
- `OnboardingService` (`lib/data/services/onboarding_service.dart`) - Onboarding completion tracking
- `NotificationPreferencesService` (`lib/data/services/notification_preferences_service.dart`) - User notification settings

**Notifications**:
- `PushNotificationService` (`lib/services/push_notification_service.dart`) - Firebase Cloud Messaging
  - Methods: `initialize()`, `requestPermission()`, `getToken()`, `syncTokenWithBackend()`
  - Background handler: `firebaseMessagingBackgroundHandler()` at top-level
- `LocalNotificationService` (`lib/services/local_notification_service.dart`) - Local notification display

**App-Level Services**:
- `BackButtonService` (`lib/services/back_button_service.dart`) - Android back button handling
  - Initialized in `main.dart` with `appRouter` reference

## Important Notes

### Project Status

**Current State**: Active development with functional implementation
- ✅ Complete authentication system (Google, Kakao, Direct login with session restoration)
- ✅ Feature-based architecture established
- ✅ GoRouter navigation with ShellRoute for persistent bottom navigation
- ✅ BLoC/Cubit state management implemented
- ✅ Repository pattern with ApiClient wrapper
- ✅ Session management with SharedPreferences
- ✅ Onboarding flow for first-time users
- ✅ Template-based contract creation with multi-step wizard
- ✅ Digital signature capture with touch pad
- ✅ PDF generation and printing for contracts
- ✅ Firebase Cloud Messaging for push notifications
- ✅ Local and remote notification handling
- ⚠️ Legacy naming from previous migration (StockCubit → needs refactoring to ContractCubit)
- ⚠️ "Podcast" feature repurposed for notifications/messaging (consider renaming)
- ⚠️ Some legacy features remain from stock app (portfolio, auto_trading, invest, survey)
- ⚠️ MiniPlayer widget exists but currently hidden (`showMiniPlayer = false` in app.dart:51)

**Migration History**:
- Originally migrated from a stock/investment app (Quant - "시그널 픽")
- Package renamed: `kr.signalpick` → `app.insign`
- App name changed: "시그널 픽" → "인싸인"
- 2025-11-01: Template-based contract creation with dynamic form fields
- 2025-11-02: Additional updates (see `작업내역_2025-11-02.md`)
- Latest: Firebase push notifications integrated (2025-11-06)

### Code Conventions

**Flutter/Dart**:
- Korean UI text with English code/comments
- Feature-based file organization (`features/*/cubit/`, `features/*/view/`)
- Two-space indentation, trailing commas in multiline literals (enforced by `dart format`)
- File naming: `snake_case.dart`
- Classes: UpperCamelCase
- Members: lowerCamelCase
- Constants: SCREAMING_SNAKE_CASE
- Screens: `*_screen.dart`
- Cubits: `*_cubit.dart` with states (non-Equatable, use `copyWith`)
- Models: Singular nouns with `fromJson()` factories
- Services: `*_service.dart`
- Repositories: `*_repository.dart`
- Centralize theme tokens (colors, typography, spacing) in `lib/core/theme/`

**NestJS/TypeScript**:
- Controllers: `*.controller.ts`
- Services: `*.service.ts`
- DTOs: `*.dto.ts`
- Entities: `*.entity.ts`
- Use ESLint and Prettier for code formatting
- Korean UI text for admin portal, English for code/comments

### Platform Configuration

**Android**:
- Package: `app.insign`
- Namespace: `app.insign` (in `build.gradle`)
- minSdkVersion: 21 (Android 5.0 Lollipop - required by Kakao SDK)
- targetSdkVersion: Flutter default (latest)
- multiDex enabled (required for Kakao SDK and Firebase)
- Google Services configured: `android/app/google-services.json` (for Firebase and Google Sign-In)
- Keystore: Uses release keystore for both debug and release builds (SHA-1 consistency)
- MainActivity: `android/app/src/main/kotlin/app/insign/MainActivity.kt`

**iOS**:
- Bundle ID configured in Xcode project
- Display Name: "인싸인"
- Bundle Name: "insign"
- Google/Kakao URL schemes in `ios/Runner/Info.plist`
- GIDClientID configured for Google Sign-In
- See platform-specific documentation in `insign_flutter/`

**Web**:
- Title: "인싸인" (in `web/index.html`)
- Google Sign-In: Meta tag with client ID in `web/index.html`
- Path URL strategy enabled (no hash routing)
- Firebase configuration in `web/index.html`

**Firebase Setup**:
- Project: `insign-69997` (Project Number: `723715287873`)
- `firebase_options.dart` auto-generated with platform-specific configuration
- Push notifications enabled via FCM
- Background message handler: `firebaseMessagingBackgroundHandler` in `main.dart`
- Google Services: `android/app/google-services.json`

**Authentication Setup**:
- Google OAuth Web Client ID: `723715287873-8jp38k93ksspp7jkeljv4v0jr2eobcb7.apps.googleusercontent.com`
- Google OAuth Android Client ID: `723715287873-04874jd2a3533h1nqc76anaj7hu5q0ni.apps.googleusercontent.com`
- Firebase Project: `insign-69997` (Project Number: `723715287873`)
- Kakao: See `insign_flutter/KAKAO_SETUP.md` for detailed setup
- Google OAuth: See `insign_flutter/GOOGLE_OAUTH_SETUP.md`
- Android Keystore: See `insign_flutter/ANDROID_KEYSTORE_SETUP.md`
- SHA-1 key hash required for both Google OAuth and Kakao login

## Testing

**Flutter Tests** (in `insign_flutter/`):
- Test files in `test/` directory (mirror structure of `lib/`)
- Run all tests: `flutter test`
- Run specific test: `flutter test test/widget_test.dart`
- Run with coverage: `flutter test --coverage`
- Update golden files: `flutter test --update-goldens`
- Widget testing with `WidgetTester` for UI components
- Integration tests can be added to `integration_test/` directory
- Basic tests reference `InsignApp` class
- Use `group()` to organize related test cases

**NestJS Tests** (in `nestjs_app/`):
- Unit tests: `npm run test`
- Watch mode: `npm run test:watch`
- Coverage: `npm run test:cov`
- E2E tests: `npm run test:e2e`
- Test files: `*.spec.ts` (unit) and `*.e2e-spec.ts` (E2E)
- Jest configuration in `package.json`

## Adding New Features

### Adding a New Screen

1. **Create feature directory**: `insign_flutter/lib/features/feature_name/`
2. **Add cubit if stateful**: `lib/features/feature_name/cubit/feature_cubit.dart`
3. **Create view**: `lib/features/feature_name/view/feature_screen.dart`
4. **Add route** in `lib/core/router/app_router.dart`:
   - Shell routes (with bottom nav): Add inside `ShellRoute.routes`
   - Full-screen routes: Add as top-level `GoRoute`
   - Use `NoTransitionPage` for bottom nav screens
   - Pass parameters via `state.extra` as `Map<String, dynamic>`
5. **Register cubit** in `main.dart` if needed globally (in `MultiBlocProvider`)
6. **Update** `lib/app.dart` if adding to bottom navigation

### Adding a New Repository

1. Create `lib/data/feature_repository.dart`
2. Add methods using `ApiClient.request()` or `ApiClient.requestList()`
3. Create corresponding model in `lib/models/` with `fromJson()` factory
4. Register in `main.dart` via `RepositoryProvider` if needed globally
5. Inject into Cubit via constructor

### Adding API Endpoints

1. Add endpoint constant to `lib/core/config/api_config.dart`
2. Create/update repository method in `lib/data/`
3. Use `ApiClient.request<T>()` with `fromJson` callback
4. Handle errors with try-catch in Cubit
5. Korean error messages handled automatically by ApiClient

## Troubleshooting

**Build Errors**:
- Run `flutter clean` then `flutter pub get`
- Check `pubspec.yaml` for version conflicts
- Ensure Android SDK and Xcode (iOS) are properly configured
- For Android builds, ensure `google-services.json` exists in `android/app/`
- Windows/WSL: If `flutter format` fails with `bash\r` error, use Linux subsystem or Git Bash
- MultiDex issues: Already enabled in `android/app/build.gradle`, but check Gradle sync

**Authentication Issues**:
- Verify Google Services configuration: `android/app/google-services.json`
- Check OAuth client IDs in Google Cloud Console match those in code
- For Kakao: Follow `insign_flutter/KAKAO_SETUP.md` and verify SHA-1 key hash
- For Google: See `insign_flutter/GOOGLE_OAUTH_SETUP.md` and verify SHA-1 certificate fingerprint
- Debug keystore: Both debug and release use same keystore (see `key.properties` setup)
- Session not restoring: Check `SessionService` has valid token in SharedPreferences

**State Not Updating**:
- Ensure Cubit is properly registered in provider tree (`main.dart`)
- Check if `emit()` is called in Cubit methods
- Verify `BlocBuilder` or `BlocListener` is used correctly in UI
- Remember: States do NOT extend Equatable in this project (use `copyWith` pattern)
- For route state: Ensure `state.extra` is properly passed through GoRouter

**Push Notifications Not Working**:
- Check Firebase configuration in `google-services.json` and `firebase_options.dart`
- Verify FCM token is being generated and registered with backend
- For Android: Check notification permissions in system settings
- For iOS: Check notification permissions in Info.plist
- Background handler: Ensure `firebaseMessagingBackgroundHandler` is properly decorated with `@pragma('vm:entry-point')`

**Development Environment (WSL2)**:
- This project is developed in WSL2 (Windows Subsystem for Linux)
- Working directory: `/mnt/c/android_prj/` (root) or `/mnt/c/android_prj/insign_flutter/` (Flutter)
- Flutter commands should be run from `insign_flutter/` directory
- NestJS commands should be run from `nestjs_app/` directory
- Note: Some Flutter commands may encounter `bash\r` errors in WSL2 - use the Linux subsystem directly if this occurs
- Android SDK path typically: `/mnt/c/sdk/` or configure via `ANDROID_SDK_ROOT`
- If Flutter is not found, check installation path (commonly `/usr/local/flutter/bin/` or `/mnt/c/sdk/flutter/bin/`)

## Working with Multiple Projects

### When to work in each directory

**`insign_flutter/`** - Work here for:
- Mobile app features (Android/iOS)
- Flutter web client
- State management (Cubits)
- UI components and screens
- Client-side routing
- Mobile-specific features (camera, notifications, signature pad)

**`nestjs_app/`** - Work here for:
- REST API endpoints
- Database schema and migrations
- Backend business logic
- Admin portal features
- Document generation (DOCX/PDF)
- Email notifications
- Server-side authentication

**Root directory** - For:
- Nginx configuration updates
- Repository-wide documentation
- Deployment scripts
- Work history tracking

### Common Cross-Project Workflows

**Adding a new API endpoint**:
1. Create endpoint in `nestjs_app/src/*/` (controller + service + DTO)
2. Update Flutter repository in `insign_flutter/lib/data/`
3. Update API config in `insign_flutter/lib/core/config/api_config.dart`
4. Test locally: NestJS on :8083, Flutter calls `http://localhost:8083/api`

**Adding a new feature**:
1. Design data model in NestJS (entity + migrations)
2. Create API endpoints in NestJS
3. Create Flutter repository and model
4. Implement UI in Flutter (cubit + screen)
5. Update routing in `app_router.dart`

**Deploying updates**:
1. Build Flutter web: `cd insign_flutter && flutter build web`
2. Copy build to server: `/home/insign/web`
3. Restart NestJS backend (if API changed)
4. Nginx automatically serves updated static files

## Additional Documentation

All documentation files are located in `insign_flutter/` unless otherwise noted:

**Flutter Setup Guides** (in `insign_flutter/`):
- `CLAUDE.md` - Detailed Flutter architecture and implementation guide (also in project root)
- `FLUTTER_INSTALLATION.md` - Flutter installation guide for development environment
- `KAKAO_SETUP.md` - Kakao login integration setup with SHA-1 key hash generation
- `GOOGLE_OAUTH_SETUP.md` - Google OAuth configuration and troubleshooting
- `ANDROID_KEYSTORE_SETUP.md` - Android signing keystore setup and management
- `SHA1_SETUP_GUIDE.md` - SHA-1 fingerprint setup for authentication providers
- `KEYSTORE_INFO.md` - Keystore information and credentials

**Flutter Configuration Guides** (in `insign_flutter/`):
- `FLUTTER_WEB_FIXED.md` - Web platform fixes and configuration
- `INDEX_HTML_FIXED.md` - Web index.html configuration for Firebase and Google Sign-In
- `PORT_MANAGEMENT.md` - Development server port management
- `PLAY_STORE_DEPLOYMENT.md` - Google Play Store deployment guide
- `PLAY_CONSOLE_RELEASE_NOTES.md` - Release notes templates
- `DEBUG_SYMBOLS_GUIDE.md` - Debug symbol upload guide
- `API35_UPDATE_CHANGELOG.md` - Android API 35 update details
- `KEYSTORE_BACKUP_GUIDE.md` - Keystore backup instructions

**Backend Documentation** (in `nestjs_app/`):
- `README.md` - NestJS backend quick start guide
- `MIGRATION_GUIDE.md` - Database migration instructions

**Repository-wide** (in root `/mnt/c/android_prj/`):
- `AGENTS.md` - Repository guidelines and coding standards
- `in-sign.conf` - Nginx reverse proxy configuration
- `작업내역_2025-11-01.md` - Initial migration work (Quant → Insign)
- `작업내역_2025-11-01_2차.md` - Second phase migration updates
- `작업내역_2025-11-01_3차.md` - Template creation flow implementation
- `작업내역_2025-11-02.md` - Additional updates and fixes
- `작업내역_2025-11-07_PlayStore배포준비.md` - Play Store deployment preparation

## Best Practices

### Commit Messages
- Use imperative mood (e.g., "Add contract detail screen", not "Added" or "Adds")
- Reference issues with `Closes #123` or `Fixes #456` where applicable
- Keep first line under 50 characters, detailed description after blank line

### Pull Requests
- Summarize scope and changes in PR description
- List validation commands run (`flutter analyze`, `flutter test`, `npm run test`)
- Attach screenshots/recordings for UI changes
- Call out impacts: schema changes, migrations, environment variables
- Ensure all tests pass before requesting review

### Security
- Never commit keystores, OAuth secrets, service accounts, or API keys
- Document required environment variables in README or .env.example
- Keep platform-specific secrets in `android/` or `ios/` gitignored files
- Use environment variables for all sensitive configuration
