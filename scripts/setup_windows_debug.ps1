# Windows VS Code 디버거 환경 설정 스크립트
# 
# 목적: launch.json은 Linux/Mac 스타일의 .venv/bin/python3.12 경로를 참조하지만,
#       Windows에서는 .venv/Scripts/python.exe에 파이썬이 존재합니다.
#       이 스크립트는 launch.json을 수정하지 않고,
#       Windows 가상환경의 python.exe를 launch.json이 찾는 경로에 복사합니다.
#
# 사용법: 프로젝트 루트 디렉토리에서 실행
#   .\scripts\setup_windows_debug.ps1
#
# 주의: 가상환경(.venv)을 재설치한 경우 이 스크립트를 다시 실행해야 합니다.

$scriptPath = $PSCommandPath
if ($scriptPath) {
    $bytes = [System.IO.File]::ReadAllBytes($scriptPath)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {
    }
    else {
        $bom = [byte[]](239, 187, 191)
        [System.IO.File]::WriteAllBytes($scriptPath, $bom + $bytes)
        Write-Host "[Encoding Fix] UTF-8 BOM has been added to the script file." -ForegroundColor Yellow
        Write-Host "[Encoding Fix] Please re-run the script to apply the correct Korean encoding!" -ForegroundColor Yellow
        exit
    }
}

chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Windows VS Code 디버거 환경 설정" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# launch.json에서 python 경로를 참조하는 백엔드 목록
$backends = @("auth", "base", "chat", "llm-gateway", "mcp")

$successCount = 0
$failCount = 0

foreach ($b in $backends) {
    $binDir = "backends\$b\.venv\bin"
    $scriptDir = "backends\$b\.venv\Scripts"

    Write-Host "[$b] 처리 중..." -NoNewline

    # 가상환경이 설치되어 있는지 확인
    if (-not (Test-Path "$scriptDir\python.exe")) {
        Write-Host " ❌ 가상환경(.venv)이 없습니다. 먼저 'uv sync'를 실행하세요." -ForegroundColor Red
        $failCount++
        continue
    }

    # bin 폴더가 없으면 생성
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Force -Path $binDir | Out-Null
    }

    # Scripts\python.exe → bin\python3.12 (확장자 없음: Linux/Mac 호환 경로)
    Copy-Item "$scriptDir\python.exe" -Destination "$binDir\python3.12" -Force

    # Scripts\python.exe → bin\python3.12.exe (확장자 있음: Windows 실행 안정성)
    Copy-Item "$scriptDir\python.exe" -Destination "$binDir\python3.12.exe" -Force

    Write-Host " ✅ 완료" -ForegroundColor Green
    $successCount++
}

Write-Host ""
Write-Host "--------------------------------------" -ForegroundColor DarkGray
Write-Host "결과: 성공 $successCount / 실패 $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Yellow" })
Write-Host ""

if ($failCount -gt 0) {
    Write-Host "⚠️  실패한 항목은 해당 디렉토리에서 'uv sync'를 먼저 실행 후 다시 시도하세요." -ForegroundColor Yellow
    Write-Host "   예시: cd backends\auth && uv sync" -ForegroundColor Yellow
    Write-Host ""
}

if ($successCount -gt 0) {
    Write-Host "✨ VS Code에서 [🚀]launch 컴파운드로 전체 서비스를 실행할 수 있습니다." -ForegroundColor Cyan
    Write-Host ""
}
