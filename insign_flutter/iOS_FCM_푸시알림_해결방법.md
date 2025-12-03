# iOS FCM 푸시 알림 빌드 오류 해결 방법

## 문제 상황
- iOS 빌드 시 firebase_messaging에서 non-modular header 오류 발생
- 오류 메시지: `Include of non-modular header inside framework module 'firebase_messaging.FLTFirebaseMessagingPlugin'`

## 해결 방법

### 1. Firebase 패키지 최신 버전으로 업그레이드

**pubspec.yaml 수정:**
```yaml
# Firebase / Push
firebase_core: ^4.0.0  # 2.24.2 → 4.2.1
firebase_messaging: ^16.0.0  # 14.7.10 → 16.0.4
flutter_local_notifications: ^17.1.0
```

**실행:**
```bash
flutter pub get
```

### 2. iOS 최소 버전을 15.0으로 상향

**이유:** Firebase SDK 12.4.0부터 iOS 15.0 이상 필요

**ios/Podfile 수정:**
```ruby
# 변경 전
platform :ios, '13.0'

# 변경 후
platform :ios, '15.0'
```

**post_install 섹션도 수정:**
```ruby
target.build_configurations.each do |config|
  # 변경 전
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'

  # 변경 후
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'

  # Firebase 관련 설정 (이미 있음)
  config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
end
```

### 3. iOS Pods 재설치

```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
```

### 4. Flutter 클린 빌드

```bash
flutter clean
flutter pub get
flutter build ios --no-codesign
```

## 결과

✅ **iOS 빌드 성공!**
```
✓ Built build/ios/iphoneos/Runner.app (33.9MB)
```

✅ **Android와 iOS 모두 FCM 푸시 알림 작동**

## 변경된 버전 정보

| 패키지 | 이전 버전 | 업데이트 후 |
|--------|----------|-------------|
| firebase_core | 2.24.2 | 4.2.1 |
| firebase_messaging | 14.7.10 | 16.0.4 |
| Firebase iOS SDK | 10.18.0 | 12.4.0 |
| iOS 최소 버전 | 13.0 | 15.0 |

## 핵심 포인트

1. **firebase_messaging 16.0.4**에서 modular import 방식(`@import FirebaseMessaging;`)을 사용하여 non-modular header 문제 해결
2. **Firebase SDK 12.4.0**은 iOS 15.0 이상 필요
3. Podfile 설정에서 `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES = YES` 유지

## Info.plist 설정 (이미 적용됨)

`ios/Runner/Info.plist`에 푸시 알림 권한 추가:

```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

## 테스트 방법

1. **Android 빌드 테스트:**
   ```bash
   flutter build apk
   ```

2. **iOS 빌드 테스트:**
   ```bash
   flutter build ios --no-codesign
   ```

3. **실제 디바이스에서 푸시 알림 테스트:**
   - 앱 실행
   - FCM 토큰 등록 확인 (로그 확인)
   - Firebase Console에서 테스트 메시지 전송

## 주의사항

- iOS 15.0 미만 기기는 지원하지 않음
- 기존 사용자는 iOS 업데이트 필요 (iOS 15는 2021년 9월 출시)
- App Store 배포 시 최소 지원 버전이 iOS 15.0으로 표시됨

## 작업 일시

- 날짜: 2025-12-02
- 작업 시간: 약 1시간
- 최종 상태: ✅ 성공

## 참고 파일

- `lib/main.dart` - PushNotificationService.initialize() 호출
- `lib/services/push_notification_service.dart` - FCM 초기화 로직
- `lib/services/local_notification_service.dart` - 로컬 알림 처리
- `ios/Runner/GoogleService-Info.plist` - Firebase 설정
- `ios/Podfile` - iOS 의존성 관리
