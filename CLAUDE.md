# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

"인싸인 (Insign)" is a digital contract management and e-signature platform with a Flutter mobile/web app and NestJS backend API.

**Production**: `https://dev.in-sign.shop`
**API**: `https://in-sign.shop/api` (port 8083, proxied via nginx)
**Environment**: Development in WSL2 at `/home/insign` (previously `/mnt/c/android_prj/`)
**Language**: Korean UI, English code/comments

### Directory Structure

```
/home/insign/
├── insign_flutter/          # Flutter app (Android/iOS/Web)
├── nestjs_app/              # NestJS backend API + admin portal
├── web/                     # Static web assets (production build output)
├── in-sign.conf            # Nginx reverse proxy config
└── src/                    # Legacy/unused
```

## Development Commands

### Flutter (`insign_flutter/`)

```bash
# Setup
flutter pub get
flutter analyze

# Development
flutter run                  # Auto-detects device
flutter run -d chrome        # Web browser
flutter run -d <device-id>   # Specific device

# Testing
flutter test
flutter test test/widget_test.dart
flutter test --coverage

# Build
flutter build apk            # Android release
flutter build appbundle      # Play Store bundle
flutter build web            # Web production build
flutter clean                # Clear build cache
```

### NestJS (`nestjs_app/`)

```bash
# Setup
npm install

# Development
npm run start:dev            # Hot reload on :8083
npm run start:debug          # Debug mode with --watch

# Production
npm run build
npm run start:prod

# Testing
npm run test
npm run test:watch
npm run test:cov
npm run test:e2e

# Code quality
npm run lint
npm run format

# Database migration & encryption scripts
npm run migrate:templates                    # Migrate contract templates
npm run migrate:alter-schema                 # Alter schema for encryption
npm run migrate:alter-schema-all             # Alter schema for all contacts
npm run migrate:alter-users-email            # Alter users email encryption
npm run migrate:alter-contract-mail-logs     # Alter contract mail logs
npm run migrate:encrypt-contracts            # Encrypt existing contracts
npm run migrate:encrypt-all-personal-data    # Encrypt all personal data
npm run migrate:encrypt-user-emails          # Encrypt user emails
npm run migrate:encrypt-contract-mail-logs   # Encrypt contract mail logs

# Utility scripts
npm run check:encryption     # Verify encryption status
npm run check:user           # Check specific user
npm run list:users           # List all users
npm run verify:password      # Verify user password
npm run reset:password       # Reset user password
```

## Architecture

### Flutter App Architecture

**Pattern**: Feature-based architecture with BLoC/Cubit state management, Repository pattern for data, dependency injection via providers.

**Critical architectural decisions**:
- **States do NOT extend Equatable** (use `copyWith` pattern instead)
- **Route parameters** passed via `state.extra` as `Map<String, dynamic>` (not URL params)
- **Session management**: Bearer tokens auto-injected into API calls via `ApiClient`
- **Bottom navigation**: Persistent via `ShellRoute` with 5 tabs

```
lib/
├── main.dart                 # App initialization sequence (see below)
├── app.dart                  # App shell with BottomNavigationBar
├── core/
│   ├── config/api_config.dart     # API endpoints
│   ├── router/app_router.dart     # GoRouter configuration
│   ├── theme/                     # Centralized theme tokens
│   └── widgets/                   # Reusable widgets
├── features/                      # Feature modules
│   ├── auth/
│   │   ├── cubit/                # AuthCubit, AuthState
│   │   ├── services/             # GoogleAuthService, KakaoAuthService
│   │   └── view/                 # Login screens
│   ├── contracts/                # Contract list/details
│   ├── templates/                # Contract templates
│   ├── inbox/                    # Notifications/messages
│   └── profile/                  # User profile
├── data/                         # Repository pattern
│   ├── services/
│   │   ├── api_client.dart       # HTTP wrapper with auto-auth
│   │   └── session_service.dart  # Token persistence (SharedPreferences)
│   ├── auth_repository.dart
│   ├── contract_repository.dart
│   └── template_repository.dart
├── models/                       # Data models with fromJson()
└── services/                     # App-level services
    ├── push_notification_service.dart
    └── back_button_service.dart
```

### App Initialization Sequence (main.dart)

