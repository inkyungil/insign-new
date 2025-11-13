# Google Play Store Release Build Script
# 인싸인(Insign) 앱 배포용 빌드 스크립트

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  인싸인 Play Store Release Build" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# 프로젝트 디렉토리 확인
$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectDir

Write-Host "[1/5] 프로젝트 디렉토리: $projectDir" -ForegroundColor Green
Write-Host ""

# Flutter 버전 확인
Write-Host "[2/5] Flutter 버전 확인..." -ForegroundColor Yellow
flutter --version
Write-Host ""

# 의존성 설치
Write-Host "[3/5] 의존성 설치 중..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "의존성 설치 실패!" -ForegroundColor Red
    exit 1
}
Write-Host ""

# 코드 분석 (선택사항)
Write-Host "[4/5] 코드 분석 중..." -ForegroundColor Yellow
flutter analyze
Write-Host ""

# App Bundle 빌드
Write-Host "[5/5] Release App Bundle 빌드 중..." -ForegroundColor Yellow
Write-Host "이 작업은 몇 분 정도 걸릴 수 있습니다..." -ForegroundColor Gray
flutter build appbundle --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "  빌드 성공!" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host ""

    # 빌드 파일 정보
    $aabPath = "build\app\outputs\bundle\release\app-release.aab"
    if (Test-Path $aabPath) {
        $fileSize = (Get-Item $aabPath).Length / 1MB
        Write-Host "빌드 파일: $aabPath" -ForegroundColor Cyan
        Write-Host "파일 크기: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Cyan
        Write-Host ""

        # 파일 탐색기에서 빌드 폴더 열기
        Write-Host "빌드 폴더 열기..." -ForegroundColor Yellow
        explorer.exe "build\app\outputs\bundle\release\"
    }

    Write-Host ""
    Write-Host "다음 단계:" -ForegroundColor Yellow
    Write-Host "1. Google Play Console 접속: https://play.google.com/console" -ForegroundColor White
    Write-Host "2. 앱 선택 또는 새 앱 만들기" -ForegroundColor White
    Write-Host "3. 프로덕션 → 새 버전 만들기" -ForegroundColor White
    Write-Host "4. app-release.aab 파일 업로드" -ForegroundColor White
    Write-Host "5. 출시 노트 작성 후 검토 및 출시" -ForegroundColor White
    Write-Host ""
    Write-Host "자세한 내용은 PLAY_STORE_DEPLOYMENT.md를 참조하세요." -ForegroundColor Gray

} else {
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Red
    Write-Host "  빌드 실패!" -ForegroundColor Red
    Write-Host "=====================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "다음을 확인하세요:" -ForegroundColor Yellow
    Write-Host "1. android/key.properties 파일 존재 확인" -ForegroundColor White
    Write-Host "2. android/app/keystores/release.keystore 파일 존재 확인" -ForegroundColor White
    Write-Host "3. android/app/google-services.json 파일 존재 확인" -ForegroundColor White
    Write-Host "4. 위의 오류 메시지 확인" -ForegroundColor White
    Write-Host ""
    exit 1
}
