#!/usr/bin/env bash
# FFmpeg 64bit Windows 바이너리 자동 다운로드 스크립트
# - BtbN FFmpeg Builds 깃허브 릴리스에서 ZIP 파일을 받아 third_party/ffmpeg 에 설치
# - WSL(프로젝트 디렉터리)와 Windows 동기화 디렉터리 둘 다에 복사

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THIRD_PARTY_DIR="$ROOT_DIR/third_party/ffmpeg"
WINDOWS_DIR="/mnt/c/ws-workspace/sat-lec-rec/third_party/ffmpeg"
API_URL="https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest"

CUSTOM_URL="${1:-}"

TMP_DIR="$(mktemp -d)"
ZIP_PATH="$TMP_DIR/ffmpeg.zip"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

resolve_download_url() {
  if [[ -n "$CUSTOM_URL" ]]; then
    echo "$CUSTOM_URL"
    return 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "❌ jq 명령어가 필요합니다. sudo apt install jq 로 설치해주세요." >&2
    exit 1
  fi

  echo "🔍 GitHub API에서 최신 릴리스 정보 조회..." >&2
  local url
  url="$(curl -s "$API_URL" | jq -r '.assets[] | select(.name | test("win64-gpl.*\\.zip$")) | select(.name | test("shared") | not) | .browser_download_url' | head -n 1)"

  if [[ -z "$url" || "$url" == "null" ]]; then
    echo "❌ FFmpeg win64 GPL 자산을 찾을 수 없습니다. GitHub 릴리스를 확인해주세요." >&2
    exit 1
  fi

  echo "$url"
}

DOWNLOAD_URL="$(resolve_download_url)"

echo "📥 다운로드 시작: $DOWNLOAD_URL"
curl -L "$DOWNLOAD_URL" -o "$ZIP_PATH"

echo "📦 압축 해제 중..."
unzip -q "$ZIP_PATH" -d "$TMP_DIR/extracted"

EXTRACTED_BIN_DIR="$(find "$TMP_DIR/extracted" -maxdepth 2 -type d -name bin | head -n 1)"
if [[ -z "$EXTRACTED_BIN_DIR" ]]; then
  echo "❌ bin 디렉터리를 찾을 수 없습니다. 릴리스 구조를 확인하세요." >&2
  exit 1
fi

mkdir -p "$THIRD_PARTY_DIR"
cp -f "$EXTRACTED_BIN_DIR/ffmpeg.exe" "$THIRD_PARTY_DIR/"
cp -f "$EXTRACTED_BIN_DIR/ffprobe.exe" "$THIRD_PARTY_DIR/"

if [[ -d "${WINDOWS_DIR%/ffmpeg}" ]]; then
  mkdir -p "$WINDOWS_DIR"
  cp -f "$EXTRACTED_BIN_DIR/ffmpeg.exe" "$WINDOWS_DIR/"
  cp -f "$EXTRACTED_BIN_DIR/ffprobe.exe" "$WINDOWS_DIR/"
  echo "✅ Windows 동기화 폴더에 복사 완료"
else
  echo "⚠️ Windows 경로를 찾을 수 없어 WSL 디렉터리에만 설치했습니다."
fi

echo "✅ FFmpeg 설치 완료"
