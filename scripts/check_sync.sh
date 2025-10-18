#!/usr/bin/env bash
# WSL과 Windows 간 동기화 상태 확인 스크립트

set -euo pipefail

WSL_DIR="/home/usereyebottle/projects/sat-lec-rec"
WIN_DIR="/mnt/c/ws-workspace/sat-lec-rec"

echo "🔍 동기화 상태 확인 중..."
echo ""

# Windows 경로 존재 확인
if [ ! -d "$WIN_DIR" ]; then
    echo "❌ Windows 경로가 존재하지 않습니다: $WIN_DIR"
    echo "   PowerShell에서 먼저 폴더를 생성하세요:"
    echo "   New-Item -ItemType Directory -Path C:\ws-workspace\sat-lec-rec"
    exit 1
fi

# 주요 파일 동기화 확인
echo "📁 주요 파일 동기화 상태:"
echo ""

check_file() {
    local file=$1
    local wsl_file="$WSL_DIR/$file"
    local win_file="$WIN_DIR/$file"

    if [ ! -f "$wsl_file" ]; then
        echo "  ⚠️  $file - WSL에 없음"
        return
    fi

    if [ ! -f "$win_file" ]; then
        echo "  ❌ $file - Windows에 없음 (동기화 필요)"
        return
    fi

    # 파일 크기 비교
    wsl_size=$(stat -c%s "$wsl_file" 2>/dev/null || echo "0")
    win_size=$(stat -c%s "$win_file" 2>/dev/null || echo "0")

    # 수정 시간 비교
    wsl_time=$(stat -c%Y "$wsl_file" 2>/dev/null || echo "0")
    win_time=$(stat -c%Y "$win_file" 2>/dev/null || echo "0")

    if [ "$wsl_size" != "$win_size" ]; then
        echo "  ⚠️  $file - 크기 다름 (WSL: ${wsl_size}B, Win: ${win_size}B)"
    elif [ "$wsl_time" -gt "$win_time" ]; then
        time_diff=$((wsl_time - win_time))
        echo "  ⏱️  $file - WSL이 ${time_diff}초 더 최신"
    else
        echo "  ✅ $file - 동기화됨"
    fi
}

# 주요 파일 확인
check_file "lib/main.dart"
check_file "pubspec.yaml"
check_file "README.md"
check_file "CLAUDE.md"

echo ""
echo "📊 전체 파일 비교:"
echo ""

# WSL에만 있는 파일 확인 (주요 파일만)
wsl_only=$(cd "$WSL_DIR" && find lib -type f -name "*.dart" 2>/dev/null | while read f; do
    if [ ! -f "$WIN_DIR/$f" ]; then
        echo "$f"
    fi
done)

if [ -n "$wsl_only" ]; then
    echo "  ⚠️  WSL에만 있는 파일:"
    echo "$wsl_only" | sed 's/^/     /'
else
    echo "  ✅ lib/ 폴더 동기화 완료"
fi

echo ""
echo "💡 동기화 명령어:"
echo "   수동 동기화: syncsat"
echo "   Git 커밋 시: 자동 동기화됨 (post-commit 훅)"
echo ""
