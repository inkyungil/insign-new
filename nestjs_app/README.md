# Insign NestJS Backend

NestJS 기반 API 서버와 관리자 포털을 위한 초기 프로젝트 템플릿입니다. `src` 디렉터리에는 인증/관리자 모듈이 포함되어 있으며, EJS 템플릿을 통해 간단한 관리자 UI를 렌더링합니다.

## 주요 기능

- Passport(Local) 기반 세션 로그인 및 로그아웃
- 관리자 대시보드 & 계정 관리 뷰(EJS)
- TypeORM(MySQL) 연결 준비 및 기본 Admin 엔티티
- Swagger 문서(`/docs`) 자동 구성
- ESLint/Prettier/Jest 설정 포함

## 폴더 구조

```
nestjs_app/
├─ src/
│  ├─ main.ts                # 앱 부트스트랩, 세션/Swagger/EJS 설정
│  ├─ app.module.ts          # 루트 모듈(TypeORM/Passport/Auth/Admin)
│  ├─ admin/                 # 관리자 모듈, 엔티티, 서비스, 컨트롤러
│  └─ auth/                  # 인증 모듈(로컬 전략, 세션 직렬화, 가드)
├─ views/                    # EJS 템플릿(login, admin/dashboard, admin/list)
├─ public/                   # 정적 자산(styles.css)
├─ package.json              # 의존성 및 npm 스크립트
├─ tsconfig*.json            # TypeScript 설정
├─ eslint.config.mjs         # ESLint 설정
└─ test/                     # 테스트 설정 (Jest)
```

## 빠른 시작

1. 의존성 설치
   ```bash
   npm install
   ```

2. 환경 변수 구성 (예: `.env`)
   ```bash
   PORT=8081
   DB_HOST=localhost
   DB_PORT=3306
   DB_USERNAME=root
   DB_PASSWORD=secret
   DB_NAME=insign
   SESSION_SECRET=change-me
   CONTRACT_POINTS_COST=3  # 계약 한도 초과 시 차감할 포인트 수
   DEFAULT_MONTHLY_CONTRACT_LIMIT=4  # 무료 계층 기본 월 계약 티켓 수
   DEFAULT_SIGNUP_POINTS=12  # 가입 시 기본 포인트
   DEFAULT_MONTHLY_POINTS_LIMIT=12  # 월 포인트 적립 한도
   ```

3. 개발 서버 실행
   ```bash
   npm run start:dev
   ```

   - 기본 관리자 계정은 `admin / admin1234`이며 최초 실행 시 자동 생성됩니다.
   - 브라우저에서 `http://localhost:8081/login`으로 접속해 로그인할 수 있습니다.

4. Swagger 문서 확인
   - `http://localhost:8081/docs`

환경 변수 참고:

- `CONTRACT_POINTS_COST`: 월 무료 한도를 모두 사용한 뒤 계약서를 1건 더 작성할 때 차감할 포인트 수(기본 3P).
- `DEFAULT_MONTHLY_CONTRACT_LIMIT`: 무료 구독 계층에 기본으로 부여되는 월 계약 티켓 수(기본 4개).
- `DEFAULT_SIGNUP_POINTS`: 새 사용자가 가입할 때 부여되는 기본 포인트(기본 12P).
- `DEFAULT_MONTHLY_POINTS_LIMIT`: 출석/광고 등으로 한 달 동안 적립할 수 있는 최대 포인트(기본 12P).

## 다음 단계 제안

- 실제 DB 스키마에 맞춘 Admin 엔티티 및 마이그레이션 작성
- API 모듈(예: 회원, 계약 등) 추가 및 Swagger DTO 정의
- 관리자 UI를 확장하고 CSRF/권한 로직 강화
- 배포 환경에 맞는 HTTPS/프록시 설정 및 세션 보안 옵션 조정

필요한 추가 모듈이나 설정이 있다면 언제든지 알려주세요.
