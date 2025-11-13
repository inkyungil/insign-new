# 계약서 템플릿 마이그레이션 가이드

## 📌 개요

이 마이그레이션은 **기존 계약서들의 metadata에 `templateFormSchema`를 추가**하여, 템플릿 수정 시 기존 계약서가 영향받지 않도록 합니다.

### 문제점
- 기존: 계약서 조회 시 최신 템플릿을 fetch하여 사용
- 결과: 템플릿 수정 시 기존 계약서도 변경됨 ❌

### 해결책
- 계약서 생성 시점의 템플릿을 metadata에 스냅샷으로 저장
- 템플릿 수정과 무관하게 원본 유지 ✅

---

## 🚀 실행 방법

### 1. 백업 (필수!)

마이그레이션 실행 전 **반드시 데이터베이스를 백업**하세요.

```bash
# MySQL 백업
mysqldump -u insign -p insign > backup_$(date +%Y%m%d_%H%M%S).sql
```

### 2. 마이그레이션 실행

```bash
cd nestjs_app

# 방법 1: npm 스크립트 사용 (권장)
npm run migrate:templates

# 방법 2: 직접 실행
npx ts-node -r tsconfig-paths/register src/scripts/migrate-contract-templates.ts
```

### 3. 실행 결과 확인

스크립트 실행 시 다음과 같은 출력을 확인할 수 있습니다:

```
🚀 계약서 템플릿 마이그레이션 시작...

📊 총 25개의 계약서를 확인합니다.

✨ 계약서 #1 - 템플릿 "근로계약서" 스냅샷 저장 완료
✅ 계약서 #2 - 이미 templateFormSchema 존재, 건너뜀
✨ 계약서 #3 - 템플릿 "프리랜서 계약서" 스냅샷 저장 완료
⏭️  계약서 #4 - templateId 없음, 건너뜀
...

============================================================
📈 마이그레이션 결과 요약

총 계약서 수: 25
✅ 업데이트 완료: 18개
⏭️  건너뛴 계약서: 7개
❌ 오류 발생: 0개
============================================================

✅ 마이그레이션이 성공적으로 완료되었습니다!
   이제 기존 계약서들도 원본 템플릿 구조를 유지합니다.

🎉 프로세스 종료
```

---

## 📝 마이그레이션 대상

### 업데이트 대상
- ✅ `templateId`가 있는 계약서
- ✅ metadata에 `templateFormSchema`가 **없는** 계약서

### 건너뛰는 계약서
- ⏭️ `templateId`가 없는 계약서 (템플릿 미사용)
- ⏭️ metadata에 이미 `templateFormSchema`가 있는 계약서

### 오류 가능성
- ❌ 템플릿이 삭제된 경우 (templateId는 있지만 템플릿 조회 실패)

---

## 🔍 변경 내용 확인

### 마이그레이션 전 metadata
```json
{
  "templateName": "근로계약서",
  "templateSchemaVersion": 1,
  "templateRawContent": "계약서 본문...",
  "templateFormValues": {...}
}
```

### 마이그레이션 후 metadata
```json
{
  "templateName": "근로계약서",
  "templateFormSchema": {
    "version": 1,
    "sections": [
      {
        "id": "basic",
        "title": "기본정보",
        "fields": [...]
      }
    ]
  },
  "templateSchemaVersion": 1,
  "templateRawContent": "계약서 본문...",
  "templateFormValues": {...}
}
```

### SQL로 확인

```sql
-- metadata에 templateFormSchema가 없는 계약서 확인
SELECT id, name, templateId,
       JSON_CONTAINS_PATH(metadata, 'one', '$.templateFormSchema') as has_schema
FROM contract
WHERE templateId IS NOT NULL;

-- 특정 계약서의 metadata 확인
SELECT id, name, metadata
FROM contract
WHERE id = 1;
```

---

## ⚠️ 주의사항

