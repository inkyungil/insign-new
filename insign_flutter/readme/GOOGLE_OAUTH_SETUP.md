# Google OAuth 설정 가이드

## 현재 설정 정보

### 프로젝트 정보
- **프로젝트 ID**: `insign-prj`
- **프로젝트 번호**: `498213338840`

### 기존 클라이언트 ID
- **Web**: `498213338840-q7v8crk85mstarb04bo5iusj6f022dng.apps.googleusercontent.com`
- **Android**: `498213338840-5tuq94mf9ktt92speec4871vsi7rb22v.apps.googleusercontent.com`

---

## ✅ SHA-1 등록 방법 (중요!)

### ⚠️ 주의: 클라이언트 ID는 1개, SHA-1은 여러 개!

**하나의 Android OAuth 클라이언트 ID에 여러 SHA-1 지문을 등록**할 수 있습니다.
- Debug용 SHA-1
- Release용 SHA-1
- 개발자 컴퓨터마다 다른 SHA-1 (팀원 추가)

### 등록 절차

1. **Google Cloud Console 접속**
   - URL: https://console.cloud.google.com/
   - 프로젝트: `insign-prj` 선택

2. **사용자 인증 정보로 이동**
   - 좌측 메뉴: **API 및 서비스** → **사용자 인증 정보**

3. **Android OAuth 클라이언트 ID 수정**
   - 기존 클라이언트 ID 클릭: `498213338840-5tuq94mf9ktt92speec4871vsi7rb22v`
   - 또는 새로 생성: **사용자 인증 정보 만들기** → **OAuth 클라이언트 ID** → **Android**

4. **SHA-1 지문 추가**

   **방법 A: 기존 클라이언트 ID 수정 (권장)**
   ```
   애플리케이션 이름: InSign Android
   패키지 이름: app.insign

   SHA-1 인증서 지문 #1 (Debug):
   A8:CD:67:98:1A:F4:77:69:DC:D0:C3:EE:8B:F7:28:E4:CE:94:7C:72

   [+ SHA-1 인증서 지문 추가] 클릭

   SHA-1 인증서 지문 #2 (Release):
   E9:5C:90:0D:39:55:AB:D1:69:E0:5E:18:B5:F3:E5:1A:29:B0:7C:49
   ```

5. **저장**

---

## 📱 Flutter 앱 코드 설정

### 클라이언트 ID는 그대로 사용

```dart
// lib/data/services/google_auth_service.dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
  // Android 클라이언트 ID는 변경 필요 없음!
  // SHA-1만 Google Cloud Console에 등록하면 됨
);
```

### Backend 설정도 동일

```env
# nestjs_app/.env_local
GOOGLE_ANDROID_CLIENT_ID=498213338840-5tuq94mf9ktt92speec4871vsi7rb22v.apps.googleusercontent.com
# ↑ 그대로 유지
```

---

## 🔍 작동 원리

### Google Sign-In 인증 흐름

1. **앱 실행** → Google Sign-In SDK가 APK의 서명 확인
2. **서명에서 SHA-1 추출** (앱이 자동으로 계산)
3. **Google 서버에 요청**:
   ```
   패키지명: app.insign
   SHA-1: A8:CD:67:98:1A:F4:77:69:DC:D0:C3:EE:8B:F7:28:E4:CE:94:7C:72
   ```
4. **Google 서버 검증**:
   - 클라이언트 ID `498213338840-5tuq94mf9ktt92speec4871vsi7rb22v`에
   - 패키지명 `app.insign`과
   - SHA-1 `A8:CD:67:98:1A:F4:77:69:DC:D0:C3:EE:8B:F7:28:E4:CE:94:7C:72`가
   - 등록되어 있는지 확인
5. **인증 성공** → ID Token 발급

---

## 📋 정리

### ❌ 잘못된 이해
```
Debug SHA-1   → Debug 전용 클라이언트 ID (별도)
Release SHA-1 → Release 전용 클라이언트 ID (별도)
```

### ✅ 올바른 구조
```
Android 클라이언트 ID (1개)
└─ 498213338840-5tuq94mf9ktt92speec4871vsi7rb22v
   ├─ 패키지명: app.insign
   ├─ SHA-1: A8:CD:67:98:1A:F4:77:69:DC:D0:C3:EE:8B:F7:28:E4:CE:94:7C:72 (Debug)
   └─ SHA-1: E9:5C:90:0D:39:55:AB:D1:69:E0:5E:18:B5:F3:E5:1A:29:B0:7C:49 (Release)
```

---

## 🎯 실전 예시

### 시나리오: 개발 팀 구성원이 3명

**클라이언트 ID**: 1개
```
498213338840-5tuq94mf9ktt92speec4871vsi7rb22v
```

**등록된 SHA-1**: 5개
```
패키지명: app.insign

SHA-1 지문들:
1. A8:CD:67:98:1A:F4:77:69... (서버 Debug keystore)
2. E9:5C:90:0D:39:55:AB:D1... (Release keystore)
3. 12:34:56:78:90:AB:CD:EF... (개발자A의 로컬 debug.keystore)
4. AB:CD:EF:12:34:56:78:90... (개발자B의 로컬 debug.keystore)
5. 98:76:54:32:10:FE:DC:BA... (개발자C의 로컬 debug.keystore)
```

모두 **같은 클라이언트 ID**를 사용하지만, 각자의 SHA-1이 모두 등록되어 있어야 합니다.

---

## 🔧 현재 해야 할 작업

### Google Cloud Console에서

1. 기존 Android 클라이언트 ID 찾기:
   ```
   498213338840-5tuq94mf9ktt92speec4871vsi7rb22v
   ```

2. 두 개의 SHA-1 추가:
   - Debug: `A8:CD:67:98:1A:F4:77:69:DC:D0:C3:EE:8B:F7:28:E4:CE:94:7C:72`
   - Release: `E9:5C:90:0D:39:55:AB:D1:69:E0:5E:18:B5:F3:E5:1A:29:B0:7C:49`

3. 저장

### 코드 변경 필요 없음!
- Flutter 앱 코드: 변경 불필요
- Backend .env: 변경 불필요
- 클라이언트 ID는 그대로 사용

---

## ⚠️ 문제 해결

### "API not enabled" 오류
- **Google Cloud Console** → **API 및 서비스** → **라이브러리**
- "Google Sign-In API" 또는 "Google+ API" 검색 후 사용 설정

### "Developer Error" 또는 "10:" 오류
- SHA-1이 제대로 등록되지 않음
- 패키지명이 일치하지 않음 (`app.insign` 확인)
- google-services.json 파일 확인

### 빌드된 APK로 테스트 시 실패
```bash
# APK의 실제 서명 확인
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk | grep SHA

# 위에서 나온 SHA-1이 Google Cloud Console에 등록되어 있는지 확인
```

---

## 📚 참고 자료

- [Google Sign-In for Android](https://developers.google.com/identity/sign-in/android/start)
- [OAuth 클라이언트 ID 만들기](https://support.google.com/cloud/answer/6158849)
- [Flutter Google Sign In 패키지](https://pub.dev/packages/google_sign_in)
