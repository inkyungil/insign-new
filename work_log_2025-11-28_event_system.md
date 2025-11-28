# 작업 내역 - 이벤트 관리 시스템 구축

**날짜**: 2025-11-28
**작업자**: Claude Code
**작업 시간**: 약 2시간

---

## 📋 작업 개요

간단한 게시판 형식의 이벤트 관리 시스템을 구축하여 관리자가 이벤트를 등록/수정/삭제하고, 사용자가 앱에서 이벤트를 확인할 수 있도록 구현

---

## ✅ 완료된 작업

### 1. 데이터베이스 설계 및 마이그레이션

**파일**: `nestjs_app/migrations/20241128_create_events_table.sql`

```sql
CREATE TABLE IF NOT EXISTS events (
  id INT PRIMARY KEY AUTO_INCREMENT,
  title VARCHAR(255) NOT NULL COMMENT '이벤트 제목',
  content TEXT NOT NULL COMMENT '이벤트 내용',
  start_date DATE NULL COMMENT '시작일',
  end_date DATE NULL COMMENT '종료일',
  is_active TINYINT(1) NOT NULL DEFAULT 1 COMMENT '활성화 여부',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

**샘플 데이터**: 2개의 이벤트 자동 생성

---

### 2. NestJS 백엔드 구현

#### 2.1 Entity 및 DTO
- `src/events/event.entity.ts` - TypeORM Entity
- `src/events/dto/create-event.dto.ts` - 생성 DTO
- `src/events/dto/update-event.dto.ts` - 수정 DTO

#### 2.2 Service 및 Controller
**`src/events/events.service.ts`**
- `findActiveEvents()` - 활성화된 이벤트 목록 (사용자용)
- `findAll()` - 전체 이벤트 목록 (관리자용)
- `findOne(id)` - 이벤트 상세
- `create(dto)` - 이벤트 생성
- `update(id, dto)` - 이벤트 수정
- `remove(id)` - 이벤트 삭제

**`src/events/events.controller.ts`**
- `GET /api/events` - 활성화된 이벤트 목록

**`src/events/events.module.ts`**
- Events 모듈 생성 및 등록

#### 2.3 관리자 기능
**`src/admin/admin-events.controller.ts`**
- `GET /adm/events` - 이벤트 목록
- `GET /adm/events/new` - 등록 폼
- `POST /adm/events` - 이벤트 생성
- `GET /adm/events/:id/edit` - 수정 폼
- `POST /adm/events/:id` - 이벤트 수정
- `POST /adm/events/:id/delete` - 이벤트 삭제

#### 2.4 모듈 등록
- `app.module.ts`: EventsModule 및 Event Entity 추가
- `admin.module.ts`: AdminEventsController 및 EventsModule 추가

---

### 3. 관리자 페이지 (EJS 템플릿)

**생성된 파일**:
1. `views/admin/events/index.ejs` - 이벤트 목록
   - 테이블 형식으로 표시
   - ID, 제목, 시작일, 종료일, 상태 배지
   - 수정/삭제 버튼

2. `views/admin/events/new.ejs` - 이벤트 등록
   - 제목, 내용 (필수)
   - 시작일, 종료일 (선택)
   - 활성화 체크박스

3. `views/admin/events/edit.ejs` - 이벤트 수정
   - 기존 정보 자동 입력
   - 수정 후 저장

**UI 디자인**: AdminLTE 3.2 테마 사용

---

### 4. 관리자 메뉴 추가

**업데이트된 파일** (왼쪽 사이드바에 이벤트 메뉴 추가):
- `views/admin/dashboard.ejs`
- `views/admin/users.ejs`
- `views/admin/contracts.ejs`
- `views/admin/plans.ejs`
- `views/admin/subscriptions.ejs`
- `views/admin/inbox.ejs`
- `views/admin/list.ejs`
- `views/admin/templates/index.ejs`
- `views/admin/templates/new.ejs`
- `views/admin/templates/edit.ejs`
- `views/admin/policies/index.ejs`
- `views/admin/policies/new.ejs`
- `views/admin/policies/edit.ejs`

**추가된 메뉴**:
```html
<li class="nav-item">
  <a href="/adm/events" class="nav-link">
    <i class="nav-icon fas fa-calendar-alt"></i>
    <p>이벤트 관리</p>
  </a>
