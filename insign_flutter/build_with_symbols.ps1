# ========================================
# 디버그 심볼 포함 빌드 스크립트
# ========================================

Write-Host "`n===================================" -ForegroundColor Cyan
Write-Host "디버그 심볼 포함 빌드" -ForegroundColor Cyan
Write-Host "===================================`n" -ForegroundColor Cyan

# 현재 디렉토리 확인
$currentDir = Get-Location
Write-Host "현재 디렉토리: $currentDir" -ForegroundColor Yellow

# pubspec.yaml 버전 확인
Write-Host "`n버전 확인..." -ForegroundColor Yellow
$pubspec = Get-Content "pubspec.yaml" -Raw
if ($pubspec -match "version:\s+(\S+)") {
    $version = $matches[1]
    Write-Host "앱 버전: $version" -ForegroundColor Green
} else {
    Write-Host "버전 정보를 찾을 수 없습니다" -ForegroundColor Red
    exit 1
}

# 기존 symbols 폴더 삭제
Write-Host "`n기존 심볼 폴더 정리..." -ForegroundColor Yellow
if (Test-Path "build\app\outputs\symbols") {
    Remove-Item -Recurse -Force build\app\outputs\symbols
    Write-Host "  - 기존 symbols 폴더 삭제 완료" -ForegroundColor Green
}

# 디버그 심볼 포함 빌드
Write-Host "`n===================================" -ForegroundColor Cyan
Write-Host "Release 빌드 시작 (디버그 심볼 포함)" -ForegroundColor Cyan
Write-Host "===================================`n" -ForegroundColor Cyan

flutter build appbundle --release --split-debug-info=build/app/outputs/symbols

# 빌드 결과 확인
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n===================================" -ForegroundColor Green
    Write-Host "빌드 성공!" -ForegroundColor Green
    Write-Host "===================================`n" -ForegroundColor Green

    # AAB 파일 확인
    $aabPath = "build\app\outputs\bundle\release\app-release.aab"
    if (Test-Path $aabPath) {
        $aabSize = (Get-Item $aabPath).Length / 1MB
        Write-Host "AAB 파일 위치: $aabPath" -ForegroundColor Cyan
        Write-Host "AAB 파일 크기: $([math]::Round($aabSize, 2)) MB" -ForegroundColor Cyan
    }

    # 심볼 폴더 확인
    $symbolsPath = "build\app\outputs\symbols"
    if (Test-Path $symbolsPath) {
        Write-Host "`n디버그 심볼 폴더: $symbolsPath" -ForegroundColor Cyan

        # 심볼 파일 개수 확인
        $symbolFiles = Get-ChildItem -Path $symbolsPath -Filter "*.symbols" -Recurse
        $symbolCount = $symbolFiles.Count
        Write-Host "심볼 파일 개수: $symbolCount" -ForegroundColor Cyan

        # ZIP 파일 생성
        Write-Host "`n심볼 파일 압축 중..." -ForegroundColor Yellow
        $zipPath = "build\app\outputs\symbols.zip"

        if (Test-Path $zipPath) {
            Remove-Item -Force $zipPath
        }

        # symbols 폴더 전체를 압축
        Compress-Archive -Path "$symbolsPath\*" -DestinationPath $zipPath -Force

        if (Test-Path $zipPath) {
            $zipSize = (Get-Item $zipPath).Length / 1MB
            Write-Host "`n심볼 ZIP 파일 생성 완료!" -ForegroundColor Green
            Write-Host "ZIP 파일 위치: $zipPath" -ForegroundColor Cyan
            Write-Host "ZIP 파일 크기: $([math]::Round($zipSize, 2)) MB" -ForegroundColor Cyan
        } else {
            Write-Host "`nZIP 파일 생성 실패!" -ForegroundColor Red
        }
    } else {
        Write-Host "`n심볼 폴더를 찾을 수 없습니다!" -ForegroundColor Red
    }

    # 요약
    Write-Host "`n===================================" -ForegroundColor Cyan
    Write-Host "빌드 완료 요약" -ForegroundColor Cyan
    Write-Host "===================================`n" -ForegroundColor Cyan
    Write-Host "버전: $version" -ForegroundColor White
    Write-Host "API Level: 35 (Android 15)" -ForegroundColor White
    Write-Host "`n생성된 파일:" -ForegroundColor Yellow
    Write-Host "1. AAB: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor White
    Write-Host "2. 심볼 ZIP: build\app\outputs\symbols.zip" -ForegroundColor White

    Write-Host "`n다음 단계:" -ForegroundColor Yellow
    Write-Host "1. Play Console -> 테스트 -> 내부 테스트" -ForegroundColor White
    Write-Host "2. 버전 1.0.0 (코드 4) 선택" -ForegroundColor White
    Write-Host "3. '아티팩트' 탭 클릭" -ForegroundColor White
    Write-Host "4. '네이티브 디버그 심볼' 섹션에서 symbols.zip 업로드" -ForegroundColor White

    # 빌드 폴더 열기
    Write-Host "`n빌드 폴더를 열까요? (Y/N): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    if ($response -eq 'Y' -or $response -eq 'y') {
        explorer "build\app\outputs"
    }

} else {
    Write-Host "`n===================================" -ForegroundColor Red
    Write-Host "빌드 실패!" -ForegroundColor Red
    Write-Host "===================================`n" -ForegroundColor Red
    Write-Host "위의 오류 메시지를 확인하세요." -ForegroundColor Yellow
}

Write-Host "`n스크립트 완료." -ForegroundColor Gray
