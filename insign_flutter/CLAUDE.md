# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"인싸인 (Insign)" is a digital contract management and e-signature Flutter application that provides contract creation, management, digital signature capabilities, and blockchain-based verification.

**Application ID**: `app.insign`
**Minimum SDK**: Android API 21+ (Android 5.0)
**UI Language**: Korean with English code/comments
**Backend API**: `https://in-sign.shop`

## Development Commands

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

# Run tests
flutter test

# Run a specific test file
flutter test test/widget_test.dart
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

## Architecture

### Feature-Based Structure

The app follows a feature-based architecture with clear separation of concerns:

```
lib/
├── core/                    # Shared utilities and configurations
│   ├── config/             # API configuration (api_config.dart)
│   ├── router/             # GoRouter configuration (app_router.dart)
│   ├── theme/              # App theme and styling
│   ├── widgets/            # Reusable widgets (CustomAppBar, etc.)
│   ├── reusable/           # Shared utilities and widgets
│   └── constants.dart      # App constants (primaryColor, etc.)
├── features/               # Feature modules
│   ├── splash/             # Splash screen
│   ├── home/               # Home screen and account registration flows
│   ├── auth/               # Authentication (Google, Kakao login)
│   │   ├── cubit/         # AuthCubit, AuthState
│   │   ├── services/      # Auth service implementations
│   │   └── view/          # Login screens
│   ├── contracts/          # Contract list/browsing
│   ├── templates/          # Contract templates
│   ├── profile/            # User profile
│   ├── settings/           # App settings and legal pages
│   ├── podcast/            # Notifications (legacy name, used for messaging)
│   │   ├── cubit/         # PodcastPlayerCubit, PodcastPrefsCubit
│   │   ├── view/          # Notification screens
│   │   └── widgets/       # MiniPlayer widget
│   └── chatbot/            # AI chatbot
├── data/                   # Repository pattern implementation
│   ├── services/          # External service integrations
│   │   ├── api_client.dart        # HTTP client wrapper
│   │   ├── session_service.dart   # Session/token management
│   │   ├── google_auth_service.dart
│   │   └── kakao_auth_service.dart
│   ├── auth_repository.dart
│   ├── contract_repository.dart
│   ├── template_repository.dart
│   ├── podcast_repository.dart
│   └── portfolio_repository.dart
├── models/                 # Data models
│   ├── user.dart          # User, AuthResponse
│   ├── contract.dart      # Contract model
│   ├── template.dart      # Contract template
│   ├── stock.dart         # Legacy (to be refactored)
│   └── ...
├── services/              # App-level services (BackButtonService)
├── utils/                 # Utility functions
└── widgets/               # Global widgets (AppDrawer)
```

### State Management

- **BLoC/Cubit Pattern**: Uses `flutter_bloc` for state management
  - Each feature has its own Cubit (AuthCubit, StockCubit, PodcastPlayerCubit, etc.)
  - States do NOT extend Equatable (copyWith pattern used instead)
  - Repository injection through `RepositoryProvider` in main.dart
- **Provider Pattern**: Dependency injection using `MultiRepositoryProvider` and `MultiBlocProvider`
- **Global State**: `AuthCubit` manages authentication state across the app

### Navigation Architecture

- **GoRouter**: Declarative routing with `ShellRoute` for main app shell
- **Bottom Navigation**: 5-tab navigation (홈, 계약, 템플릿, 메시지함, 마이)
- **App Shell** (`lib/app.dart`): Provides consistent BottomNavigationBar
  - Tabs: Home, Contracts, Templates, Inbox (Messages), Profile
  - Conditionally shows MiniPlayer above BottomNavigationBar
- **Route Types**:
  1. **Shell Routes**: Main navigation screens with bottom bar (`/home`, `/contracts`, `/templates`, `/inbox`, `/profile`)
  2. **Full Screen**: Modal screens without navigation (`/auth/login`, `/settings`, `/privacy-policy`, `/terms-of-service`)
  3. **Overlay**: Full-screen dialogs (`/now_playing` for full-screen views)
- **Route Parameters**: Passed via `state.extra` as `Map<String, dynamic>`
- **Initial Route**: `/splash` (splash screen shows for 4 seconds before navigating to home)

### Authentication System

**Providers**: Google Sign-In, Kakao Login, and Direct Login (email/password)

