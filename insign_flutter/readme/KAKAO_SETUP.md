# 카카오 로그인 설정 가이드

## 1. 카카오 개발자 계정 설정

1. [Kakao Developers](https://developers.kakao.com/) 접속
2. 애플리케이션 생성
3. 플랫폼 설정 (Android, iOS, Web)
4. 앱 키 확인

## 2. Android 설정

### AndroidManifest.xml 수정
- `kakao${YOUR_KAKAO_APP_KEY}` 부분을 실제 앱 키로 교체
- 예: `kakao6e0890d62b2c37446106b6f1ed9b4741`

### build.gradle 설정
```gradle
android {
    defaultConfig {
        manifestPlaceholders = [
            'kakaoAppKey': 'YOUR_KAKAO_APP_KEY'
        ]
    }
}
```

## 3. iOS 설정 (필요시)

### Info.plist 수정
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>kakao${YOUR_KAKAO_APP_KEY}</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>kakao${YOUR_KAKAO_APP_KEY}</string>
        </array>
    </dict>
</array>
```

## 4. 코드에서 앱 키 설정

### KakaoAuthService 수정
```dart
class KakaoAuthService {
  static const String _kakaoAppKey = '6e0890d62b2c37446106b6f1ed9b4741';
  // ... 나머지 코드
}
```

## 5. 테스트

1. `flutter pub get` 실행
2. 앱 실행
3. 카카오 로그인 버튼 클릭
4. 카카오톡 또는 카카오계정으로 로그인

## 주의사항

- 실제 앱 키는 보안을 위해 환경 변수나 설정 파일로 관리
- 카카오 개발자 콘솔에서 앱 상태를 "활성화"로 설정
- 테스트 시에는 카카오톡이 설치된 기기에서 테스트 권장
