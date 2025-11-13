# Flutter 포트 관리 가이드

## 포트 충돌 문제 해결

### 오류 메시지
```
SocketException: Failed to create server socket (OS Error: Address already in use, errno = 98), 
address = 0.0.0.0, port = 8082
```

이 오류는 8082 포트가 이미 다른 프로세스에서 사용 중일 때 발생합니다.

---

## 빠른 해결 방법

### 방법 1: 자동 스크립트 사용 (권장)

```bash
/home/insign/kill_flutter_port.sh
```

이 스크립트는:
- 8082 포트 사용 중인 프로세스 자동 찾기
- 해당 프로세스 종료
- 포트 해제 확인

### 방법 2: 수동으로 해결

```bash
# 1. 포트 사용 중인 프로세스 찾기
lsof -i :8082

# 2. PID 확인 후 종료
kill -9 <PID>

# 3. 포트 해제 확인
lsof -i :8082
```

---

## 실행 순서

### 정상 실행 절차

```bash
# 1. 포트 정리 (선택사항)
/home/insign/kill_flutter_port.sh

# 2. Flutter 웹 서버 시작
cd /home/insign/insign_flutter
export PATH="$PATH:/opt/flutter/bin"
flutter run -d web-server --web-port=8082 --web-hostname=0.0.0.0
```

또는 스크립트 사용:
```bash
/home/insign/start_flutter_web.sh
```

---

## 포트 확인 명령어

### 포트 사용 확인
```bash
lsof -i :8082
```

**출력 예시** (사용 중):
```
COMMAND      PID USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME
dart:flut 353105 root    9u  IPv4 4726485      0t0  TCP *:8082 (LISTEN)
```

**출력 예시** (비어있음):
```
(출력 없음 = 포트 사용 가능)
```

### 모든 Flutter 프로세스 확인
```bash
ps aux | grep flutter
```

### 모든 Flutter 프로세스 종료
```bash
pkill -f flutter
```

---

## 백그라운드 실행 관리

### 백그라운드로 실행
```bash
nohup flutter run -d web-server --web-port=8082 --web-hostname=0.0.0.0 > /tmp/flutter.log 2>&1 &
```

### 백그라운드 프로세스 확인
```bash
jobs
# 또는
ps aux | grep flutter
```

### 백그라운드 프로세스 종료
```bash
# 특정 job 종료
kill %1  # job 번호

# PID로 종료
kill -9 <PID>

# 모든 Flutter 프로세스 종료
pkill -9 -f flutter
```

---

## 자주 발생하는 시나리오

### 시나리오 1: Ctrl+C로 종료했지만 포트가 아직 사용 중
**원인**: 프로세스가 완전히 종료되지 않음

**해결**:
```bash
/home/insign/kill_flutter_port.sh
```

### 시나리오 2: 여러 터미널에서 실행 시도
**원인**: 이미 다른 터미널에서 Flutter 실행 중

**해결**:
```bash
# 모든 Flutter 프로세스 확인
ps aux | grep flutter

# 필요 없는 프로세스 종료
kill -9 <PID>
```

### 시나리오 3: 시스템 재부팅 후에도 포트 사용 중
**원인**: 시스템에 등록된 서비스가 포트 사용

**해결**:
```bash
# 포트 사용 중인 서비스 확인
sudo netstat -tlnp | grep 8082

# 또는
sudo ss -tlnp | grep 8082
```

---

## 포트 변경하기

다른 포트를 사용하고 싶다면:

```bash
# 예: 8090 포트 사용
flutter run -d web-server --web-port=8090 --web-hostname=0.0.0.0
```

**주의**: Backend CORS 설정도 변경해야 합니다:
```
nestjs_app/.env_local에 새 포트 추가
```

---

## 유용한 별칭 (Optional)

`~/.bashrc`에 추가하면 편리합니다:

```bash
# Flutter 포트 관리
alias flutter-kill="kill -9 \$(lsof -t -i :8082)"
alias flutter-check="lsof -i :8082"
alias flutter-start="flutter run -d web-server --web-port=8082 --web-hostname=0.0.0.0"
```

적용:
```bash
source ~/.bashrc
```

사용:
```bash
flutter-kill    # 포트 사용 프로세스 종료
flutter-check   # 포트 상태 확인
flutter-start   # Flutter 웹 시작
```

---

## 문제 해결 체크리스트

- [ ] 포트 8082가 사용 중인지 확인 (`lsof -i :8082`)
- [ ] 사용 중이면 프로세스 종료 (`kill -9 <PID>`)
- [ ] 포트 해제 확인 (`lsof -i :8082` 결과 없음)
- [ ] Flutter 실행 (`flutter run ...`)
- [ ] 브라우저에서 접속 테스트 (`http://localhost:8082`)

---

## 도움이 필요한 경우

1. **포트 충돌 지속**: 시스템 재부팅 고려
2. **권한 오류**: `sudo` 사용 (권장하지 않음, root로 실행 중)
3. **방화벽 문제**: `ufw allow 8082/tcp` 실행

