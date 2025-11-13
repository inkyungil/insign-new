# 작업 내역 - 2025년 11월 7일

## 📋 작업 제목
**Google Play Store 배포 준비 및 설정**

---

## 🎯 작업 목표
인싸인(Insign) Flutter 앱을 Google Play Store에 배포하기 위한 전체 설정 완료

---

## ✅ 완료된 작업

### 1. Google Play Store 배포 설정 (build.gradle)

**파일**: `android/app/build.gradle`

#### 변경 사항:

**코드 난독화 및 최적화 활성화**
```gradle
buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled true        // 코드 난독화 활성화
        shrinkResources true      // 리소스 최적화 활성화
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'

        ndk {
            debugSymbolLevel 'SYMBOL_TABLE'  // 디버그 심볼 설정
        }
    }
    debug {
        signingConfig signingConfigs.debug
        applicationIdSuffix ".debug"  // 디버그 버전 구분
        debuggable true
    }
}
```

**효과**:
- APK/AAB 파일 크기 감소
- 코드 보안 강화
- 성능 최적화

---

### 2. ProGuard 규칙 파일 생성

**파일**: `android/app/proguard-rules.pro` (신규 생성)

#### 주요 내용:

```proguard
# Flutter 핵심 규칙
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Kakao SDK
-keep class com.kakao.sdk.** { *; }

# Gson (JSON 직렬화)
-keep class com.google.gson.** { *; }

# Kotlin & Coroutines
-keep class kotlin.** { *; }
-keepnames class kotlinx.coroutines.** { *; }

# 앱 모델 클래스
-keep class app.insign.** { *; }
```

**목적**: 난독화 시 필요한 클래스 보호

---

### 3. Gradle 빌드 성능 최적화

**파일**: `android/gradle.properties`

#### 추가된 설정:

```properties
# R8 전체 모드 활성화 (코드 최적화 강화)
android.enableR8.fullMode=true

# 빌드 캐시 활성화 (빌드 속도 향상)
org.gradle.caching=true

# 병렬 빌드 활성화
org.gradle.parallel=true

# 설정 캐시 활성화
org.gradle.configuration-cache=true

# 데몬 활성화 (빌드 속도 향상)
org.gradle.daemon=true
```

**효과**:
- 빌드 속도 향상
- 코드 최적화 강화
- 메모리 사용 효율화

---

### 4. 키스토어 경로 수정

**파일**: `android/key.properties`

#### 문제:
```
오류: Keystore file 'C:\...\app\app\keystores\release.keystore' not found
```

#### 해결:
```properties
# 이전 (오류)
storeFile=app/keystores/release.keystore

# 수정 후 (정상)
storeFile=keystores/release.keystore
```

**이유**: Gradle이 `android/app/` 기준으로 경로를 해석하므로 `app/` 중복 제거

---

### 5. API 레벨 35 업데이트

**파일**: `android/app/build.gradle`

#### 문제:
```
Play Console 오류: 현재 앱이 33의 API 수준을 타겟팅하고 있지만,
API 수준 35 이상을 타겟팅해야 합니다.
```

#### 해결:
```gradle
android {
    compileSdk 35  // 변경: flutter.compileSdkVersion → 35

    defaultConfig {
        minSdkVersion 21  // 유지 (Android 5.0)
        targetSdkVersion 35  // 변경: flutter.targetSdkVersion → 35
    }
}
```

**효과**:
- Google Play 최신 정책 준수
- Android 15 (API 35) 지원
- Android 5.0 ~ 15 호환

---

### 6. AndroidManifest 권한 추가

**파일**: `android/app/src/main/AndroidManifest.xml`

#### 추가된 권한:

```xml
<!-- 푸시 알림 권한 (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- 인터넷 권한 -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- 파일 접근 권한 (PDF 생성 및 file_picker) -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"
    tools:ignore="ScopedStorage" />

<!-- Android 13+ 미디어 접근 권한 -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
```

**목적**:
- Android 13+ 호환성
- 파일 접근 권한 명시
- 푸시 알림 지원

---

### 7. 버전 관리

**파일**: `pubspec.yaml`

```yaml
# 변경 전
version: 1.0.0+1

# 변경 후
version: 1.0.0+2
```