Order matters - this is the exact initialization flow:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `usePathUrlStrategy()` (web only - clean URLs)
3. `KakaoAuthService.initialize()` (Kakao SDK)
4. `BackButtonService.initialize(appRouter)` (Android back button)
5. `Firebase.initializeApp()` (Firebase Core)
6. `PushNotificationService.initialize()` (FCM setup)
7. System UI styling (status bar)
8. `runApp(InsignApp())`

Provider hierarchy:
```
MultiRepositoryProvider (PodcastRepository, StockRepository, AudioPlayer)
  └── MultiBlocProvider (AuthCubit, OnboardingCubit, StockCubit, etc.)
      └── MaterialApp.router (GoRouter)
          └── AppShell (ShellRoute with BottomNavigationBar)
```

### Routing Architecture

**Initial flow**: `/splash` (4s) → session check → `/auth/login` OR `/onboarding` OR `/home`

**Route types**:
- **Shell routes** (with bottom nav): `/home`, `/contracts`, `/templates`, `/inbox`, `/profile`
- **Full-screen** (no bottom nav): `/auth/login`, `/settings`, `/privacy-policy`
- Use `NoTransitionPage` for bottom nav screens to prevent animation

**Adding routes**:
1. Edit `lib/core/router/app_router.dart`
2. Shell routes: Add inside `ShellRoute.routes`
3. Full-screen: Add as top-level `GoRoute`
4. Parameters: Pass via `state.extra` as `Map<String, dynamic>`

### Authentication Flow

**Providers**: Google Sign-In, Kakao Login, Email/Password

**Components**:
- `AuthCubit`: Manages auth state, auto-restores session on app start via `checkSession()`
- `SessionService`: Persists `accessToken`, `user`, `expiresAt` to SharedPreferences
- `ApiClient`: Auto-injects Bearer token from session into all API requests

**Google OAuth IDs**:
- Web: `723715287873-8jp38k93ksspp7jkeljv4v0jr2eobcb7.apps.googleusercontent.com`
- Android: `723715287873-04874jd2a3533h1nqc76anaj7hu5q0ni.apps.googleusercontent.com`
- Firebase Project: `insign-69997` (Project Number: `723715287873`)

### NestJS Backend Architecture

**Port**: 8083 (proxied at `https://in-sign.shop/api` and `/adm`)
**Database**: MySQL with TypeORM
**Admin Portal**: EJS templates at `/adm/*`

```
src/
├── main.ts                  # Express server, Swagger at /docs
├── app.module.ts            # Root module
├── auth/                    # JWT/Local auth strategies
├── api-auth/                # OAuth endpoints (Google, Kakao)
├── users/                   # User management
├── contracts/               # Contract CRUD + PDF generation
├── templates/               # Template management
├── inbox/                   # Push notification inbox
├── push-tokens/             # FCM token registration
├── mail/                    # Email service (Nodemailer)
├── admin/                   # Admin portal controllers
└── scripts/                 # Migration/encryption scripts
```

**Key modules**:
- `contracts/`: DOCX templating (docxtemplater), PDF conversion (Puppeteer), file uploads (Multer)
- `push-tokens/`: Firebase Admin SDK for FCM
- `api-auth/`: OAuth verification for Google/Kakao

**Environment** (`.env`):
```env
# Server
PORT=8083

# Database (MySQL with TypeORM)
DB_HOST=localhost
DB_PORT=3306
DB_USERNAME=root
DB_PASSWORD=<password>
DB_NAME=insign

# Security
SESSION_SECRET=<secret>
JWT_SECRET=<secret>

# OAuth
GOOGLE_WEB_CLIENT_ID=<client-id>
GOOGLE_ANDROID_CLIENT_ID=<client-id>

# Email (Nodemailer)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=<email>
SMTP_PASS=<password>

# Firebase Admin SDK
FIREBASE_PROJECT_ID=insign-69997
FIREBASE_CLIENT_EMAIL=<service-account-email>
FIREBASE_PRIVATE_KEY=<private-key>
```

**Admin Portal**:
- Default admin account: `admin / admin1234` (auto-created on first run)
- Access at `https://in-sign.shop/adm/dashboard`
- EJS templates in `nestjs_app/views/`

## Key Workflows

### Adding a New Feature

