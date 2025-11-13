# Android Keystore 설정 가이드

## 개요

이 문서는 인싸인(Insign) Flutter 앱의 Android 키스토어 설정 및 SHA-1 인증서 관리 방법을 설명합니다.

## 키스토어 정보

### 파일 위치
```
android/app/keystores/release.keystore
```

### 키스토어 설정 (android/key.properties)
```properties
storePassword=insign1004
keyPassword=insign1004
keyAlias=insign-release
storeFile=keystores/release.keystore
```

### 인증서 지문 (Certificate Fingerprints)

**생성일**: 2025-11-03

**SHA-1**:
```
F5:7A:6C:35:90:6A:A5:09:28:10:EA:17:F7:D2:37:40:81:61:E9:5E
```

**SHA-256**:
```
27:58:B2:6D:42:F0:88:6A:0C:62:9B:4C:05:6E:7E:D0:A1:E7:A5:81:B6:F8:BD:4B:02:7B:46:5F:C7:1D:3F:6A
```

## 주요 특징

### ✅ 개발과 배포 버전 동일 키스토어 사용

`android/app/build.gradle` 설정에서 **debug**와 **release** 빌드 모두 동일한 키스토어를 사용하도록 구성되어 있습니다:

```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
    // Debug 빌드에도 Release keystore 사용 (Google OAuth SHA-1 통합)
    debug {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}

buildTypes {
    debug {
        signingConfig signingConfigs.debug  // Release keystore 사용
    }
    release {
        signingConfig signingConfigs.release
    }
}
```

**장점**:
- 개발 중에도 프로덕션과 동일한 SHA-1 사용
- Google OAuth, Kakao 로그인 등 인증 서비스에 하나의 SHA-1만 등록
- 빌드 타입에 관계없이 일관된 동작 보장

## SHA-1 인증서 지문 추출 방법

### Windows (PowerShell 또는 CMD)

```bash
cd android\app
keytool -list -v -keystore keystores\release.keystore -alias insign-release -storepass insign1004
```

### Linux / macOS / WSL

```bash
cd android/app
keytool -list -v -keystore keystores/release.keystore -alias insign-release -storepass insign1004
```

### 출력 예시

```
Certificate fingerprints:
     SHA1: F5:7A:6C:35:90:6A:A5:09:28:10:EA:17:F7:D2:37:40:81:61:E9:5E
     SHA256: 27:58:B2:6D:42:F0:88:6A:0C:62:9B:4C:05:6E:7E:D0:A1:E7:A5:81:B6:F8:BD:4B:02:7B:46:5F:C7:1D:3F:6A
```

## Google Cloud Console 설정

### 1. Google Cloud Console 접속
- URL: https://console.cloud.google.com/
- 프로젝트: `insign-prj` 선택

### 2. OAuth 2.0 클라이언트 ID 설정

**현재 클라이언트 ID**:
- Web Client ID: `498213338840-q7v8crk85mstarb04bo5iusj6f022dng.apps.googleusercontent.com`
- Android Client ID: `498213338840-5tuq94mf9ktt92speec4871vsi7rb22v.apps.googleusercontent.com`

### 3. Android OAuth 클라이언트 업데이트

1. **APIs & Services** > **Credentials** 이동
2. Android Client ID 선택 또는 새로 생성
3. 다음 정보 입력:
   - **Package name**: `app.insign`
   - **SHA-1 certificate fingerprint**: `F5:7A:6C:35:90:6A:A5:09:28:10:EA:17:F7:D2:37:40:81:61:E9:5E`
4. 저장

### 4. google-services.json 확인

파일 위치: `android/app/google-services.json`

이 파일이 최신 상태인지 확인하고, 필요시 Google Cloud Console에서 다시 다운로드합니다.

## Kakao Developers 설정

### 1. Kakao Developers 콘솔 접속
- URL: https://developers.kakao.com/
- 애플리케이션 선택

### 2. 플랫폼 설정

1. **내 애플리케이션** > **앱 설정** > **플랫폼**
2. **Android 플랫폼** 추가/수정
3. 다음 정보 입력:
   - **패키지명**: `app.insign`
   - **키 해시**: SHA-1 기반으로 계산 (아래 참조)

### 3. Kakao 키 해시 생성

Kakao는 SHA-1이 아닌 별도의 키 해시 형식을 사용합니다.

**PowerShell 스크립트 사용** (권장):

프로젝트 루트에 `get_keyhash.ps1` 스크립트가 있으면 실행:

```powershell
.\get_keyhash.ps1
```