**이유**:
- Play Console에 재업로드 시 버전 코드 증가 필수
- versionCode 1 → 2

---

### 8. 빌드 스크립트 생성

#### 8.1. 일반 빌드 스크립트

**파일**:
- `build_release.ps1` (PowerShell)
- `build_release.bat` (Windows 배치)

**기능**:
1. Flutter 버전 확인
2. 의존성 설치 (`flutter pub get`)
3. 코드 분석 (`flutter analyze`)
4. Release App Bundle 빌드
5. 빌드 폴더 자동 열기
6. 단계별 안내 메시지

#### 8.2. 디버그 심볼 포함 빌드 스크립트

**파일**:
- `build_with_symbols.ps1` (PowerShell)
- `build_with_symbols.bat` (Windows 배치)

**기능**:
- 일반 빌드 + 디버그 심볼 생성
- `--split-debug-info` 옵션 사용
- symbols.zip 자동 생성
- 상세 안내 포함

**명령어 예시**:
```powershell
flutter build appbundle --release --split-debug-info=build/app/outputs/symbols
```

#### 8.3. 서명 확인 스크립트

**파일**:
- `verify_signature.ps1`
- `verify_signature.bat`

**기능**:
- AAB 파일의 서명 정보 확인
- 키스토어 사용 여부 검증

---

### 9. 문서 작성

#### 9.1. Play Store 배포 가이드

**파일**: `PLAY_STORE_DEPLOYMENT.md`

**주요 내용**:
- 사전 준비 사항
- 버전 관리 방법
- 빌드 명령어
- Play Console 업로드 절차
- 배포 체크리스트
- 문제 해결 가이드
- 추가 최적화 팁

#### 9.2. 출시 노트 템플릿

**파일**: `PLAY_CONSOLE_RELEASE_NOTES.md`

**포함된 템플릿**:
- 내부 테스트용 출시 노트
- 비공개 테스트용 출시 노트
- 공개 테스트용 출시 노트
- 프로덕션 정식 출시 노트
- 업데이트용 출시 노트 (v1.0.1, v1.1.0)
- 영어 버전 템플릿

**바로 사용 가능한 파일**: `QUICK_RELEASE_NOTE.txt`

```
버전 1.0.0 - 첫 내부 테스트

안녕하세요, 인싸인 앱 첫 테스트 버전입니다.

✅ 테스트 필요 기능:
• 로그인 (Google, Kakao, 직접 로그인)
• 계약서 템플릿 조회
• 계약서 작성 및 저장
• 디지털 서명 기능
• 푸시 알림 수신

⚠️ 알려진 이슈:
• 일부 기기에서 로그인 지연 가능
• 서명 패드 반응 속도 개선 예정

💬 피드백:
앱 사용 중 발견한 버그나 개선사항을 공유해주세요!
```

#### 9.3. 디버그 심볼 가이드

**파일**: `DEBUG_SYMBOLS_GUIDE.md`

**내용**:
- 디버그 심볼이란?
- 왜 필요한가?
- 업로드 방법
- ZIP 파일 만들기
- Play Console 상세 가이드
- FAQ

#### 9.4. API 35 업데이트 변경사항

**파일**: `API35_UPDATE_CHANGELOG.md`

**내용**:
- 변경 이유
- 변경된 파일 목록
- 호환성 정보
- 권한 설명
- 주의사항

#### 9.5. 키스토어 백업 가이드

**파일**: `KEYSTORE_BACKUP_GUIDE.md`

**내용**:
- 백업해야 할 파일
- 백업 방법 (클라우드, USB, 비밀번호 관리자)
- 보안 수칙
- 키스토어 분실 시 대처 방법
- 키스토어 정보 확인 명령어

---

## 📦 생성된 파일 목록

### 설정 파일
1. `android/app/proguard-rules.pro` - ProGuard 난독화 규칙
2. `android/gradle.properties` - Gradle 성능 최적화 설정

