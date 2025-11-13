# AAB 파일 서명 확인 스크립트
# App Bundle이 올바른 키스토어로 서명되었는지 확인

$aabPath = "build\app\outputs\bundle\release\app-release.aab"

if (Test-Path $aabPath) {
    Write-Host "App Bundle 서명 정보 확인 중..." -ForegroundColor Yellow
    Write-Host ""

    # JAR 서명 확인 (AAB는 ZIP 형식이므로 jarsigner 사용 가능)
    jarsigner -verify -verbose -certs $aabPath

    Write-Host ""
    Write-Host "서명 확인 완료!" -ForegroundColor Green
    Write-Host ""
    Write-Host "확인 사항:" -ForegroundColor Cyan
    Write-Host "1. 'jar verified' 메시지가 표시되어야 합니다" -ForegroundColor White
    Write-Host "2. 'CN=...' 부분에서 키스토어 정보를 확인할 수 있습니다" -ForegroundColor White

} else {
    Write-Host "App Bundle 파일을 찾을 수 없습니다!" -ForegroundColor Red
    Write-Host "먼저 빌드를 실행하세요: flutter build appbundle --release" -ForegroundColor Yellow
}

pause