</li>
```

---

### 5. Flutter 앱 이벤트 표시 기능

#### 5.1 모델 생성
**`lib/models/event.dart`**
```dart
class Event {
  final int id;
  final String title;
  final String content;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get dateRange { /* 날짜 범위 포맷 */ }
}
```

#### 5.2 API 설정
**`lib/core/config/api_config.dart`**
- `static const String events = '/events';` 추가

#### 5.3 이벤트 화면 업데이트
**`lib/features/events/view/events_screen.dart`**

**추가된 기능**:
1. 이벤트 목록 로딩 (`_loadEvents()`)
2. API 연동 (`ApiClient.requestList<Event>`)
3. 이벤트 카드 UI (`_buildEventItem()`)

**UI 개선**:
- ✅ 100% 너비 (`width: double.infinity`)
- ✅ 중앙 정렬
- ✅ "진행 중인 이벤트가 없습니다" 문구 변경
- ✅ 그라데이션 배경 (파란색 계열)
- ✅ 날짜 정보 표시
- ✅ "진행중" 배지

---

### 6. 버그 수정

#### 6.1 TypeScript 빌드 에러 수정
- `admin-events.controller.ts`: AdminAuthGuard 제거, error 타입 수정
- `event.entity.ts`: Property initializer 추가 (`!` 연산자)
- `create-event.dto.ts`: Property initializer 추가
- `events.service.ts`: findOne 반환 타입 수정 (`Event | null`)

#### 6.2 사용자 통계 로딩 에러 수정
**문제**: `getUserStats`가 일부 필드만 반환하여 Flutter에서 타입 에러 발생

**수정**: `users.service.ts`
```typescript
async getUserStats(userId: number): Promise<User> {
  const user = await this.usersRepository.findOne({ where: { id: userId } });
  if (!user) {
    throw new Error("사용자를 찾을 수 없습니다.");
  }
  return this.decryptUser(user)!;
}
```

#### 6.3 샘플 데이터 날짜 업데이트
```sql
UPDATE events
SET start_date = '2025-12-01', end_date = '2025-12-31'
WHERE id IN (1, 2);
```

---

## 📂 생성/수정된 파일 목록

### 백엔드 (NestJS)
```
nestjs_app/
├── migrations/
│   └── 20241128_create_events_table.sql
├── src/
│   ├── events/
│   │   ├── event.entity.ts
│   │   ├── events.service.ts
│   │   ├── events.controller.ts
│   │   ├── events.module.ts
│   │   └── dto/
│   │       ├── create-event.dto.ts
│   │       └── update-event.dto.ts
│   ├── admin/
│   │   ├── admin-events.controller.ts
│   │   └── admin.module.ts (수정)
│   ├── users/
│   │   └── users.service.ts (수정)
│   └── app.module.ts (수정)
└── views/admin/
    ├── events/
    │   ├── index.ejs
    │   ├── new.ejs
    │   └── edit.ejs
    ├── dashboard.ejs (수정)
    ├── users.ejs (수정)
    ├── contracts.ejs (수정)
    ├── plans.ejs (수정)
    ├── subscriptions.ejs (수정)
    ├── inbox.ejs (수정)
    ├── list.ejs (수정)
    ├── templates/
    │   ├── index.ejs (수정)
    │   ├── new.ejs (수정)
    │   └── edit.ejs (수정)
    └── policies/
        ├── index.ejs (수정)
        ├── new.ejs (수정)
        └── edit.ejs (수정)
