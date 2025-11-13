# Kakao 키 해시 생성 스크립트
# Android 키스토어에서 Kakao Developers에 등록할 키 해시를 생성합니다.

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Kakao 키 해시 생성 도구" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 키스토어 파일 경로
$keystorePath = "android\app\keystores\release.keystore"
$keyAlias = "insign-release"
$storePassword = "!@#insign1004"
$keyPassword = "!@#insign1004"

# 파일 존재 확인
if (-not (Test-Path $keystorePath)) {
    Write-Host "❌ 오류: 키스토어 파일을 찾을 수 없습니다." -ForegroundColor Red
    Write-Host "   경로: $keystorePath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "키스토어를 먼저 생성해주세요." -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ 키스토어 파일 확인: $keystorePath" -ForegroundColor Green
Write-Host ""

# keytool 경로 확인
$keytoolPath = "keytool"
try {
    $null = & $keytoolPath -help 2>&1
} catch {
    Write-Host "❌ 오류: keytool을 찾을 수 없습니다." -ForegroundColor Red
    Write-Host "   Java JDK가 설치되어 있고 PATH에 추가되어 있는지 확인해주세요." -ForegroundColor Yellow
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SHA-1 인증서 지문" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# SHA-1 지문 추출
try {
    $certInfo = & keytool -list -v -keystore $keystorePath -alias $keyAlias -storepass $storePassword -keypass $keyPassword 2>&1

    # SHA-1 추출
    $sha1Line = $certInfo | Select-String "SHA1:"
    if ($sha1Line) {
        $sha1 = ($sha1Line -split "SHA1:")[1].Trim()
        Write-Host "SHA-1: " -NoNewline -ForegroundColor Yellow
        Write-Host $sha1 -ForegroundColor White
    }

    # SHA-256 추출
    $sha256Line = $certInfo | Select-String "SHA256:"
    if ($sha256Line) {
        $sha256 = ($sha256Line -split "SHA256:")[1].Trim()
        Write-Host "SHA-256: " -NoNewline -ForegroundColor Yellow
        Write-Host $sha256 -ForegroundColor White
    }

    Write-Host ""
} catch {
    Write-Host "⚠️  SHA 지문 추출 실패 (계속 진행)" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Kakao 키 해시 생성" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# OpenSSL 확인
$opensslPath = "openssl"
try {
    $null = & $opensslPath version 2>&1
    $opensslAvailable = $true
} catch {
    $opensslAvailable = $false
}

if ($opensslAvailable) {
    Write-Host "OpenSSL 사용 가능 - Kakao 키 해시 생성 중..." -ForegroundColor Green
    Write-Host ""

    try {
        # Kakao 키 해시 생성
        $keyHash = & keytool -exportcert -alias $keyAlias -keystore $keystorePath -storepass $storePassword -keypass $keyPassword |
                   & openssl sha1 -binary |
                   & openssl base64

        Write-Host "✅ Kakao 키 해시:" -ForegroundColor Green
        Write-Host ""
        Write-Host "    $keyHash" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "위 키 해시를 복사하여 Kakao Developers 콘솔에 등록하세요." -ForegroundColor Yellow
        Write-Host ""

        # 클립보드에 복사 (Windows PowerShell)
        try {
            Set-Clipboard -Value $keyHash
            Write-Host "✅ 키 해시가 클립보드에 복사되었습니다!" -ForegroundColor Green
        } catch {
            Write-Host "⚠️  클립보드 복사 실패 - 수동으로 복사해주세요." -ForegroundColor Yellow
        }

    } catch {
        Write-Host "❌ 키 해시 생성 실패" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

} else {
    Write-Host "❌ OpenSSL을 찾을 수 없습니다." -ForegroundColor Red
    Write-Host ""
    Write-Host "OpenSSL 설치 방법:" -ForegroundColor Yellow
    Write-Host "  1. Git for Windows 설치 (OpenSSL 포함)" -ForegroundColor White
    Write-Host "     https://git-scm.com/download/win" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  2. OpenSSL 직접 설치" -ForegroundColor White
    Write-Host "     https://slproweb.com/products/Win32OpenSSL.html" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  3. PATH 환경 변수에 OpenSSL 경로 추가" -ForegroundColor White
    Write-Host "     예: C:\Program Files\Git\usr\bin" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  등록 안내" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 Google Cloud Console (Google 로그인)" -ForegroundColor Yellow
Write-Host "   1. https://console.cloud.google.com/ 접속" -ForegroundColor White
Write-Host "   2. APIs & Services > Credentials" -ForegroundColor White
Write-Host "   3. Android OAuth Client 선택" -ForegroundColor White
Write-Host "   4. Package name: app.insign" -ForegroundColor White
Write-Host "   5. SHA-1 지문 (위에서 확인) 입력" -ForegroundColor White
Write-Host ""

Write-Host "📋 Kakao Developers (Kakao 로그인)" -ForegroundColor Yellow
Write-Host "   1. https://developers.kakao.com/ 접속" -ForegroundColor White
Write-Host "   2. 내 애플리케이션 > 앱 설정 > 플랫폼" -ForegroundColor White
Write-Host "   3. Android 플랫폼 추가/수정" -ForegroundColor White
Write-Host "   4. 패키지명: app.insign" -ForegroundColor White
Write-Host "   5. 키 해시 (위에서 생성) 입력" -ForegroundColor White
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "완료!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