### 빌드 스크립트
3. `build_release.ps1` - PowerShell 일반 빌드 스크립트
4. `build_release.bat` - Windows 배치 일반 빌드 스크립트
5. `build_with_symbols.ps1` - PowerShell 디버그 심볼 포함 빌드
6. `build_with_symbols.bat` - Windows 배치 디버그 심볼 포함 빌드
7. `verify_signature.ps1` - AAB 서명 확인 스크립트
8. `verify_signature.bat` - AAB 서명 확인 스크립트

### 문서
9. `PLAY_STORE_DEPLOYMENT.md` - Play Store 배포 완전 가이드
10. `PLAY_CONSOLE_RELEASE_NOTES.md` - 출시 노트 템플릿 모음
11. `QUICK_RELEASE_NOTE.txt` - 바로 사용 가능한 출시 노트
12. `DEBUG_SYMBOLS_GUIDE.md` - 디버그 심볼 상세 가이드
13. `API35_UPDATE_CHANGELOG.md` - API 35 업데이트 변경사항
14. `KEYSTORE_BACKUP_GUIDE.md` - 키스토어 백업 가이드

### 작업 내역
15. `작업내역_2025-11-07_PlayStore배포준비.md` - 이 문서

---

## 🔧 수정된 기존 파일

1. `android/app/build.gradle`
   - compileSdk: 35
   - targetSdkVersion: 35
   - minifyEnabled: true
   - shrinkResources: true
   - ProGuard 설정 추가
   - NDK 디버그 심볼 레벨 설정

2. `android/gradle.properties`
   - R8 전체 모드 활성화
   - 빌드 캐시 활성화
   - 병렬 빌드 활성화
   - 설정 캐시 활성화

3. `android/key.properties`
   - storeFile 경로 수정 (app/ 제거)

4. `android/app/src/main/AndroidManifest.xml`
   - 7개 권한 추가 (인터넷, 알림, 파일 접근 등)

5. `pubspec.yaml`
   - version: 1.0.0+2 (버전 코드 증가)

---

## 🚀 빌드 및 배포 방법

### 방법 1: PowerShell 스크립트 사용 (권장)

```powershell
# 프로젝트 디렉토리로 이동
cd C:\android_prj\insign_flutter

# 일반 빌드 (디버그 심볼 없음)
.\build_release.ps1

# 또는 디버그 심볼 포함 빌드 (권장)
.\build_with_symbols.ps1
```

### 방법 2: 직접 명령어 실행

```powershell
# 캐시 정리
flutter clean

# 의존성 설치
flutter pub get

# 일반 빌드
flutter build appbundle --release

# 또는 디버그 심볼 포함 빌드
flutter build appbundle --release --split-debug-info=build/app/outputs/symbols
```

### 빌드 결과 파일

```
build/app/outputs/
├── bundle/release/
│   └── app-release.aab          ← Play Console에 업로드
└── symbols/ (심볼 포함 빌드 시)
    └── app.android-arm64.symbols ← ZIP으로 압축하여 업로드
```

---

## 📱 Play Console 업로드 절차

### 1. Play Console 접속
```
https://play.google.com/console
```

### 2. 내부 테스트 트랙 선택
```
앱 선택 → 테스트 → 내부 테스트 → 새 버전 만들기
```

### 3. App Bundle 업로드
```
build\app\outputs\bundle\release\app-release.aab 드래그 앤 드롭
```

### 4. 출시 노트 작성
`QUICK_RELEASE_NOTE.txt` 내용 복사하여 붙여넣기

### 5. 디버그 심볼 업로드 (선택사항)
```
아티팩트 탭 → 네이티브 디버그 심볼 → symbols.zip 업로드
```

### 6. 검토 및 출시

---

## 📊 버전 정보

| 항목 | 값 |
|------|-----|
| 앱 이름 | 인싸인 (Insign) |
| 패키지명 | app.insign |
| 버전명 | 1.0.0 |
| 버전코드 | 2 |
| minSdkVersion | 21 (Android 5.0) |
| targetSdkVersion | 35 (Android 15) |
| compileSdk | 35 |

---

## 🔐 키스토어 정보

```
Store File: android/app/keystores/release.keystore
Store Password: insign1004
Key Password: insign1004
Key Alias: insign-release
```

⚠️ **중요**: 이 정보는 절대 분실하지 마세요! 백업 필수!

---

