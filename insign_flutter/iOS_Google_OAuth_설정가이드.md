# iOS Google OAuth 2.0 설정 가이드

## 문제 상황
- iOS에서 Google 로그인 시 "400 오류: invalid_request" 발생
- 원인: OAuth 2.0 클라이언트 ID가 Google Cloud Console에 제대로 등록되지 않음

## 📋 필요한 정보

### 현재 프로젝트 정보
- **Firebase Project ID**: `insign-69997`
- **Firebase Project Number**: `723715287873`
- **Bundle ID**: `app.insign`
- **iOS Client ID**: `723715287873-nrqen0g7j7m679h6196i215308441539.apps.googleusercontent.com`
- **Web Client ID**: `723715287873-8jp38k93ksspp7jkeljv4v0jr2eobcb7.apps.googleusercontent.com`

## 🔧 설정 단계

### 1단계: Google Cloud Console에서 OAuth 2.0 클라이언트 ID 확인

1. **Google Cloud Console 접속**
   - 주소: https://console.cloud.google.com/
   - Firebase 프로젝트와 연결된 Google Cloud 프로젝트 선택

2. **API 및 서비스 > 사용자 인증 정보**
   - 좌측 메뉴에서 "API 및 서비스" → "사용자 인증 정보" 선택

3. **OAuth 2.0 클라이언트 ID 확인**
   - 기존 클라이언트 ID 목록 확인:
     - iOS 클라이언트 ID (iOS용)
     - 웹 클라이언트 ID (Android/서버용)
     - Android 클라이언트 ID (Android용)

### 2단계: iOS OAuth 2.0 클라이언트 ID 생성/수정

#### iOS 클라이언트 ID가 없는 경우:

1. **"+ 사용자 인증 정보 만들기" 클릭**
   - "OAuth 2.0 클라이언트 ID" 선택

2. **애플리케이션 유형 선택**
   - 유형: **iOS**

3. **iOS 앱 정보 입력**
   ```
   이름: insign iOS Client
   Bundle ID: app.insign
   ```

4. **"만들기" 클릭**
   - 생성된 클라이언트 ID 복사

#### iOS 클라이언트 ID가 있는 경우:

1. **기존 iOS 클라이언트 ID 클릭**
2. **Bundle ID 확인**
   - Bundle ID가 `app.insign`인지 확인
   - 다르면 수정

### 3단계: OAuth 동의 화면 설정

1. **"OAuth 동의 화면" 메뉴 선택**

2. **앱 정보 입력**
   ```
   앱 이름: 인싸인
   사용자 지원 이메일: (본인 이메일)
   앱 로고: (선택사항)
   앱 도메인:
     - 애플리케이션 홈페이지: https://in-sign.shop
     - 개인정보처리방침: https://in-sign.shop/privacy-policy
     - 서비스 약관: https://in-sign.shop/terms-of-service
   개발자 연락처 정보: (본인 이메일)
   ```

3. **범위 설정**
   - "범위 추가 또는 삭제" 클릭
   - 다음 범위 추가:
     - `email`
     - `profile`
     - `openid`

4. **게시 상태**
   - **테스트 중**: 테스트 사용자만 로그인 가능
   - **프로덕션**: 모든 사용자 로그인 가능

   **중요**: 앱을 배포하기 전에 "프로덕션"으로 변경해야 합니다!

5. **테스트 사용자 추가** (테스트 중인 경우)
   - 본인 Gmail 주소 추가
   - `propose101@gmail.com` 추가

### 4단계: Firebase Console에서 iOS 앱 설정

1. **Firebase Console 접속**
   - 주소: https://console.firebase.google.com/
   - 프로젝트 선택: `insign-69997`

2. **프로젝트 설정 > 일반**
   - "내 앱" 섹션에서 iOS 앱 확인
   - Bundle ID가 `app.insign`인지 확인

3. **Authentication 설정**
   - 좌측 메뉴 "Authentication" 선택
   - "Sign-in method" 탭 선택
   - Google 제공업체 활성화 확인

4. **GoogleService-Info.plist 다운로드**
   - 프로젝트 설정 > 일반 > iOS 앱
   - "GoogleService-Info.plist 다운로드" 클릭
   - 다운로드한 파일을 `ios/Runner/` 디렉토리에 복사 (덮어쓰기)

### 5단계: 앱 코드 확인

#### Info.plist 설정 확인 (이미 완료됨)