**Core Components**:
- `AuthCubit` (`lib/features/auth/cubit/auth_cubit.dart`): Manages authentication state
  - `checkSession()`: Auto-login on app start if session exists
  - `login()`: Email/password login
  - `register()`: Account registration
  - `loginWithGoogle()`: Google OAuth flow
  - `logout()`: Clears session and signs out
- `AuthRepository` (`lib/data/auth_repository.dart`): API calls for auth
- `SessionService` (`lib/data/services/session_service.dart`): Token persistence using SharedPreferences
- `GoogleAuthService` (`lib/data/services/google_auth_service.dart`): Google Sign-In wrapper
- `KakaoAuthService` (`lib/data/services/kakao_auth_service.dart`): Kakao SDK wrapper

**Session Flow**:
1. User logs in → Receive `AuthResponse` (user + accessToken + expiresIn)
2. Token saved to SharedPreferences via `SessionService`
3. Token automatically included in API requests via `ApiClient`
4. On app restart, `checkSession()` restores user state

**Google OAuth Setup**:
- Web Client ID: `498213338840-q7v8crk85mstarb04bo5iusj6f022dng.apps.googleusercontent.com`
- Android Client ID: `498213338840-5tuq94mf9ktt92speec4871vsi7rb22v.apps.googleusercontent.com`
- Project ID: `insign-prj`
- Configuration files: `android/app/google-services.json`, `ios/Runner/Info.plist`, `web/index.html`

**Kakao Setup**:
- App key configured in `KakaoAuthService`
- Android: minSdkVersion 21, multiDex enabled
- See `KAKAO_SETUP.md` for detailed setup instructions
- Key hash generation: Use `get_keyhash.ps1` script

### API Integration

**Configuration**: `lib/core/config/api_config.dart`
- Base URL: `https://in-sign.shop`
- API Endpoint: `https://in-sign.shop/api`

**Client**: `lib/data/services/api_client.dart`
- Generic HTTP wrapper with error handling
- Methods: `request<T>()`, `requestList<T>()`, `requestVoid()`
- Automatically adds Bearer token from session
- Korean error messages

**Endpoints**:
- `POST /auth/register` - User registration
- `POST /auth/login` - Email/password login
- `POST /auth/google` - Google OAuth login
- `POST /auth/logout` - Logout
- `GET /contracts` - List contracts
- `POST /contracts` - Create contract
- `GET /templates` - List templates

### Data Models

Key models all include `fromJson()` factories for API deserialization:

- **User** (`lib/models/user.dart`): id, email, displayName, provider, avatarUrl, lastLoginAt
- **AuthResponse**: user, accessToken, expiresIn
- **Contract** (`lib/models/contract.dart`): Full contract data with client, performer, signatures, metadata
- **Template** (`lib/models/template.dart`): Contract template structure
- **StoredSession** (`lib/data/services/session_service.dart`): accessToken, user, expiresAt

## Key Dependencies

### Core
- `flutter_bloc: ^9.0.0` - State management with Cubit pattern
- `go_router: ^14.0.0` - Declarative navigation and routing
- `equatable: ^2.0.5` - Value equality (minimal usage)

### Authentication & Storage
- `google_sign_in: ^6.2.1` - Google OAuth authentication
- `kakao_flutter_sdk: ^1.9.0` - Kakao login integration
- `crypto: ^3.0.3` - Cryptographic utilities
- `shared_preferences: ^2.2.2` - Local key-value storage for session

### Networking
- `http: ^1.1.0` - HTTP requests

### Audio (Legacy - used for notifications)
- `just_audio: ^0.9.39` - Audio playback
- `audio_session: ^0.1.16` - Audio session management
- `rxdart: ^0.27.7` - Reactive streams

### UI & Utility
- `cached_network_image: ^3.3.1` - Network image caching
- `intl: ^0.19.0` - Internationalization and formatting
- `google_fonts: ^6.2.0` - Custom typography
- `fluttertoast: ^8.2.4` - Toast notifications
- `universal_io: ^2.2.2` - Cross-platform IO
- `cupertino_icons: ^1.0.6` - iOS-style icons

## Code Conventions

### General
- Korean UI text with English code/comments
- Feature-based file organization
- Prefer Cubit over BLoC for simpler state management
- Repository pattern for data layer abstraction
- Dependency injection via constructors
- Strong typing with explicit models

