#!/usr/bin/env bash
# sat-lec-rec 개발 환경 검증 스크립트
# 작성일: 2025-10-21
# 설명: M0 환경 설정 완료 여부를 자동으로 검증합니다.

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 결과 카운터
PASSED=0
FAILED=0
WARNINGS=0

# 헬퍼 함수
print_header() {
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}  SAT-LEC-REC 개발 환경 검증${NC}"
    echo -e "${BLUE}===================================================${NC}"
    echo ""
}

print_section() {
    echo -e "${YELLOW}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}  ✓ $1${NC}"
    ((PASSED++))
}

print_fail() {
    echo -e "${RED}  ✗ $1${NC}"
    ((FAILED++))
}

print_warning() {
    echo -e "${YELLOW}  ⚠ $1${NC}"
    ((WARNINGS++))
}

print_info() {
    echo -e "    $1"
}

print_summary() {
    echo ""
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}  검증 결과 요약${NC}"
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${GREEN}  성공: $PASSED${NC}"
    echo -e "${RED}  실패: $FAILED${NC}"
    echo -e "${YELLOW}  경고: $WARNINGS${NC}"
    echo ""

    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ 모든 필수 검증 통과! 개발을 시작할 수 있습니다.${NC}"
        echo ""
        echo -e "${BLUE}다음 단계:${NC}"
        echo "  1. doc/development-roadmap.md 참조"
        echo "  2. Phase 1: 기초 인프라 구축 시작"
        echo "  3. FFI 기초 구조 (Dart ↔ C++ Hello World)"
        return 0
    else
        echo -e "${RED}✗ $FAILED개 항목이 실패했습니다.${NC}"
        echo -e "${YELLOW}해결 방법: doc/m0-environment-setup.md 참조${NC}"
        return 1
    fi
}

# =============================================================================
# 검증 시작
# =============================================================================

print_header

# -----------------------------------------------------------------------------
# 1. WSL 환경 검증
# -----------------------------------------------------------------------------
print_section "1. WSL 환경 검증"

# 1.1 OS 버전 확인
if lsb_release -a 2>/dev/null | grep -q "Ubuntu 24.04"; then
    print_success "Ubuntu 24.04 확인"
else
    OS_VERSION=$(lsb_release -rs 2>/dev/null || echo "Unknown")
    print_warning "Ubuntu 24.04 권장 (현재: Ubuntu $OS_VERSION)"
fi

# 1.2 Git 설치 확인
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | awk '{print $3}')
    print_success "Git 설치됨 (버전: $GIT_VERSION)"
else
    print_fail "Git 미설치"
    print_info "설치: sudo apt install git"
fi

# 1.3 rsync 설치 확인
if command -v rsync &> /dev/null; then
    print_success "rsync 설치됨"
else
    print_fail "rsync 미설치"
    print_info "설치: sudo apt install rsync"
fi

# 1.4 WSL Flutter 설치 확인
if [ -d "$HOME/.local/flutter" ]; then
    print_success "WSL Flutter SDK 존재 (~/.local/flutter)"

    # PATH 확인
    if command -v flutter &> /dev/null; then
        FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -n1 | awk '{print $2}')
        if [ -n "$FLUTTER_VERSION" ]; then
            print_success "WSL Flutter 실행 가능 (버전: $FLUTTER_VERSION)"
        else
            print_warning "Flutter 실행되지만 버전 확인 실패"
        fi
    else
        print_fail "Flutter PATH 미설정"
        print_info "해결: echo 'export PATH=\"\$HOME/.local/flutter/bin:\$PATH\"' >> ~/.bashrc"
        print_info "      source ~/.bashrc"
    fi
else
    print_fail "WSL Flutter SDK 미설치 (~/.local/flutter 없음)"
    print_info "설치: git clone https://github.com/flutter/flutter.git -b stable ~/.local/flutter --depth 1"
fi

# 1.5 Git 사용자 정보 확인
GIT_USER=$(git config --global user.name 2>/dev/null || echo "")
GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

if [ -n "$GIT_USER" ] && [ -n "$GIT_EMAIL" ]; then
    print_success "Git 사용자 정보 설정됨 ($GIT_USER <$GIT_EMAIL>)"
else
    print_warning "Git 사용자 정보 미설정"
    print_info "설정: git config --global user.name \"Your Name\""
    print_info "      git config --global user.email \"your@email.com\""
fi

echo ""

# -----------------------------------------------------------------------------
# 2. Windows 환경 검증 (접근 가능한 항목만)
# -----------------------------------------------------------------------------
print_section "2. Windows 환경 검증"

# 2.1 Windows Flutter 확인
if [ -d "/mnt/c/flutter" ]; then
    print_success "Windows Flutter SDK 존재 (C:\\flutter)"
else
    print_fail "Windows Flutter SDK 미설치 (C:\\flutter 없음)"
    print_info "설치: Windows PowerShell에서"
    print_info "      git clone https://github.com/flutter/flutter.git -b stable C:\\flutter --depth 1"
fi

