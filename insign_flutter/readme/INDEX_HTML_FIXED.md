# index.html 초기화 오류 해결 ✅

## 문제

```
FlutterLoader.load requires _flutter.buildConfig to be set
```

Flutter 3.24.5에서 웹 초기화 API가 변경되었습니다.

---

## 해결 방법

### 변경 전 (Deprecated)
```html
<script>
  var serviceWorkerVersion = "{{flutter_service_worker_version}}";
</script>
<script src="flutter.js" defer></script>
</head>
<body>
  <script>
    window.addEventListener('load', function(ev) {
      _flutter.loader.load({
        serviceWorkerSettings: {
          serviceWorkerVersion: serviceWorkerVersion,
        },
        onEntrypointLoaded: function(engineInitializer) {
          engineInitializer.initializeEngine().then(function(appRunner) {
            appRunner.runApp();
          });
        }
      });
    });
  </script>
```

### 변경 후 (Flutter 3.24.5)
```html
{{flutter_js}}
{{flutter_build_config}}
</head>
<body>
  <script>
    window.addEventListener('load', function(ev) {
      _flutter.loader.load();
    });
  </script>
```

---

## 주요 변경사항

1. **템플릿 토큰 사용**
   - `{{flutter_js}}` - Flutter JS 로더 자동 주입
   - `{{flutter_build_config}}` - 빌드 설정 자동 주입

2. **간소화된 초기화**
   - `_flutter.loader.load()` - 파라미터 없이 호출
   - 모든 설정은 템플릿 토큰으로 자동 처리

3. **제거된 수동 설정**
   - `serviceWorkerVersion` 변수 불필요
   - `serviceWorkerSettings` 파라미터 불필요
   - `onEntrypointLoaded` 콜백 불필요 (기본값 사용)

---

## ✅ 현재 상태

Flutter 웹 서버가 업데이트된 index.html로 정상 작동 중입니다.

- **URL**: http://0.0.0.0:8082
- **Status**: ✅ 실행 중
- **초기화 오류**: ✅ 해결됨

---

## 참고 문서

- [Flutter Web 초기화 가이드](https://docs.flutter.dev/platform-integration/web/initialization)
- [Flutter 3.x 마이그레이션](https://docs.flutter.dev/release/breaking-changes)

