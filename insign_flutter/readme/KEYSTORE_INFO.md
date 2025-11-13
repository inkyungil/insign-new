# Android Keystore 인증서 정보

생성일: 2025-11-03

## 📁 파일 위치

```
insign_flutter/android/app/keystores/
├── debug.keystore    (개발용)
└── release.keystore  (프로덕션 배포용)
```

## 🔐 인증서 정보

### Debug Keystore (개발/테스트용)

**파일 경로**: `android/app/keystores/debug.keystore`

**Keystore 정보**:
- Alias: `androiddebugkey`
- Store Password: `android`
- Key Password: `android`
- Validity: 10,000 days

**인증서 지문**:
- **SHA-1**: `A8:CD:67:98:1A:F4:77:69:DC:D0:C3:EE:8B:F7:28:E4:CE:94:7C:72`
- **SHA-256**: `9B:22:69:48:74:F5:9E:52:47:D4:AA:A6:F4:69:D8:E1:05:BA:9A:4B:78:95:07:ED:91:25:DF:91:B3:C2:90:37`

**Kakao Key Hash**: `qM1nmBr0d2nc0MPui/co5M6UfHI=`

---

### Release Keystore (프로덕션 배포용)

**파일 경로**: `android/app/keystores/release.keystore`

**Keystore 정보**:
- Alias: `insign-release`
- Store Password: `!@#insign1004`
- Key Password: `!@#insign1004`
- Validity: 10,000 days
- DN: `CN=InSign, OU=Mobile, O=InSign, L=Seoul, ST=Seoul, C=KR`

**인증서 지문**:
- **SHA-1**: `E9:5C:90:0D:39:55:AB:D1:69:E0:5E:18:B5:F3:E5:1A:29:B0:7C:49`
- **SHA-256**: `D5:B5:FC:41:30:E6:85:AE:50:50:5E:44:DD:AF:5D:9D:17:29:96:9D:1D:4E:9D:D0:CD:88:91:0C:70:89:D6:88`

**Kakao Key Hash**: `6VyQDTlVq9Fp4F4YtfPlGimwfEk=`

---

## 📝 등록 정보

### Google Cloud Console 등록

1. [Google Cloud Console](https://console.cloud.google.com/) 접속
2. 프로젝트: **insign-prj** 선택
3. **API 및 서비스** → **사용자 인증 정보**
4. Android OAuth 2.0 클라이언트 ID 설정:

**개발용 (Debug)**:
- 패키지 이름: `app.insign`
- SHA-1 인증서 지문: `A8:CD:67:98:1A:F4:77:69:DC:D0:C3:EE:8B:F7:28:E4:CE:94:7C:72`

**프로덕션용 (Release)**:
- 패키지 이름: `app.insign`
- SHA-1 인증서 지문: `E9:5C:90:0D:39:55:AB:D1:69:E0:5E:18:B5:F3:E5:1A:29:B0:7C:49`

### Kakao Developers 등록

1. [Kakao Developers](https://developers.kakao.com/) 접속
2. 애플리케이션 선택
3. **플랫폼 설정** → **Android 플랫폼**

**개발용 (Debug)**:
- 패키지 이름: `app.insign`
- 키 해시: `qM1nmBr0d2nc0MPui/co5M6UfHI=`

**프로덕션용 (Release)**:
- 패키지 이름: `app.insign`
- 키 해시: `6VyQDTlVq9Fp4F4YtfPlGimwfEk=`

---

## 🛠️ 빌드 설정

### key.properties

파일 위치: `android/key.properties`

```properties
storePassword=!@#insign1004
keyPassword=!@#insign1004
keyAlias=insign-release
storeFile=keystores/release.keystore
```

### build.gradle 설정 완료

Release 빌드 시 자동으로 `release.keystore`를 사용하도록 설정되어 있습니다.

---

## 📱 빌드 명령어

### Debug 빌드
```bash
flutter build apk --debug
# 또는
flutter run
```

### Release 빌드
```bash
# APK 생성
flutter build apk --release

# App Bundle 생성 (Google Play 배포용)
flutter build appbundle --release
```

---

## 🔍 인증서 확인 명령어

### SHA-1 확인

**Debug**:
```bash
keytool -list -v \
  -keystore android/app/keystores/debug.keystore \
  -alias androiddebugkey \
  -storepass android \
  -keypass android
```

**Release**:
```bash
keytool -list -v \
  -keystore android/app/keystores/release.keystore \
  -alias insign-release \
  -storepass '!@#insign1004' \
  -keypass '!@#insign1004'
```

### Kakao Key Hash 확인

**Debug**:
```bash
keytool -exportcert \
  -alias androiddebugkey \
  -keystore android/app/keystores/debug.keystore \
  -storepass android | \
openssl sha1 -binary | openssl base64
```

**Release**:
```bash
keytool -exportcert \
  -alias insign-release \
  -keystore android/app/keystores/release.keystore \
  -storepass '!@#insign1004' | \
openssl sha1 -binary | openssl base64
```

---

## ⚠️ 보안 주의사항

1. **절대 공개하지 말 것**:
   - `release.keystore` 파일
   - `key.properties` 파일
   - Keystore 비밀번호

2. **Git에서 제외됨**:
   - `.gitignore`에 `key.properties` 및 `**/*.keystore` 추가됨
   - Keystore 파일은 버전 관리에서 제외됨

3. **백업 필수**:
   - `release.keystore` 파일을 안전한 곳에 백업
   - 분실 시 앱 업데이트 불가능!

4. **팀원 공유**:
   - 안전한 방법으로 팀원에게 공유 (1Password, LastPass 등)
   - 이메일이나 채팅으로 전송 금지

---

## 📞 문제 해결

### Gradle 빌드 오류 발생 시

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

### SHA-1이 Google/Kakao에 등록되지 않을 때

- 빌드한 APK의 서명 확인:
```bash
# APK 서명 확인
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk
```

### Keystore 비밀번호 분실 시

- **Release keystore 비밀번호 분실 시**: 복구 불가능, 새로 생성 필요
- **기존 앱이 Play Store에 배포된 경우**: 새로운 패키지명으로 재배포 필요
- **반드시 안전한 곳에 백업하세요!**
