# 디버그 심볼 업로드 가이드

## 📌 디버그 심볼이란?

디버그 심볼(Debug Symbols)은 네이티브 코드(C/C++)의 크래시를 분석하기 위한 파일입니다.

### 💡 왜 필요한가요?

| 심볼 없음 | 심볼 있음 |
|----------|----------|
| `#00 pc 0x00012345` | `MyClass::doSomething() at file.cpp:123` |
| 알 수 없는 메모리 주소 | 정확한 파일과 줄 번호 |

**결론**: 심볼 파일이 있으면 크래시 위치를 정확히 알 수 있습니다!

---

## ⚖️ 업로드 해야 할까요?

### ✅ 업로드 권장 (선택사항)

**장점**:
- 🐛 크래시 리포트에서 정확한 코드 위치 확인
- 📊 ANR(응답 없음) 문제 디버깅 용이
- 🔍 네이티브 코드 오류 추적 가능
- 📈 Play Console에서 더 상세한 분석 제공

**단점**:
- 파일 크기 약간 증가 (보통 몇 MB)
- 빌드 시간 약간 증가 (몇 초)

### 🎯 권장사항

- **첫 배포**: 선택사항 (나중에도 업로드 가능)
- **정식 출시 후**: 강력 권장 (사용자 크래시 분석 필요)

---

## 🚀 두 가지 방법

### 방법 1: 현재 AAB 그대로 업로드 (빠름)

**지금 상황에 적합합니다!**

1. ✅ 현재 빌드한 AAB를 Play Console에 업로드
2. ⚠️ "디버그 심볼 없음" 경고는 무시 (선택사항이므로 괜찮음)
3. 나중에 필요하면 심볼만 따로 업로드 가능

**장점**: 바로 테스트 시작 가능
**단점**: 크래시 발생 시 분석 어려움

---

### 방법 2: 디버그 심볼 포함 재빌드 (권장)

**더 나은 크래시 분석을 원한다면!**

#### Step 1: 디버그 심볼 포함 빌드

**PowerShell에서 실행**:
```powershell
cd C:\android_prj\insign_flutter

# 디버그 심볼 포함 빌드 스크립트 실행
.\build_with_symbols.ps1
```

또는 **직접 명령어**:
```powershell
# 캐시 정리
flutter clean
flutter pub get

# 디버그 심볼 포함 빌드
flutter build appbundle --release --split-debug-info=build/app/outputs/symbols
```

#### Step 2: 생성되는 파일

```
build/app/outputs/
├── bundle/release/
│   └── app-release.aab          ← Play Console에 업로드
└── symbols/
    └── app.android-arm64.symbols  ← 디버그 심볼 (ZIP으로 압축)
```

#### Step 3: Play Console 업로드

1. **App Bundle 업로드**
   - `build/app/outputs/bundle/release/app-release.aab` 업로드

2. **디버그 심볼 업로드** (AAB 업로드 후)
   ```
   Play Console → 버전 선택 → 아티팩트 탭
   → "네이티브 디버그 심볼" 섹션
   → symbols 폴더를 ZIP으로 압축하여 업로드
   ```

---

## 📦 디버그 심볼 ZIP 파일 만들기

### Windows 탐색기에서:

1. `build\app\outputs\symbols` 폴더 열기
2. 폴더 안의 **모든 파일** 선택
3. 마우스 우클릭 → **"압축(ZIP) 폴더로 보내기"**
4. `symbols.zip` 파일 생성됨

### PowerShell에서:

```powershell
# symbols 폴더를 ZIP으로 압축
Compress-Archive -Path "build\app\outputs\symbols\*" -DestinationPath "build\app\outputs\symbols.zip"
```

---

## 🎯 Play Console 업로드 상세 가이드

### 1. App Bundle 업로드

```
Play Console → 앱 선택 → 테스트 → 내부 테스트
→ 새 버전 만들기
→ app-release.aab 드래그 앤 드롭
```

### 2. 디버그 심볼 업로드

AAB 업로드 후:

```
같은 화면에서 아래로 스크롤
→ "아티팩트" 섹션 찾기
→ "네이티브 디버그 심볼" 클릭
→ "심볼 파일 업로드" 버튼
→ symbols.zip 파일 선택
→ 업로드
```

**스크린샷 위치**:
```
┌─────────────────────────────────┐
│ 새 버전 만들기                    │
├─────────────────────────────────┤
│ App Bundle                       │
│ ✓ app-release.aab (25.3 MB)     │
│                                  │
│ 아티팩트 ▼                       │
│   네이티브 디버그 심볼            │
│   [ 심볼 파일 업로드 ]           │  ← 여기!
│                                  │
│ 출시 노트                         │
│ ...                              │
└─────────────────────────────────┘
```

---

## ❓ FAQ

### Q1: 심볼 없이 업로드하면 어떻게 되나요?
**A**: 앱은 정상 작동합니다. 다만 크래시 발생 시 정확한 위치를 찾기 어렵습니다.

### Q2: 나중에 추가할 수 있나요?
**A**: 네! 언제든지 Play Console에서 해당 버전에 심볼을 추가 업로드할 수 있습니다.

### Q3: 심볼 파일을 분실하면?
**A**: 같은 버전 코드로 다시 빌드하면 됩니다. 하지만 보관하는 것이 좋습니다.

### Q4: 파일 크기가 얼마나 되나요?
**A**: 보통 5-20MB 정도입니다 (프로젝트 크기에 따라 다름).

### Q5: 테스트 버전에도 필요한가요?
**A**: 선택사항입니다. 정식 출시 시에는 강력 권장합니다.

---

## 📊 비교표

| 항목 | 심볼 없음 | 심볼 있음 |
|------|----------|----------|
| 빌드 시간 | 빠름 | 약간 느림 (+10초) |
| 파일 크기 | 작음 | 약간 큼 (+5-20MB) |
| 크래시 분석 | 어려움 | 쉬움 |
| ANR 디버깅 | 어려움 | 쉬움 |
| 권장도 | ⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## 🎯 최종 추천

### 지금 (내부 테스트)
**심볼 없이 먼저 업로드하세요!**
- 빠르게 테스트 시작
- 경고는 무시해도 됨
- 나중에 추가 가능

### 나중에 (정식 출시)
**디버그 심볼 포함 빌드 필수!**
- 사용자 크래시 분석 필요
- 품질 향상에 중요

---

## 📝 명령어 요약

### 일반 빌드 (심볼 없음)
```powershell
flutter build appbundle --release
```

### 심볼 포함 빌드 (권장)
```powershell
flutter build appbundle --release --split-debug-info=build/app/outputs/symbols
```

### 빌드 스크립트 사용
```powershell
# 심볼 포함
.\build_with_symbols.ps1

# 일반 빌드
.\build_release.ps1
```

---

**작성일**: 2025-11-07
**앱**: 인싸인 (Insign)
**버전**: 1.0.0+2
