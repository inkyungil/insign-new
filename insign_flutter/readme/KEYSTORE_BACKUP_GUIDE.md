# 키스토어 백업 가이드

## ⚠️ 매우 중요!

키스토어 파일과 비밀번호를 분실하면 Google Play Store에 앱 업데이트를 할 수 없습니다!

## 📦 백업해야 할 파일

1. **키스토어 파일**
   - `android/app/keystores/release.keystore`

2. **키스토어 정보 파일**
   - `android/key.properties`

3. **키스토어 정보 (텍스트)**
   ```
   Store Password: insign1004
   Key Password: insign1004
   Key Alias: insign-release
   Store File: keystores/release.keystore
   ```

## 💾 백업 방법

### 방법 1: 안전한 클라우드 저장소

1. **Google Drive / OneDrive / Dropbox**
   - 비공개 폴더에 저장
   - 2단계 인증 활성화

2. **암호화된 저장소**
   - VeraCrypt 등으로 암호화된 볼륨 사용

### 방법 2: USB 드라이브

1. 외장 하드 디스크 또는 USB에 저장
2. 안전한 장소에 보관
3. 최소 2개 이상의 백업 사본 유지

### 방법 3: 비밀번호 관리자

1. **1Password / LastPass / Bitwarden**
   - 키스토어 파일 첨부
   - 비밀번호 정보 저장

## 🔒 보안 수칙

- [ ] 키스토어 파일을 Git에 커밋하지 마세요
- [ ] 공개 저장소에 업로드하지 마세요
- [ ] 이메일로 전송하지 마세요
- [ ] 여러 곳에 백업하세요 (최소 2곳 이상)
- [ ] 주기적으로 백업 파일이 손상되지 않았는지 확인하세요

## 🆘 키스토어를 분실한 경우

### Play Store에 이미 배포한 경우

1. **앱 업데이트 불가능**
2. **해결 방법**:
   - 기존 앱 삭제 (사용자 피해 발생)
   - 새 패키지명으로 새 앱 등록
   - 사용자들에게 재설치 안내

### 아직 배포하지 않은 경우

1. **새 키스토어 생성**
2. **처음부터 다시 시작**

## 📋 백업 체크리스트

배포 전:
- [ ] release.keystore 파일 백업
- [ ] key.properties 파일 백업
- [ ] 비밀번호 정보 안전하게 기록
- [ ] 백업 파일 확인 (열리는지 테스트)
- [ ] 여러 장소에 백업 (클라우드 + USB)

배포 후:
- [ ] 최종 키스토어 백업 재확인
- [ ] SHA-1 fingerprint 기록
- [ ] Google Play Console에 등록된 인증서 확인

## 🔑 키스토어 정보 확인 명령어

```powershell
# 키스토어 정보 확인
keytool -list -v -keystore android\app\keystores\release.keystore -alias insign-release

# SHA-1 fingerprint 확인
keytool -list -v -keystore android\app\keystores\release.keystore -alias insign-release | findstr SHA1
```

---

**최종 업데이트**: 2025-11-07
**중요도**: 🔴 매우 높음