### Naming
- Screens: `*_screen.dart` (e.g., `home_screen.dart`)
- Widgets: `*_widget.dart` or descriptive names (e.g., `mini_player.dart`)
- Cubits: `*_cubit.dart` with corresponding state classes (non-Equatable)
- Models: Singular nouns (e.g., `contract.dart`, `user.dart`)
- Services: `*_service.dart` (e.g., `kakao_auth_service.dart`)
- Repositories: `*_repository.dart`

### File Structure Pattern
Each feature should follow this pattern:
```
feature_name/
├── cubit/           # State management
├── view/            # Screens
├── widgets/         # Feature-specific widgets (optional)
└── services/        # Feature-specific services (optional)
```

## Testing

### Current State
- Basic widget tests in `test/widget_test.dart`
- Tests reference `InsignApp` class

### Running Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage
```

## Platform-Specific Configuration

### Android
- **Application ID**: `app.insign`
- **Package Name**: `app.insign`
- **Minimum SDK**: 21 (Android 5.0)
- **Target SDK**: Latest Flutter default
- **MultiDex**: Enabled (required for Kakao SDK)
- **Build Config**: `android/app/build.gradle`
- **Google Services**: `android/app/google-services.json` (for Google Sign-In)
- **MainActivity**: `android/app/src/main/kotlin/app/insign/MainActivity.kt`
- **Namespace**: `app.insign`

### iOS
- **Bundle ID**: Configure in Xcode
- **Info.plist** (`ios/Runner/Info.plist`):
  - CFBundleDisplayName: "인싸인"
  - CFBundleName: "insign"
  - Google Sign-In URL Scheme
  - GIDClientID
  - Kakao URL Scheme (if using Kakao)
- See `KAKAO_SETUP.md` for complete setup

### Web
- **Title**: "인싸인" (`web/index.html`)
- **Google Sign-In**: Meta tag with client ID in `web/index.html`
- **Manifest**: `web/manifest.json`

## Adding New Features

### Adding a New Screen
1. Create feature directory: `lib/features/feature_name/`
2. Add cubit if stateful: `lib/features/feature_name/cubit/feature_cubit.dart`
3. Create view: `lib/features/feature_name/view/feature_screen.dart`
4. Add route in `lib/core/router/app_router.dart`
5. Register cubit in `main.dart` if needed globally (in `MultiBlocProvider`)
6. Update `lib/app.dart` if adding to bottom navigation

### Adding a New Route
1. Edit `lib/core/router/app_router.dart`
2. For shell routes (with bottom nav): Add inside `ShellRoute.routes`
3. For full-screen routes: Add as top-level `GoRoute`
4. Use `NoTransitionPage` for bottom nav screens to prevent animation
5. Pass parameters via `state.extra` as `Map<String, dynamic>`

### Adding a New Repository
1. Create `lib/data/feature_repository.dart`
2. Add methods that use `ApiClient.request()` or `ApiClient.requestList()`
3. Create corresponding model in `lib/models/`
4. Register in `main.dart` via `RepositoryProvider` if needed globally
5. Inject into Cubit via constructor

### Adding API Endpoints
1. Add endpoint constant to `lib/core/config/api_config.dart`
2. Create/update repository method in `lib/data/`
3. Use `ApiClient.request()` with `fromJson` callback
4. Handle errors with try-catch in Cubit

## Migration Notes

This project was migrated from a stock/investment app (Quant) to a digital contract management app (Insign). Some legacy references may still exist:

- `StockCubit` should eventually be renamed to `ContractCubit`
- `stock_repository.dart` exists alongside `contract_repository.dart`
- "Podcast" features are repurposed for notifications/messaging
- Some UI labels were changed from investment-related to contract-related terms

**Recent Migration** (2025-11-01):
- Project renamed from `quant` to `insign`
- Package name changed from `kr.signalpick` to `app.insign`
- App name changed from "시그널 픽" to "인싸인"
- Full authentication infrastructure implemented (direct login + Google OAuth)
- API client and session management added
- See `작업내역_2025-11-01.md` for complete migration details

## Additional Documentation

- `KAKAO_SETUP.md`: Kakao login setup guide
- `작업내역_2025-11-01.md`: Recent work history and migration details
- `AGENTS.md`: Agent configuration (if applicable)
