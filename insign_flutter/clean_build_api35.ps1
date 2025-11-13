# ========================================
# 완전 클린 빌드 스크립트 (API 35 검증)
# ========================================

Write-Host "`n===================================" -ForegroundColor Cyan
Write-Host "Flutter 완전 클린 빌드 (API 35)" -ForegroundColor Cyan
Write-Host "===================================`n" -ForegroundColor Cyan

# 현재 디렉토리 확인
$currentDir = Get-Location
Write-Host "[1/8] 현재 디렉토리: $currentDir" -ForegroundColor Yellow

# Flutter 버전 확인
Write-Host "`n[2/8] Flutter 버전 확인..." -ForegroundColor Yellow
flutter --version

# Flutter 캐시 정리
Write-Host "`n[3/8] Flutter 캐시 정리..." -ForegroundColor Yellow
flutter clean

# Gradle 캐시 정리
Write-Host "`n[4/8] Gradle 캐시 정리..." -ForegroundColor Yellow
cd android
.\gradlew clean
.\gradlew cleanBuildCache
cd ..

# 빌드 폴더 수동 삭제
Write-Host "`n[5/8] 빌드 폴더 수동 삭제..." -ForegroundColor Yellow
if (Test-Path "build") {
    Remove-Item -Recurse -Force build
    Write-Host "  - build 폴더 삭제 완료" -ForegroundColor Green
}
if (Test-Path "android\.gradle") {
    Remove-Item -Recurse -Force android\.gradle
    Write-Host "  - android\.gradle 폴더 삭제 완료" -ForegroundColor Green
}
if (Test-Path "android\app\build") {
    Remove-Item -Recurse -Force android\app\build
    Write-Host "  - android\app\build 폴더 삭제 완료" -ForegroundColor Green
}

# build.gradle 설정 확인
Write-Host "`n[6/8] build.gradle API 설정 확인..." -ForegroundColor Yellow
$buildGradle = Get-Content "android\app\build.gradle" -Raw
if ($buildGradle -match "compileSdk\s+35") {
    Write-Host "  ✓ compileSdk 35 확인됨" -ForegroundColor Green
} else {
    Write-Host "  ✗ compileSdk 35가 아닙니다!" -ForegroundColor Red
    exit 1
}
if ($buildGradle -match "targetSdkVersion\s+35") {
    Write-Host "  ✓ targetSdkVersion 35 확인됨" -ForegroundColor Green
} else {
    Write-Host "  ✗ targetSdkVersion 35가 아닙니다!" -ForegroundColor Red
    exit 1
}

# pubspec.yaml 버전 확인
Write-Host "`n[7/8] pubspec.yaml 버전 확인..." -ForegroundColor Yellow
$pubspec = Get-Content "pubspec.yaml" -Raw
if ($pubspec -match "version:\s+(\S+)") {
    $version = $matches[1]
    Write-Host "  앱 버전: $version" -ForegroundColor Green
} else {
    Write-Host "  버전 정보를 찾을 수 없습니다" -ForegroundColor Red
}

# 의존성 재설치
Write-Host "`n[8/8] Flutter 의존성 재설치..." -ForegroundColor Yellow
flutter pub get

# Release 빌드
Write-Host "`n===================================" -ForegroundColor Cyan
Write-Host "Release App Bundle 빌드 시작" -ForegroundColor Cyan
Write-Host "===================================`n" -ForegroundColor Cyan

flutter build appbundle --release

# 빌드 결과 확인
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n===================================" -ForegroundColor Green
    Write-Host "빌드 성공!" -ForegroundColor Green
    Write-Host "===================================`n" -ForegroundColor Green

    $aabPath = "build\app\outputs\bundle\release\app-release.aab"
    if (Test-Path $aabPath) {
        $aabSize = (Get-Item $aabPath).Length / 1MB
        Write-Host "AAB 파일 위치: $aabPath" -ForegroundColor Cyan
        Write-Host "AAB 파일 크기: $([math]::Round($aabSize, 2)) MB" -ForegroundColor Cyan
        Write-Host "`n버전: $version" -ForegroundColor Cyan
        Write-Host "API Level: 35 (Android 15)" -ForegroundColor Cyan
        Write-Host "`n다음 단계:" -ForegroundColor Yellow
        Write-Host "1. Play Console로 이동" -ForegroundColor White
        Write-Host "2. 테스트 -> 내부 테스트 -> 새 버전 만들기" -ForegroundColor White
        Write-Host "3. 이전 버전(코드 1, 2) 삭제" -ForegroundColor White
        Write-Host "4. 위 AAB 파일 업로드" -ForegroundColor White
        Write-Host "5. 출시 노트 작성 및 검토" -ForegroundColor White

        # 빌드 폴더 열기
        Write-Host "`n빌드 폴더를 열까요? (Y/N): " -ForegroundColor Yellow -NoNewline
        $response = Read-Host
        if ($response -eq 'Y' -or $response -eq 'y') {
            explorer "build\app\outputs\bundle\release"
        }
    } else {
        Write-Host "AAB 파일을 찾을 수 없습니다!" -ForegroundColor Red
    }
} else {
    Write-Host "`n===================================" -ForegroundColor Red
    Write-Host "빌드 실패!" -ForegroundColor Red
    Write-Host "===================================`n" -ForegroundColor Red
    Write-Host "위의 오류 메시지를 확인하세요." -ForegroundColor Yellow
}

Write-Host "`n스크립트 완료." -ForegroundColor Gray