# 2.2 Windows 동기화 폴더 확인
if [ -d "/mnt/c/ws-workspace/sat-lec-rec" ]; then
    print_success "Windows 동기화 폴더 존재 (C:\\ws-workspace\\sat-lec-rec)"

    # pubspec.yaml 확인
    if [ -f "/mnt/c/ws-workspace/sat-lec-rec/pubspec.yaml" ]; then
        print_success "Windows 동기화 폴더에 프로젝트 파일 확인"
    else
        print_warning "Windows 동기화 폴더가 비어있음"
        print_info "동기화: bash ~/projects/sat-lec-rec/scripts/sync_wsl_to_windows.sh"
    fi
else
    print_warning "Windows 동기화 폴더 없음 (C:\\ws-workspace\\sat-lec-rec)"
    print_info "생성: Windows PowerShell에서"
    print_info "      New-Item -ItemType Directory -Path C:\\ws-workspace\\sat-lec-rec"
fi

# 2.3 FFmpeg 바이너리 확인
if [ -f "/mnt/c/ws-workspace/sat-lec-rec/third_party/ffmpeg/ffmpeg.exe" ]; then
    print_success "FFmpeg 바이너리 존재 (ffmpeg.exe)"
else
    print_fail "FFmpeg 바이너리 없음"
    print_info "다운로드: https://github.com/BtbN/FFmpeg-Builds/releases"
    print_info "배치: ffmpeg.exe → C:\\ws-workspace\\sat-lec-rec\\third_party\\ffmpeg\\"
fi

if [ -f "/mnt/c/ws-workspace/sat-lec-rec/third_party/ffmpeg/ffprobe.exe" ]; then
    print_success "FFprobe 바이너리 존재 (ffprobe.exe)"
else
    print_fail "FFprobe 바이너리 없음"
    print_info "배치: ffprobe.exe → C:\\ws-workspace\\sat-lec-rec\\third_party\\ffmpeg\\"
fi

echo ""

# -----------------------------------------------------------------------------
# 3. 프로젝트 설정 검증
# -----------------------------------------------------------------------------
print_section "3. 프로젝트 설정 검증"

# 3.1 프로젝트 디렉토리 확인
PROJECT_DIR="$HOME/projects/sat-lec-rec"
if [ -d "$PROJECT_DIR" ]; then
    print_success "프로젝트 디렉토리 존재 ($PROJECT_DIR)"

    # Git 저장소 확인
    if [ -d "$PROJECT_DIR/.git" ]; then
        print_success "Git 저장소 초기화됨"

        # Git safe.directory 확인
        cd "$PROJECT_DIR"
        if git status &>/dev/null; then
            print_success "Git safe.directory 설정 완료"
        else
            print_fail "Git safe.directory 미설정"
            print_info "설정: git config --global --add safe.directory $PROJECT_DIR"
        fi
    else
        print_fail "Git 저장소 미초기화"
    fi

    # pubspec.yaml 확인
    if [ -f "$PROJECT_DIR/pubspec.yaml" ]; then
        print_success "pubspec.yaml 존재"

        # flutter pub get 확인 (.dart_tool 존재 여부)
        if [ -d "$PROJECT_DIR/.dart_tool" ]; then
            print_success "flutter pub get 실행됨"
        else
            print_warning "flutter pub get 미실행"
            print_info "실행: cd $PROJECT_DIR && flutter pub get"
        fi
    fi
else
    print_fail "프로젝트 디렉토리 없음 ($PROJECT_DIR)"
    print_info "클론: cd ~/projects && git clone git@github.com:Eyebottle/sat-lec-rec.git"
fi

# 3.2 동기화 스크립트 확인
SYNC_SCRIPT="$PROJECT_DIR/scripts/sync_wsl_to_windows.sh"
if [ -f "$SYNC_SCRIPT" ]; then
    print_success "동기화 스크립트 존재"

    if [ -x "$SYNC_SCRIPT" ]; then
        print_success "동기화 스크립트 실행 권한 있음"
    else
        print_warning "동기화 스크립트 실행 권한 없음"
        print_info "권한 부여: chmod +x $SYNC_SCRIPT"
    fi
else
    print_warning "동기화 스크립트 없음"
fi

# 3.3 alias 설정 확인
if grep -q "alias syncsat=" ~/.bashrc 2>/dev/null; then
    print_success "syncsat alias 설정됨"
else
    print_warning "syncsat alias 미설정"
    print_info "설정: echo 'alias syncsat=\"~/projects/sat-lec-rec/scripts/sync_wsl_to_windows.sh\"' >> ~/.bashrc"
fi

echo ""

# -----------------------------------------------------------------------------
# 4. 추가 도구 확인
# -----------------------------------------------------------------------------
print_section "4. 추가 도구 (선택)"

# pnpm 확인
if command -v pnpm &> /dev/null; then
    PNPM_VERSION=$(pnpm --version)
    print_success "pnpm 설치됨 (버전: $PNPM_VERSION)"
else
    print_info "pnpm 미설치 (Flutter 프로젝트에는 불필요)"
fi

# Node.js 확인
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    print_success "Node.js 설치됨 (버전: $NODE_VERSION)"
else
    print_info "Node.js 미설치 (Flutter 프로젝트에는 불필요)"
fi

echo ""

# -----------------------------------------------------------------------------
# 결과 요약
# -----------------------------------------------------------------------------
print_summary