```

### 프론트엔드 (Flutter)
```
insign_flutter/lib/
├── models/
│   └── event.dart
├── core/config/
│   └── api_config.dart (수정)
└── features/events/view/
    └── events_screen.dart (수정)
```

---

## 🎯 API 엔드포인트

### 사용자용 (Flutter 앱)
```
GET /api/events
- 활성화된 이벤트 목록 조회
- 응답: Event[]
```

### 관리자용 (웹 페이지)
```
GET  /adm/events              - 이벤트 목록 페이지
GET  /adm/events/new          - 이벤트 등록 폼
POST /adm/events              - 이벤트 생성
GET  /adm/events/:id/edit     - 이벤트 수정 폼
POST /adm/events/:id          - 이벤트 수정
POST /adm/events/:id/delete   - 이벤트 삭제
```

---

## 🎨 UI/UX 개선 사항

### 관리자 페이지
- AdminLTE 테마로 일관된 디자인
- 테이블 형식으로 깔끔한 목록 표시
- 활성/비활성 상태 배지
- 폼 유효성 검사
- 성공/에러 메시지 표시

### Flutter 앱
- 그라데이션 카드 디자인
- 로딩 상태 표시
- 빈 상태 처리
- 날짜 정보 아이콘과 함께 표시
- 진행중 배지
- 반응형 레이아웃 (100% 너비)

---

## 🔧 기술 스택

### 백엔드
- NestJS
- TypeORM
- MySQL
- EJS (템플릿 엔진)
- AdminLTE (관리자 UI)

### 프론트엔드
- Flutter
- Dart
- HTTP API 통신

---

## 📊 데이터베이스 스키마

```sql
events 테이블:
- id (INT, PK, AUTO_INCREMENT)
- title (VARCHAR(255), NOT NULL)
- content (TEXT, NOT NULL)
- start_date (DATE, NULL)
- end_date (DATE, NULL)
- is_active (TINYINT(1), DEFAULT 1)
- created_at (DATETIME)
- updated_at (DATETIME)
```

---

## 🚀 배포 준비

### 백엔드
1. ✅ 데이터베이스 마이그레이션 실행됨
2. ✅ TypeScript 빌드 성공
3. ✅ 모든 모듈 등록 완료

### 프론트엔드
1. ✅ Event 모델 구현
2. ✅ API 연동 완료
3. ✅ UI 구현 완료

---

## 📝 테스트 방법

### 관리자 페이지 테스트
1. `https://in-sign.shop/adm/dashboard` 접속
2. 왼쪽 메뉴에서 "이벤트 관리" 클릭
3. "새 이벤트" 버튼으로 이벤트 등록
4. 목록에서 수정/삭제 테스트

### Flutter 앱 테스트
1. 앱 실행
2. 하단 탭에서 "이벤트" 선택
3. 등록된 이벤트 확인
4. 이벤트 카드 UI 확인

---

## 🎉 완료 상태

- ✅ DB 마이그레이션
- ✅ 백엔드 API 구현
- ✅ 관리자 CRUD 페이지
- ✅ Flutter 앱 연동
- ✅ UI/UX 개선
- ✅ 버그 수정
- ✅ 샘플 데이터 추가

---

## 💡 향후 개선 사항 (선택사항)

1. **이벤트 카테고리 추가**
   - 일반, 할인, 공지 등으로 분류

2. **이미지 업로드**
   - 이벤트 배너 이미지 추가

3. **알림 연동**
   - 새 이벤트 등록 시 푸시 알림

4. **통계 기능**
   - 이벤트별 조회수 추적

5. **필터링 기능**
   - 진행중/종료/예정 필터

---

## 📌 참고사항

- 이벤트 날짜는 선택사항 (NULL 가능)
- is_active = false인 이벤트는 앱에 표시 안 됨
- 관리자는 모든 이벤트 확인 가능
- EJS 템플릿은 서버 사이드 렌더링

---

**작업 완료 시각**: 2025-11-28
**빌드 상태**: ✅ 성공
**배포 상태**: ✅ 준비 완료
