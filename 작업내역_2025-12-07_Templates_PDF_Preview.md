# 2025-12-07 템플릿 PDF 미리보기 작업 내역

## 목표
- `/templates` 화면과 "템플릿으로 작성하기" 플로우에서 **실제 계약서 PDF와 동일한 디자인**으로 템플릿 PDF 미리보기를 제공.

## NestJS (`nestjs_app`)

### 1) 템플릿 미리보기용 PDF 엔드포인트 추가
- 파일: `src/templates/templates.controller.ts`
  - `GET /api/templates/:id/preview-pdf` 추가.
  - 인증 토큰 검증 후 `TemplatesService.generatePreviewPdf(id)` 호출.
  - `Content-Type: application/pdf`, `inline` 응답으로 PDF 스트리밍.

### 2) 템플릿 미리보기 PDF 생성 로직 추가
- 파일: `src/templates/templates.service.ts`
  - `generatePreviewPdf(templateId: number)` 구현.
    - `Template` 조회 후 **가짜 `Contract` 엔티티** 생성:
      - `contract.templateId = template.id`
      - `contract.name = '<템플릿명> (미리보기)'`
      - `clientName = '샘플 갑'`, `performerName = '샘플 을'` 등 기본 샘플 값 설정.
    - `contract.metadata`에 템플릿 관련 메타데이터 주입:
      - `templateName`, `templateSchemaVersion`
      - `templateFormValues` = `samplePayload` + `formSchema.defaultValue` 를 합쳐 만든 placeholder 값
      - `templateRawContent` = `template.content`
    - `ContractPdfService.generate(contract)` 호출해서 **실제 계약 PDF와 동일한 파이프라인**으로 PDF 생성.

### 3) HTML → PDF 렌더링 fallback 처리
- 파일: `src/templates/html-pdf.service.ts`
  - 원래: Puppeteer(Chromium) 실패 시 예외를 던지며 500 응답 발생.
  - 변경:
    - Chromium 페이지 크래시 / 브라우저 실행 실패 시:
      - 경고 로그 출력 후 `renderFallback(...)` 호출.
    - `renderFallback`:
      - `pdfkit`을 사용해 단순 텍스트 기반 A4 PDF 생성.
      - HTML에서 `<style>`, `<script>`, 태그 제거 후 텍스트만 추출해 PDF에 출력.
  - 결과:
    - 서버 환경에서 Chromium이 동작하지 않아도 **PDF는 항상 생성**되지만,
    - 이 경우 디자인은 기존 A4 템플릿과 다른 "간소화된 PDF" 형태가 됨.

## Flutter (`insign_flutter`)

### 4) 템플릿 PDF 풀스크린 뷰 화면 추가
- 파일: `lib/features/templates/view/template_pdf_view_screen.dart`
  - `TemplatePdfViewScreen(templateId)`:
    - `SessionService.getAccessToken()`으로 토큰 조회.
    - `TemplateRepository.previewTemplatePdf(id: templateId)` 호출 → `/api/templates/:id/preview-pdf`에서 PDF 바이트 수신.
    - `PdfPreview` 위젯으로 **계약서 PDF와 동일한 스타일**의 풀스크린 PDF 뷰 제공.
    - 로딩/에러/재시도 UI 포함.
- 파일: `lib/data/template_repository.dart`
  - `previewTemplatePdf({required int id, String? token})` 추가:
    - `GET /api/templates/:id/preview-pdf`
    - `Accept: application/pdf`로 `Uint8List` 반환.

### 5) `/templates` 리스트 "미리보기" 버튼 동작 변경
- 파일: `lib/features/templates/view/templates_screen.dart`
  - 이전: `showTemplatePreviewModal(context, template)` (HTML 기반 모달 미리보기).
  - 이후:
    ```dart
    Future<void> _handlePreview(Template template) {
      return Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TemplatePdfViewScreen(templateId: template.id),
        ),
      );
    }
    ```
  - 결과: 템플릿 리스트의 "미리보기" 버튼을 누르면 **계약서 PDF와 동일한 풀스크린 뷰어**로 템플릿 PDF 미리보기를 확인.

### 6) "템플릿으로 작성" 화면 상단 눈(미리보기) 아이콘 동작 변경
- 파일: `lib/features/contracts/view/create_contract_screen.dart`
  - `_openTemplatePreview()` 수정:
    - 이전: `showTemplatePreviewModal(context, template)` (HTML 모달).
    - 이후:
      ```dart
      Future<void> _openTemplatePreview() {
        final template = _template;
        if (template == null) {
          return Future.value();
        }
        return Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TemplatePdfViewScreen(templateId: template.id),
          ),
        );
      }
      ```
  - 결과: 템플릿으로 작성하기 화면 상단 우측 눈 아이콘도 **계약서 PDF와 동일한 풀스크린 PDF 뷰어**를 사용.

### 7) 테스트 추가
- 파일: `test/features/templates/view/template_pdf_view_screen_test.dart`
  - `TemplatePdfViewScreen`이 AppBar와 로딩 인디케이터를 그리는지 확인하는 기본 위젯 테스트 추가.

## 현재 한계 및 남은 이슈

1. **서버 환경에서 Chromium(Puppeteer)이 정상 동작하지 않음**
   - 로그:
     ```text
     WARN [HtmlPdfService] Chromium page closed unexpectedly while generating PDF. Restarting browser... (Protocol error: Connection closed.)
     WARN [HtmlPdfService] Falling back to simple PDF rendering due to Chromium page crash...
     WARN [HtmlPdfService] Using HtmlPdfService fallback renderer (PDFKit).
     ```
   - 이 때문에 템플릿 미리보기 및 새로 생성하는 계약서 PDF는 **fallback(PDFKit) 디자인**으로 생성됨.
   - 기존에 저장되어 있던 계약 PDF(Chromium으로 렌더된 것)과 **디자인 차이 발생**.

2. **코드 관점에서의 통일은 완료**
   - 템플릿 미리보기와 `계약서 PDF로 보기` 모두:
     - `ContractPdfService.generate(...)`를 사용.
     - 템플릿 HTML/DOCX + placeholder 채움 로직을 공유.
   - Flutter는 두 경우 모두 **NestJS가 생성한 PDF만 풀스크린으로 보여주는 역할**로 통일.

3. **완전 동일한 디자인을 보장하려면**
   - 서버에서 다음이 필요:
     - Chromium/Chrome 설치 및 실행 가능 상태 확보.
     - `CHROMIUM_PATH` 또는 `PUPPETEER_EXECUTABLE_PATH` 환경 변수로 실제 바이너리 경로 지정.
     - NestJS 재시작 후 `HtmlPdfService`에서 fallback 경로가 더 이상 호출되지 않는지 확인.
   - 이후에는 템플릿 미리보기와 `계약서 PDF로 보기`가 **실제 PDF 레이아웃까지 완전히 동일**하게 출력될 예정.

