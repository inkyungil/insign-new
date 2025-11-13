# Google Play Store 배포 가이드

이 문서는 인싸인(Insign) Flutter 앱을 Google Play Store에 배포하기 위한 완전한 가이드입니다.

## 📋 목차

1. [사전 준비](#사전-준비)
2. [버전 관리](#버전-관리)
3. [빌드 설정 확인](#빌드-설정-확인)
4. [Release APK/AAB 빌드](#release-apkaab-빌드)
5. [Play Console 업로드](#play-console-업로드)
6. [배포 체크리스트](#배포-체크리스트)
7. [문제 해결](#문제-해결)

---

## 사전 준비

### 1. Google Play Console 계정
- Google Play Console 계정 생성: https://play.google.com/console
- 개발자 등록비 $25 (일회성)
- 앱 등록 및 설정 완료

### 2. 필수 파일 확인
```bash
android/key.properties          # 키스토어 정보
android/keystores/release.keystore  # 릴리스 키스토어 파일
android/app/google-services.json    # Firebase 설정
```

### 3. 현재 키스토어 정보
```
Store Password: insign1004
Key Password: insign1004
Key Alias: insign-release
Store File: keystores/release.keystore
```

⚠️ **중요**: 키스토어 파일과 비밀번호는 절대 분실하지 마세요! 분실 시 앱 업데이트가 불가능합니다.

---

## 버전 관리

### pubspec.yaml에서 버전 업데이트

```yaml
# pubspec.yaml
version: 1.0.0+1
#        ↑     ↑
#   versionName versionCode
```

- **versionName** (1.0.0): 사용자에게 표시되는 버전 (Semantic Versioning)
- **versionCode** (1): Google Play가 사용하는 내부 버전 번호 (항상 증가해야 함)

### 버전 증가 규칙

```bash
# 업데이트 시마다 versionCode를 1씩 증가
1.0.0+1  →  1.0.0+2  # 버그 수정
1.0.0+2  →  1.0.1+3  # 마이너 업데이트
1.0.1+3  →  1.1.0+4  # 기능 추가
1.1.0+4  →  2.0.0+5  # 메이저 업데이트
```

---

## 빌드 설정 확인

### 현재 build.gradle 설정 (이미 완료됨)

✅ **서명 설정**
```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile file(keystoreProperties['storeFile'])
        storePassword keystoreProperties['storePassword']
    }
}
```

✅ **ProGuard/R8 최적화**
```gradle
buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled true        // 코드 난독화
        shrinkResources true      // 리소스 최적화
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

✅ **ProGuard 규칙 파일**
- `android/app/proguard-rules.pro` - Flutter, Firebase, Kakao SDK 규칙 포함

---

## Release APK/AAB 빌드

### 1. 빌드 전 체크리스트

```bash
# 1. 의존성 최신화
cd insign_flutter
flutter pub get

# 2. 코드 분석 (오류 확인)
flutter analyze

# 3. 테스트 실행
flutter test

# 4. 빌드 캐시 정리 (선택사항)
flutter clean
flutter pub get
```

### 2. App Bundle 빌드 (권장)

**App Bundle은 Play Store의 동적 전달 시스템을 활용하여 APK 크기를 최적화합니다.**

```bash
# App Bundle 빌드 (권장)
flutter build appbundle --release

# 빌드 결과 위치
# build/app/outputs/bundle/release/app-release.aab
```

### 3. APK 빌드 (직접 배포용)

```bash
# Release APK 빌드
flutter build apk --release

# Split APK 빌드 (ABI별 APK 생성 - 크기 최적화)
flutter build apk --split-per-abi --release

# 빌드 결과 위치
# build/app/outputs/flutter-apk/app-release.apk
# build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# build/app/outputs/flutter-apk/app-x86_64-release.apk
```

### 4. 빌드 파일 크기 확인

```bash
# App Bundle 크기 확인
ls -lh build/app/outputs/bundle/release/app-release.aab

# APK 크기 확인
ls -lh build/app/outputs/flutter-apk/*.apk
```

---

## Play Console 업로드

### 1. 첫 배포 (새 앱 등록)

1. **Play Console 접속**: https://play.google.com/console
2. **앱 만들기** 클릭
3. **앱 세부정보 입력**:
   - 앱 이름: `인싸인`
   - 기본 언어: 한국어
   - 앱 유형: 앱
   - 무료/유료: 무료

4. **스토어 등록정보 작성**:
   - 간단한 설명 (80자 이내)
   - 자세한 설명 (4000자 이내)
   - 스크린샷 (필수):
     - 휴대전화: 최소 2개 (권장: 8개)
     - 7인치 태블릿: 선택사항
     - 10인치 태블릿: 선택사항
   - 앱 아이콘: 512x512 PNG (32비트)
   - 기능 그래픽: 1024x500 JPG/PNG

5. **콘텐츠 등급 설정**:
   - 설문조사 작성
   - 앱의 콘텐츠에 따라 등급 자동 산정

6. **대상 고객 및 콘텐츠**:
   - 대상 연령: 선택
   - 개인정보처리방침 URL: 필수

7. **앱 액세스 권한**:
   - 특별한 액세스 요구사항이 있는 경우 설명

### 2. 프로덕션 트랙에 업로드

```
Play Console → 앱 → 프로덕션 → 새 버전 만들기
```

1. **App Bundle 업로드**:
   - `build/app/outputs/bundle/release/app-release.aab` 드래그 앤 드롭

2. **버전 이름 및 출시 노트 작성**:
   ```
   버전 이름: 1.0.0

   출시 노트 (한국어):
   - 인싸인 앱의 첫 번째 공식 버전입니다.
   - 전자 계약서 작성 및 관리
   - 디지털 서명 기능
   - Google 및 Kakao 소셜 로그인
   ```

3. **검토 후 출시**

### 3. 내부 테스트/비공개 테스트 트랙

실제 프로덕션 배포 전에 테스트를 권장합니다:

```
Play Console → 테스트 → 내부 테스트 → 새 버전 만들기
```

- **내부 테스트**: 최대 100명의 테스터, 즉시 배포
- **비공개 테스트**: 선택한 테스터 그룹, 몇 시간 내 배포
- **공개 테스트**: 누구나 참여 가능

---

## 배포 체크리스트

### 빌드 전

- [ ] `pubspec.yaml`에서 버전 업데이트 (versionCode 증가)
- [ ] `flutter analyze` 실행하여 오류 확인
- [ ] `flutter test` 실행하여 테스트 통과
- [ ] API 엔드포인트가 프로덕션 서버로 설정되어 있는지 확인
- [ ] 디버그 로그 및 테스트 코드 제거
- [ ] Firebase 프로젝트 설정 확인

### Play Console 설정

- [ ] 앱 이름, 설명, 아이콘 준비
- [ ] 스크린샷 준비 (최소 2개, 권장 8개)
- [ ] 개인정보처리방침 URL 준비
- [ ] 콘텐츠 등급 설문조사 완료
- [ ] 앱 카테고리 선택
- [ ] 연락처 정보 입력

### 법적 요구사항

- [ ] 개인정보처리방침 페이지 작성 및 공개
- [ ] 이용약관 페이지 작성 및 공개
- [ ] 데이터 보안 섹션 작성 (Play Console)
- [ ] 앱에서 수집하는 데이터 유형 선언

### 빌드 및 업로드

- [ ] `flutter build appbundle --release` 실행
- [ ] AAB 파일 Play Console에 업로드
- [ ] 출시 노트 작성 (한국어)
- [ ] 검토 및 출시 요청

---

## 문제 해결

### 1. 서명 오류

**오류**: `Execution failed for task ':app:validateSigningRelease'`

**해결**:
```bash
# key.properties 파일 확인
cat android/key.properties

# 키스토어 파일 경로 확인
ls -la android/keystores/release.keystore
```

### 2. ProGuard 오류

**오류**: 난독화 후 앱이 크래시

**해결**:
```bash
# proguard-rules.pro에 규칙 추가
# 특정 클래스 예외 처리
-keep class your.package.name.** { *; }
```

### 3. MultiDex 오류

**오류**: `Cannot fit requested classes in a single dex file`

**해결**: 이미 설정되어 있음
```gradle
defaultConfig {
    multiDexEnabled true
}
dependencies {
    implementation 'androidx.multidex:multidex:2.0.1'
}
```

### 4. 버전 충돌

**오류**: `Version code 1 has already been used`

**해결**:
```yaml
# pubspec.yaml에서 versionCode 증가
version: 1.0.0+2  # +1 → +2로 변경
```

### 5. Firebase 오류

**오류**: `google-services.json not found`

**해결**:
```bash
# 파일 존재 확인
ls android/app/google-services.json

# Firebase Console에서 다시 다운로드
# https://console.firebase.google.com/
```

---

## 추가 최적화 팁

### 1. APK 크기 줄이기

```bash
# Split APK로 빌드 (ABI별 분리)
flutter build apk --split-per-abi --release

# 결과: 각 아키텍처별로 최적화된 APK 생성
# - armeabi-v7a: 32비트 ARM
# - arm64-v8a: 64비트 ARM (대부분의 최신 기기)
# - x86_64: Intel 기반 기기
```

### 2. 빌드 시간 단축

```bash
# Gradle 캐시 활용 (gradle.properties에 이미 설정됨)
org.gradle.caching=true
org.gradle.parallel=true

# 전체 리빌드 필요 시
flutter clean && flutter pub get && flutter build appbundle --release
```

### 3. 네이티브 라이브러리 최적화

이미 `build.gradle`에 설정됨:
```gradle
ndk {
    debugSymbolLevel 'SYMBOL_TABLE'
}
```

---

## 유용한 명령어

```bash
# 버전 확인
flutter --version

# 연결된 기기 확인
flutter devices

# Release 모드로 실행 (테스트)
flutter run --release

# 빌드 캐시 삭제
flutter clean

# Gradle 캐시 삭제
cd android && ./gradlew clean && cd ..

# APK 분석
flutter build apk --analyze-size

# 디버그 심볼 생성
flutter build apk --release --split-debug-info=build/app/outputs/symbols
```

---

## 참고 자료

- [Flutter 공식 배포 가이드](https://docs.flutter.dev/deployment/android)
- [Google Play Console 도움말](https://support.google.com/googleplay/android-developer)
- [Android App Bundle](https://developer.android.com/guide/app-bundle)
- [ProGuard/R8 가이드](https://developer.android.com/studio/build/shrink-code)

---

## 지원

문제가 발생하면:
1. 이 문서의 "문제 해결" 섹션 확인
2. `ANDROID_KEYSTORE_SETUP.md` 참고
3. Flutter 공식 문서 확인
4. GitHub Issues에 문의

---

**최종 업데이트**: 2025-11-07
**앱 버전**: 1.0.0
**문서 버전**: 1.0