**Flutter**:
1. Create `lib/features/feature_name/cubit/feature_cubit.dart` (if stateful)
2. Create `lib/features/feature_name/view/feature_screen.dart`
3. Add route in `lib/core/router/app_router.dart`
4. Register cubit in `main.dart` if needed globally
5. Update `lib/app.dart` if adding to bottom navigation

**NestJS**:
1. Create module: `nest g module feature`
2. Create controller: `nest g controller feature`
3. Create service: `nest g service feature`
4. Add entity (TypeORM) and DTOs
5. Register in `app.module.ts`

### Adding an API Endpoint (Full Stack)

1. **Backend**: Create endpoint in `nestjs_app/src/*/` (controller + service + DTO)
2. **Flutter Config**: Add endpoint to `insign_flutter/lib/core/config/api_config.dart`
3. **Flutter Repository**: Create method in `lib/data/*_repository.dart`
4. **Flutter Model**: Add/update model in `lib/models/` with `fromJson()`
5. **Flutter Cubit**: Call repository method, handle state
6. **Test locally**: NestJS on :8083, Flutter calls `http://localhost:8083/api`

### Deployment Workflow

1. **Flutter Web Build**:
   ```bash
   cd insign_flutter
   flutter build web
   cp -r build/web/* /home/insign/web/
   ```

2. **NestJS Backend** (if API changed):
   ```bash
   cd nestjs_app
   npm run build
   npm run start:prod
   # Or restart with PM2/systemd
   ```

3. **Nginx**: Auto-serves updated static files from `/home/insign/web/` (no restart needed)

### Running Database Scripts

NestJS scripts require database connection. Two methods:

**Method 1: Using npm scripts** (reads from `.env`):
```bash
cd nestjs_app
npm run list:users
npm run check:encryption
npm run verify:password
```

**Method 2: Direct ts-node** (with inline env vars):
```bash
DB_HOST=localhost DB_PORT=3306 DB_USERNAME=insign \
DB_PASSWORD='H./Bv!jPsH*z-[Jo' DB_NAME=insign \
npx ts-node -r tsconfig-paths/register src/scripts/list-users.ts
```

## Platform Configuration

### Android
- Package: `app.insign`
- minSdkVersion: 21 (required by Kakao SDK)
- multiDex: enabled (Kakao SDK + Firebase)
- Google Services: `android/app/google-services.json`
- Keystore: Uses same keystore for debug/release (SHA-1 consistency)
- MainActivity: `android/app/src/main/kotlin/app/insign/MainActivity.kt`

### Firebase
- Project: `insign-69997`
- `firebase_options.dart`: Auto-generated config
- Background handler: `firebaseMessagingBackgroundHandler` in `main.dart`
- Must be decorated with `@pragma('vm:entry-point')`

### Nginx Routing
- `/` → Flutter web (static files from `/home/insign/web`)
- `/api/*` → NestJS backend (127.0.0.1:8083)
- `/adm/*` → Admin portal EJS (NestJS)
- `/static/*` → Backend static resources (NestJS)

## Code Conventions

### Flutter/Dart
- Korean UI text, English code/comments
- Two-space indentation, trailing commas
- File naming: `snake_case.dart`
- Screens: `*_screen.dart`, Cubits: `*_cubit.dart`, Services: `*_service.dart`
- **States: Do NOT extend Equatable** (use `copyWith` pattern)
- Centralize theme tokens in `lib/core/theme/`

### NestJS/TypeScript
- Controllers: `*.controller.ts`, Services: `*.service.ts`, DTOs: `*.dto.ts`, Entities: `*.entity.ts`
- ESLint + Prettier formatting
- Korean UI for admin portal, English code

## Testing

### Flutter
```bash
flutter test                        # All tests
flutter test test/widget_test.dart  # Specific test
flutter test --coverage            # With coverage report
```

### NestJS
```bash
npm run test              # Unit tests
npm run test:watch        # Watch mode
npm run test:cov          # Coverage
npm run test:e2e          # E2E tests
```

## Migration Context

**History**: Originally a stock/investment app ("시그널 픽" / Quant), migrated to contract management ("인싸인" / Insign) in Nov 2025.

