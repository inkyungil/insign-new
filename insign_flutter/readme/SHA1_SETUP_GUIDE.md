# Google OAuth SHA-1 등록 가이드

## 문제 상황

❌ **잘못된 이해**: Android OAuth 클라이언트 ID 하나에 여러 SHA-1 등록 가능
✅ **실제**: Android OAuth 클라이언트 ID 하나에 **SHA-1 하나만** 등록 가능

## 현재 설정

### 기존 클라이언트 ID
```
Android: 498213338840-5tuq94mf9ktt92speec4871vsi7rb22v.apps.googleusercontent.com
Web:     498213338840-q7v8crk85mstarb04bo5iusj6f022dng.apps.googleusercontent.com
```

### SHA-1 지문
```
Debug:   A8:CD:67:98:1A:F4:77:69:DC:D0:C3:EE:8B:F7:28:E4:CE:94:7C:72
Release: E9:5C:90:0D:39:55:AB:D1:69:E0:5E:18:B5:F3:E5:1A:29:B0:7C:49
```

---

## 해결 방법 (권장: 방법 1)

### 방법 1: Release SHA-1만 등록 (추천) ⭐

**개발 중에도 Release keystore 사용**

#### 장점
- 설정이 간단함
- google-services.json 하나만 관리
- 프로덕션과 동일한 환경에서 테스트

#### 단점
- Debug 빌드 시 약간 느림 (서명 때문)

#### 설정 방법

1. **Google Cloud Console 등록**
   ```
   URL: https://console.cloud.google.com/auth/clients/498213338840-5tuq94mf9ktt92speec4871vsi7rb22v.apps.googleusercontent.com?project=insign-prj

   패키지명: app.insign
   SHA-1: E9:5C:90:0D:39:55:AB:D1:69:E0:5E:18:B5:F3:E5:1A:29:B0:7C:49
   ```

2. **build.gradle 수정** (Debug 빌드에도 Release 서명 사용)

```gradle
android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
        // Debug에도 Release 서명 사용
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
            minifyEnabled false
            shrinkResources false
        }
    }
}
```

3. **완료!** Debug/Release 모두 동일한 SHA-1 사용

---

### 방법 2: Debug/Release용 Android 클라이언트 ID 2개 생성

**별도의 클라이언트 ID를 각각 생성**

#### 장점
- Debug와 Release 환경 완전 분리
- Debug 빌드가 빠름

#### 단점
- 설정이 복잡함
- google-services.json을 2개 관리해야 함
- Flavor 또는 빌드 스크립트 필요

#### 설정 방법

1. **Google Cloud Console에서 Android OAuth 클라이언트 ID 2개 생성**

   **Debug용**:
   ```
   이름: InSign Android (Debug)
   패키지명: app.insign
   SHA-1: A8:CD:67:98:1A:F4:77:69:DC:D0:C3:EE:8B:F7:28:E4:CE:94:7C:72

   → 클라이언트 ID 생성됨 (예: 498213338840-xxxxx-debug.apps.googleusercontent.com)
   ```

   **Release용** (기존 사용):
   ```
   이름: InSign Android (Release)
   패키지명: app.insign
   SHA-1: E9:5C:90:0D:39:55:AB:D1:69:E0:5E:18:B5:F3:E5:1A:29:B0:7C:49

   → 기존: 498213338840-5tuq94mf9ktt92speec4871vsi7rb22v.apps.googleusercontent.com
   ```

2. **google-services.json 다운로드**
   - Debug용 google-services.json 다운로드
   - Release용 google-services.json 다운로드 (기존 파일)

3. **빌드 타입별 설정**

   **android/app/build.gradle**:
   ```gradle
   android {
       buildTypes {
           debug {
               // android/app/src/debug/google-services.json 사용
           }
           release {
               // android/app/src/release/google-services.json 사용
           }
       }
   }
   ```

   **파일 위치**:
   ```
   android/app/
   ├── src/
   │   ├── debug/
   │   │   └── google-services.json   (Debug용)
   │   ├── release/
   │   │   └── google-services.json   (Release용)
   │   └── main/
   │       └── ...
   └── build.gradle
   ```

---

## 권장 설정: 방법 1 적용

### 1단계: Google Cloud Console 등록

```
URL: https://console.cloud.google.com/auth/clients/498213338840-5tuq94mf9ktt92speec4871vsi7rb22v.apps.googleusercontent.com?project=insign-prj

설정:
- 애플리케이션 유형: Android
- 이름: InSign Android
- 패키지 이름: app.insign
- SHA-1 인증서 지문: E9:5C:90:0D:39:55:AB:D1:69:E0:5E:18:B5:F3:E5:1A:29:B0:7C:49
```

### 2단계: build.gradle 수정

현재 build.gradle을 수정하여 Debug에도 Release keystore를 사용하도록 설정합니다.

### 3단계: 테스트

```bash
# Debug 빌드 (Release keystore 사용)
flutter run

# Release 빌드
flutter build apk --release
```

둘 다 동일한 SHA-1을 사용하므로 Google Sign-In이 정상 작동합니다.

---

## Kakao 설정

Kakao도 동일하게 **Release Key Hash만 등록**하면 됩니다:

```
패키지명: app.insign
키 해시: 6VyQDTlVq9Fp4F4YtfPlGimwfEk=
```

---

## 요약

### ✅ 권장: 방법 1 (Release SHA-1만 사용)

1. Google Console: Release SHA-1만 등록
2. Kakao: Release Key Hash만 등록
3. build.gradle: Debug에도 Release keystore 사용
4. 완료!

### 대안: 방법 2 (2개 클라이언트 ID)

- 복잡하지만 완전 분리 가능
- 팀이 크거나 환경 분리가 중요한 경우에만 사용