`ios/Runner/Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.723715287873-nrqen0g7j7m679h6196i215308441539</string>
        </array>
    </dict>
</array>
<key>GIDClientID</key>
<string>723715287873-nrqen0g7j7m679h6196i215308441539.apps.googleusercontent.com</string>
```

#### GoogleAuthService 설정 확인 (이미 수정됨)

`lib/data/services/google_auth_service.dart`:
```dart
static const String _iosClientId =
    '723715287873-nrqen0g7j7m679h6196i215308441539.apps.googleusercontent.com';

static final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: kIsWeb
      ? _webClientId
      : (defaultTargetPlatform == TargetPlatform.iOS ? _iosClientId : null),
  serverClientId: _webClientId,
);
```

## ✅ 체크리스트

설정이 완료되었는지 확인하세요:

- [ ] Google Cloud Console에서 iOS OAuth 2.0 클라이언트 ID 생성/확인
- [ ] Bundle ID가 `app.insign`으로 정확히 설정됨
- [ ] OAuth 동의 화면 설정 완료
- [ ] OAuth 동의 화면 게시 상태 확인 (테스트/프로덕션)
- [ ] 테스트 사용자 추가 (테스트 모드인 경우)
- [ ] Firebase Console에서 Google 인증 활성화
- [ ] GoogleService-Info.plist 최신 버전으로 업데이트
- [ ] Info.plist에 URL Scheme 설정 완료
- [ ] GoogleAuthService에 iOS Client ID 추가 완료

## 🧪 테스트 방법

1. **앱 재빌드**
   ```bash
   flutter clean
   flutter pub get
   cd ios && pod install && cd ..
   flutter build ios --no-codesign
   ```

2. **Xcode로 실행**
   - Xcode에서 `ios/Runner.xcworkspace` 열기
   - 실제 iOS 디바이스나 시뮬레이터 선택
   - Run 버튼 클릭

3. **Google 로그인 테스트**
   - 로그인 화면에서 "Google로 로그인" 클릭
   - Google 계정 선택
   - 권한 승인
   - 로그인 성공 확인

## ⚠️ 주의사항

### 1. OAuth 동의 화면 상태
- **테스트 모드**:
  - 등록된 테스트 사용자만 로그인 가능
  - 최대 100명까지 추가 가능
  - 앱 스토어 배포 전에 프로덕션으로 변경 필요

- **프로덕션 모드**:
  - 모든 Google 사용자 로그인 가능
  - Google 검토 필요할 수 있음 (민감한 권한 요청 시)

### 2. Bundle ID 일치
- Xcode 프로젝트 설정
- Firebase Console
- Google Cloud Console OAuth 클라이언트
- Info.plist

**모든 곳에서 `app.insign`으로 동일해야 함!**

### 3. GoogleService-Info.plist
- Firebase Console에서 다운로드한 최신 파일 사용
- `ios/Runner/` 디렉토리에 위치
- Xcode 프로젝트에 포함되어 있는지 확인

## 🔗 참고 링크

- **Google Cloud Console**: https://console.cloud.google.com/
- **Firebase Console**: https://console.firebase.google.com/
- **OAuth 2.0 설정 가이드**: https://developers.google.com/identity/protocols/oauth2
- **Firebase iOS 설정**: https://firebase.google.com/docs/ios/setup

## 🆘 문제 해결

### "400 오류: invalid_request" 지속 시

1. **OAuth 동의 화면 게시 상태 확인**
   - 테스트 모드인 경우 테스트 사용자에 추가되었는지 확인

2. **클라이언트 ID 재생성**
   - Google Cloud Console에서 기존 iOS 클라이언트 ID 삭제
   - 새로 생성
   - 코드 업데이트

3. **캐시 클리어**
   ```bash
   flutter clean
   cd ios
   rm -rf Pods Podfile.lock
   pod install
   cd ..
   ```

### "access_denied" 오류

- OAuth 동의 화면이 "테스트" 모드인 경우
- 테스트 사용자 목록에 추가 필요

### 로그인 후 바로 로그아웃됨

- `serverClientId` 설정 확인
- Backend API에서 ID Token 검증 로직 확인

## 📝 작업 기록

- **날짜**: 2025-12-02
- **작업**: iOS Google OAuth 설정 추가
- **변경 파일**:
  - `lib/data/services/google_auth_service.dart`
  - `iOS_Google_OAuth_설정가이드.md` (신규)