**Legacy artifacts** (to be refactored):
- `StockCubit` → should be `ContractCubit`
- "Podcast" features → actually notifications/messaging
- `podcast_repository.dart`, `portfolio_repository.dart` → legacy from stock app
- MiniPlayer widget exists but hidden (`showMiniPlayer = false` in app.dart:51)

## Important Notes

### Authentication SHA-1 Requirements
- Both Google OAuth and Kakao require SHA-1 key hash
- Debug and release use **same keystore** for consistency
- See `insign_flutter/KAKAO_SETUP.md` and `GOOGLE_OAUTH_SETUP.md`

### Session Management
- Tokens auto-restore on app start via `AuthCubit.checkSession()`
- `SessionService` persists to SharedPreferences
- `ApiClient` auto-injects Bearer token into all authenticated requests

### Data Encryption & Privacy
- **Personal data encryption**: Contract personal info (names, emails, phone numbers) encrypted at rest
- **Encryption scripts**: Available in `nestjs_app/src/scripts/` for migrating existing data
- **Migration flow**:
  1. Run schema alteration script (e.g., `npm run migrate:alter-schema`)
  2. Run encryption script (e.g., `npm run migrate:encrypt-contracts`)
  3. Verify with `npm run check:encryption`
- **CRITICAL**: Never modify encrypted columns directly - always use migration scripts
- Encrypted fields: User emails, contract participant info, mail logs

### Push Notifications (Firebase Cloud Messaging)
- `PushNotificationService.initialize()` called in `main.dart` after Firebase init
- FCM token automatically registered with backend on app start
- Background handler (`firebaseMessagingBackgroundHandler`) must be:
  - Top-level function (not inside a class)
  - Decorated with `@pragma('vm:entry-point')` for tree-shaking
  - Defined before `main()` function
- Foreground notifications handled by `PushNotificationService`
- Inbox module in NestJS manages notification storage and push-tokens registration
- Flutter local notifications used for displaying notifications

### WSL2 Development
- Working directory: `/home/insign` (not `/mnt/c/android_prj/`)
- Flutter commands: Run from `insign_flutter/`
- NestJS commands: Run from `nestjs_app/`
- Some commands may have `bash\r` errors - use Linux subsystem directly

## Troubleshooting

### Flutter Common Issues

**Hot reload not working**:
```bash
flutter clean
flutter pub get
flutter run
```

**Kakao/Google OAuth issues**:
- Verify SHA-1 key hash matches in Firebase/Kakao console
- Check client IDs in `api_config.dart` match OAuth console
- For Kakao: Ensure minSdkVersion is 21+, multiDex enabled

**Web build errors**:
- Clear `build/` directory: `flutter clean`
- Check `web/index.html` has correct Google client ID meta tag

### NestJS Common Issues

**Database connection errors**:
- Verify `.env` credentials match MySQL instance
- Check MySQL is running: `sudo mysql -u root -p`
- Test connection: `npm run list:users`

**TypeORM sync issues**:
- TypeORM auto-sync is disabled in production
- Use migration scripts for schema changes
- Never delete/modify encrypted columns without migration

**Port 8083 already in use**:
```bash
lsof -i :8083
kill <pid>
# Or use different port in .env
```

### Nginx Issues

**Static files not updating**:
```bash
# Verify files copied correctly
ls -la /home/insign/web/
# Check nginx config
sudo nginx -t
# Reload if needed (usually not required)
sudo systemctl reload nginx
```

**API requests failing**:
- Check backend is running: `curl http://localhost:8083/api/health`
- Verify nginx proxy: Check `/api/*` routes in `in-sign.conf`

## Additional Documentation

**Flutter** (`insign_flutter/`):
- `KAKAO_SETUP.md` - Kakao login setup with SHA-1
- `GOOGLE_OAUTH_SETUP.md` - Google OAuth configuration
- `ANDROID_KEYSTORE_SETUP.md` - Keystore management
- `PLAY_STORE_DEPLOYMENT.md` - Play Store deployment
- `CLAUDE.md` - Flutter-specific guidance (separate from this root CLAUDE.md)

**Backend** (`nestjs_app/`):
- Swagger docs at `http://localhost:8083/docs` (dev mode)
- `README.md` - Quick start guide

**Root**:
- `AGENTS.md` - Coding standards and guidelines
- `in-sign.conf` - Nginx reverse proxy configuration
- `작업내역_*.md` - Work history logs (Korean)
