# API 레벨 35 업데이트 변경사항

## 📅 업데이트 날짜: 2025-11-07

## 🎯 변경 이유
Google Play Console에서 요구하는 최신 API 레벨 적용
- 기존: API 33 (Android 13)
- 변경: API 35 (Android 15)

---

## ✅ 변경된 파일

### 1. android/app/build.gradle
```gradle
android {
    compileSdk 35  // 변경: flutter.compileSdkVersion → 35

    defaultConfig {
        minSdkVersion 21  // 유지 (Android 5.0)
        targetSdkVersion 35  // 변경: flutter.targetSdkVersion → 35
    }
}
```

### 2. android/app/src/main/AndroidManifest.xml
추가된 권한:
```xml
<!-- 인터넷 권한 -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- 파일 접근 권한 (PDF 생성 및 file_picker) -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />

<!-- Android 13+ 미디어 접근 권한 -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
```

### 3. pubspec.yaml
```yaml
version: 1.0.0+2  # 변경: 1.0.0+1 → 1.0.0+2
```

---

## 🔄 호환성

| 항목 | 값 |
|------|-----|
| 최소 지원 버전 | Android 5.0 (API 21) |
| 타겟 버전 | Android 15 (API 35) |
| 컴파일 SDK | 35 |

---

## 📝 권한 설명

### 필수 권한
1. **INTERNET** - API 통신
2. **POST_NOTIFICATIONS** - 푸시 알림 (Android 13+)

### 파일 접근 권한
1. **READ_EXTERNAL_STORAGE** - 파일 읽기 (Android 12 이하)
2. **WRITE_EXTERNAL_STORAGE** - 파일 쓰기 (Android 12 이하)
3. **READ_MEDIA_IMAGES** - 이미지 접근 (Android 13+)
4. **READ_MEDIA_VIDEO** - 비디오 접근 (Android 13+)

---

## 🚀 다음 단계

1. **빌드 정리**
   ```powershell
   flutter clean
   flutter pub get
   ```

2. **새 App Bundle 빌드**
   ```powershell
   flutter build appbundle --release
   ```

3. **Play Console 업로드**
   - 기존 버전 삭제 또는 교체
   - 새 AAB 파일 업로드 (버전 코드 2)

---

## ⚠️ 주의사항

1. **버전 코드 관리**
   - 이전: 1
   - 현재: 2
   - 다음 업로드 시: 3 이상 필수

2. **기기 호환성**
   - Android 5.0 ~ 15 지원
   - 대부분의 기기에서 정상 동작

3. **권한 요청**
   - Android 13+ 기기는 알림 권한 런타임 요청
   - 파일 접근 시 적절한 권한 요청 필요

---

**업데이트 완료**: 2025-11-07
**버전**: 1.0.0+2
**API 레벨**: 35 (Android 15)
