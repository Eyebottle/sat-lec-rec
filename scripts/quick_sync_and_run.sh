#!/usr/bin/env bash
# WSL에서 코드 수정 후 바로 Windows에서 실행하기 위한 빠른 동기화 스크립트

set -euo pipefail

echo "🔄 빠른 동기화 & 실행 준비..."
echo ""

# 1. 동기화 실행
echo "1️⃣ WSL → Windows 동기화 중..."
~/projects/sat-lec-rec/scripts/sync_wsl_to_windows.sh

# 2. 동기화 확인
echo ""
echo "2️⃣ 동기화 확인..."
~/projects/sat-lec-rec/scripts/check_sync.sh

# 3. Windows에서 실행할 명령어 안내
echo ""
echo "✅ 동기화 완료!"
echo ""
echo "📱 Windows에서 실행하려면:"
echo ""
echo "   [안드로이드 스튜디오]"
echo "   1. 프로젝트가 열려있으면 자동 새로고침됨"
echo "   2. Shift+F10 또는 Run 버튼 클릭"
echo ""
echo "   [명령 프롬프트/PowerShell]"
echo "   cd C:\\ws-workspace\\sat-lec-rec"
echo "   flutter run -d windows"
echo ""