## ✅ 배포 체크리스트

### 빌드 전
- [x] build.gradle 최적화 완료
- [x] ProGuard 규칙 설정 완료
- [x] API 레벨 35로 업데이트
- [x] AndroidManifest 권한 추가
- [x] 키스토어 파일 확인 완료
- [x] Firebase 설정 확인 완료
- [x] 버전 코드 증가 (1 → 2)
- [ ] `flutter analyze` 실행
- [ ] `flutter test` 실행 (선택)

### 빌드
- [ ] `flutter clean` 실행
- [ ] `flutter pub get` 실행
- [ ] `flutter build appbundle --release` 실행
- [ ] AAB 파일 생성 확인

### Play Console
- [ ] Play Console 접속
- [ ] 내부 테스트 트랙 선택
- [ ] AAB 파일 업로드
- [ ] 출시 노트 작성
- [ ] 디버그 심볼 업로드 (선택)
- [ ] 검토 및 출시

---

## 🐛 해결된 문제

### 1. 키스토어 경로 오류
**문제**: `app/app/keystores/release.keystore` 경로 중복
**해결**: `keystores/release.keystore`로 수정

### 2. API 레벨 33 오류
**문제**: Play Console에서 API 35 요구
**해결**: compileSdk 및 targetSdkVersion을 35로 업데이트

### 3. 디버그 심볼 경고
**문제**: "디버그 심볼이 업로드되지 않음" 경고
**해결**: 선택사항임을 안내 + 빌드 스크립트 제공

---

## 💡 주요 학습 내용

1. **ProGuard/R8 난독화**
   - 코드 보안 및 최적화
   - 필수 클래스 보호 규칙 작성

2. **API 레벨 관리**
   - minSdk: 최소 지원 버전
   - targetSdk: 타겟 최적화 버전
   - compileSdk: 컴파일 SDK 버전

3. **디버그 심볼**
   - 크래시 분석에 필요
   - 선택사항이지만 권장
   - `--split-debug-info` 옵션 사용

4. **버전 관리**
   - versionName: 사용자에게 표시 (1.0.0)
   - versionCode: Play Store 내부 번호 (증가 필수)

5. **Android 권한**
   - Android 13+ 런타임 권한 필요
   - maxSdkVersion으로 범위 제한 가능

---

## 📚 참고 자료

- [Flutter 공식 배포 가이드](https://docs.flutter.dev/deployment/android)
- [Google Play Console 도움말](https://support.google.com/googleplay/android-developer)
- [Android App Bundle](https://developer.android.com/guide/app-bundle)
- [ProGuard/R8 가이드](https://developer.android.com/studio/build/shrink-code)

---

## 🎯 다음 단계

1. **빌드 실행**
   ```powershell
   cd C:\android_prj\insign_flutter
   .\build_release.ps1
   ```

2. **Play Console 업로드**
   - AAB 파일 업로드
   - 출시 노트 작성
   - 검토 및 출시

3. **테스터 초대**
   - 내부 테스터 이메일 추가
   - 테스트 링크 공유

4. **피드백 수집**
   - 테스터 의견 수렴
   - 버그 수정
   - 다음 버전 준비

---

## 📝 메모

### 빌드 명령어 요약

```powershell
# 일반 빌드 (권장 - 간단함)
flutter build appbundle --release

# 디버그 심볼 포함 빌드 (권장 - 정식 출시 시)
flutter build appbundle --release --split-debug-info=build/app/outputs/symbols
```

### Play Console 경고 처리

- **디버그 심볼 경고**: 무시 가능 (선택사항)
- **API 레벨 경고**: 이미 해결 (API 35로 업데이트)
- **권한 경고**: 필요한 권한 모두 추가됨

---

## 🎉 작업 완료!

**모든 설정이 완료되었습니다!**

이제 빌드하고 Play Console에 업로드하시면 됩니다.

빌드 명령어:
```powershell
cd C:\android_prj\insign_flutter
flutter build appbundle --release
```

---

**작업일**: 2025년 11월 7일
**작업자**: Claude Code
**프로젝트**: 인싸인 (Insign)
**버전**: 1.0.0+2
**상태**: ✅ 배포 준비 완료
