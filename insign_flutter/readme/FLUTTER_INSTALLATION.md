# Flutter 설치 및 실행 가이드

## ✅ Flutter SDK 설치 완료

Flutter 3.24.5가 `/opt/flutter`에 설치되었습니다.

### 설치된 구성 요소
- **Flutter SDK**: 3.24.5
- **Dart**: 3.5.4
- **DevTools**: 2.37.3
- **Web Support**: 활성화됨

---

## 🚀 Flutter 웹 서버 실행 방법

### 방법 1: 스크립트 사용 (간편)

```bash
# 프로젝트 루트에서
/home/insign/start_flutter_web.sh
```

### 방법 2: 직접 명령어 실행

```bash
cd /home/insign/insign_flutter
export PATH="$PATH:/opt/flutter/bin"
flutter run -d web-server --web-port=8082 --web-hostname=0.0.0.0
```

**접속 URL**:
- 로컬: `http://localhost:8082`
- 외부: `http://in-sign.shop:8082`

---

## 🛠️ 유용한 명령어

### Flutter 버전 확인
```bash
export PATH="$PATH:/opt/flutter/bin"
flutter --version
```

### 의존성 설치
```bash
cd /home/insign/insign_flutter
export PATH="$PATH:/opt/flutter/bin"
flutter pub get
```

### 프로덕션 빌드
```bash
cd /home/insign/insign_flutter
export PATH="$PATH:/opt/flutter/bin"
flutter build web --release
```

빌드 결과: `build/web/`

### 코드 분석
```bash
flutter analyze
```

### 테스트 실행
```bash
flutter test
```

---

## 🔧 PATH 설정

현재 세션에서만 사용 (재부팅 시 초기화):
```bash
export PATH="$PATH:/opt/flutter/bin"
```

영구적으로 설정 (이미 ~/.bashrc에 추가됨):
```bash
# 새 터미널을 열거나 다음 명령어 실행
source ~/.bashrc
```

---

## ⚠️ 주의사항

### Root 권한 경고
Flutter를 root로 실행하면 경고가 표시되지만 서버 환경에서는 정상 작동합니다:
```
Woah! You appear to be trying to run flutter as root.
We strongly recommend running the flutter tool without superuser privileges.
```

이 경고는 무시해도 됩니다.

### 방화벽 설정
외부에서 접속하려면 8082 포트를 열어야 합니다:
```bash
# Ubuntu UFW
sudo ufw allow 8082/tcp

# iptables
sudo iptables -A INPUT -p tcp --dport 8082 -j ACCEPT
```

---

## 📦 프로덕션 배포

### 정적 파일로 빌드
```bash
flutter build web --release
```

### Nginx로 서빙
```nginx
server {
    listen 80;
    server_name in-sign.shop;

    location /app {
        alias /home/insign/insign_flutter/build/web;
        try_files $uri $uri/ /index.html;
    }
}
```

---

## 🐛 문제 해결

### "Command not found: flutter"
```bash
export PATH="$PATH:/opt/flutter/bin"
```

### 의존성 오류
```bash
flutter clean
flutter pub get
```

### 포트 충돌
```bash
# 8082 포트 사용 중인 프로세스 확인
lsof -i :8082
# 또는
netstat -tlnp | grep 8082

# 프로세스 종료
kill -9 <PID>
```

### Hot Reload 문제
```bash
flutter clean
rm -rf build/
flutter pub get
flutter run -d web-server --web-port=8082 --web-hostname=0.0.0.0
```

---

## 📚 참고

- Flutter 공식 문서: https://flutter.dev/docs
- Flutter Web: https://flutter.dev/web
- Dart 문서: https://dart.dev/guides

---

## 시스템 정보

- **OS**: Ubuntu 24.04.3 LTS
- **Architecture**: x86_64
- **Flutter 설치 경로**: `/opt/flutter`
- **프로젝트 경로**: `/home/insign/insign_flutter`