### 1. 백업 필수
- 마이그레이션 전 반드시 DB 백업

### 2. 서버 중단 권장
- 마이그레이션 중 서버를 중단하는 것을 권장
- 동시성 이슈 방지

### 3. 재실행 가능
- 스크립트는 **멱등성(idempotent)** 보장
- 여러 번 실행해도 안전 (이미 있는 경우 건너뜀)

### 4. 롤백 방법
문제 발생 시 백업으로 복원:

```bash
mysql -u insign -p insign < backup_20250103_120000.sql
```

---

## 🧪 테스트 방법

### 1. 마이그레이션 전 테스트
```bash
# 템플릿이 있는 계약서 개수 확인
mysql -u insign -p insign -e "SELECT COUNT(*) FROM contract WHERE templateId IS NOT NULL;"

# metadata에 templateFormSchema가 없는 계약서 개수
mysql -u insign -p insign -e "
SELECT COUNT(*) FROM contract
WHERE templateId IS NOT NULL
AND NOT JSON_CONTAINS_PATH(metadata, 'one', '$.templateFormSchema');"
```

### 2. 마이그레이션 실행
```bash
npm run migrate:templates
```

### 3. 마이그레이션 후 검증
```bash
# 모든 계약서가 templateFormSchema를 가지고 있는지 확인
mysql -u insign -p insign -e "
SELECT
  COUNT(*) as total,
  SUM(CASE WHEN JSON_CONTAINS_PATH(metadata, 'one', '$.templateFormSchema') THEN 1 ELSE 0 END) as with_schema
FROM contract
WHERE templateId IS NOT NULL;"
```

### 4. Flutter 앱에서 확인
1. 기존 계약서 조회
2. 템플릿 필드가 올바르게 표시되는지 확인
3. 관리자에서 템플릿 수정 후 기존 계약서가 영향받지 않는지 확인

---

## 📞 문제 발생 시

### 오류 로그 확인
마이그레이션 스크립트는 오류가 발생해도 계속 진행하며, 마지막에 오류 목록을 출력합니다.

```
⚠️  오류 상세 내역:

  - 계약서 #5: 템플릿 #3을 찾을 수 없음
  - 계약서 #12: 데이터베이스 연결 오류
```

### 수동 수정
특정 계약서만 문제가 있는 경우, SQL로 직접 수정 가능:

```sql
-- 특정 계약서의 metadata에 templateFormSchema 추가
UPDATE contract
SET metadata = JSON_SET(
  metadata,
  '$.templateFormSchema',
  (SELECT formSchema FROM template WHERE id = [템플릿ID])
)
WHERE id = [계약서ID];
```

---

## ✅ 완료 체크리스트

- [ ] DB 백업 완료
- [ ] 서버 중단 (선택)
- [ ] 마이그레이션 실행
- [ ] 결과 확인 (업데이트/건너뜀/오류 개수)
- [ ] SQL로 데이터 검증
- [ ] Flutter 앱에서 기존 계약서 조회 테스트
- [ ] 템플릿 수정 후 기존 계약서가 영향받지 않는지 확인
- [ ] 새 계약서 생성 시 최신 템플릿 적용 확인

---

## 🔗 관련 파일

- **마이그레이션 스크립트**: `nestjs_app/src/scripts/migrate-contract-templates.ts`
- **Flutter 수정 파일**: `insign_flutter/lib/features/contracts/view/create_contract_screen.dart` (2486-2489줄)
- **백엔드 로직**: `nestjs_app/src/contracts/contracts.service.ts` (enrichTemplateMetadata 메서드)

---

## 📚 추가 정보

이 마이그레이션은 **과거 계약서들을 수정**하는 것입니다.

**앞으로 생성되는 계약서**는 Flutter 앱의 수정사항으로 인해 자동으로 `templateFormSchema`가 저장됩니다.

따라서 이 마이그레이션은 **한 번만 실행**하면 됩니다.