**수동 생성**:

```bash
keytool -exportcert -alias insign-release -keystore android/app/keystores/release.keystore -storepass insign1004 | openssl sha1 -binary | openssl base64
```

출력된 키 해시를 Kakao Developers 콘솔에 등록합니다.

### 4. KakaoAuthService 설정 확인

파일: `lib/data/services/kakao_auth_service.dart`

Kakao Native App Key가 올바르게 설정되어 있는지 확인합니다.

## 빌드 테스트

### Debug 빌드 (개발용)

```bash
cd insign_flutter
flutter build apk --debug
```

생성 위치: `build/app/outputs/flutter-apk/app-debug.apk`

### Release 빌드 (배포용)

```bash
cd insign_flutter
flutter build apk --release
```

생성 위치: `build/app/outputs/flutter-apk/app-release.apk`

### 서명 확인

생성된 APK의 서명이 올바른지 확인:

```bash
# Debug APK 확인
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-debug.apk | grep -A 3 "Certificate fingerprints"

# Release APK 확인
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk | grep -A 3 "Certificate fingerprints"
```

두 빌드 모두 동일한 SHA-1 지문이 나와야 합니다:
```
SHA1: F5:7A:6C:35:90:6A:A5:09:28:10:EA:17:F7:D2:37:40:81:61:E9:5E
```

## 주의사항

### ⚠️ 키스토어 백업

키스토어 파일(`release.keystore`)과 비밀번호는 **반드시 안전한 곳에 백업**하세요.

- 키스토어를 분실하면 Play Store에 업데이트를 배포할 수 없습니다
- 키스토어 비밀번호를 잊어버리면 새로운 앱으로 다시 배포해야 합니다

**권장 백업 위치**:
- 암호화된 클라우드 스토리지 (Google Drive, OneDrive 등)
- 비밀번호 관리자 (1Password, LastPass 등)
- 안전한 외장 저장소

### ⚠️ Git에 키스토어 커밋 금지

`.gitignore`에 다음 항목이 포함되어 있는지 확인:

```gitignore
# Android keystore files
*.keystore
*.jks
key.properties
```

**절대로 Git에 커밋하지 마세요**:
- `android/app/keystores/release.keystore`
- `android/key.properties`

### ⚠️ Play Store 기존 앱 주의

이미 Google Play Store에 배포된 앱이 있다면 키스토어를 변경하면 안 됩니다.
- 키스토어 변경 시 기존 앱을 업데이트할 수 없음
- 완전히 새로운 앱으로 다시 배포해야 함

## 트러블슈팅

### Google 로그인이 작동하지 않는 경우

1. SHA-1 지문이 Google Cloud Console에 올바르게 등록되었는지 확인
2. `google-services.json` 파일이 최신 버전인지 확인
3. 앱을 완전히 삭제하고 재설치 (캐시 문제일 수 있음)
4. `flutter clean && flutter pub get` 실행 후 재빌드

### Kakao 로그인이 작동하지 않는 경우

1. 패키지명이 `app.insign`으로 정확히 입력되었는지 확인
2. Kakao 키 해시가 올바르게 생성되고 등록되었는지 확인
3. `get_keyhash.ps1` 스크립트 사용 권장
4. Kakao Native App Key가 코드에 올바르게 설정되었는지 확인

### APK 서명 오류

```
Error: A problem occurred evaluating project ':app'.
> Failed to read key from keystore
```

**해결 방법**:
1. `android/key.properties` 파일이 존재하는지 확인
2. 비밀번호가 올바른지 확인
3. 키스토어 파일 경로가 정확한지 확인

## 참고 문서

- Google Cloud Console: https://console.cloud.google.com/
- Kakao Developers: https://developers.kakao.com/
- Flutter Android 배포 가이드: https://docs.flutter.dev/deployment/android
- Android 앱 서명: https://developer.android.com/studio/publish/app-signing

## 변경 이력

- **2025-11-03**: 새로운 키스토어 생성 및 초기 설정
  - SHA-1: `F5:7A:6C:35:90:6A:A5:09:28:10:EA:17:F7:D2:37:40:81:61:E9:5E`
  - SHA-256: `27:58:B2:6D:42:F0:88:6A:0C:62:9B:4C:05:6E:7E:D0:A1:E7:A5:81:B6:F8:BD:4B:02:7B:46:5F:C7:1D:3F:6A`
  - 개발/배포 버전 동일 키스토어 사용 설정 완료
  - Windows PowerShell 호환을 위해 특수문자 제거한 비밀번호 사용



패키지
insign.app