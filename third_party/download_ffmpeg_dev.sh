#!/bin/bash
set -e

echo "FFmpeg 개발 라이브러리 다운로드 중..."

# BtbN FFmpeg Builds (Windows, shared)
FFMPEG_VERSION="7.1"
DOWNLOAD_URL="https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n${FFMPEG_VERSION}-latest-win64-gpl-shared-${FFMPEG_VERSION}.zip"

echo "다운로드 URL: $DOWNLOAD_URL"
echo ""
echo "수동 다운로드 필요:"
echo "1. 브라우저에서 다음 페이지 방문:"
echo "   https://github.com/BtbN/FFmpeg-Builds/releases"
echo ""
echo "2. 'ffmpeg-n7.1-latest-win64-gpl-shared-7.1.zip' 파일 다운로드"
echo ""
echo "3. Windows에서 압축 해제 후 다음 구조로 복사:"
echo "   sat-lec-rec/third_party/ffmpeg/"
echo "   ├── include/"
echo "   ├── lib/"
echo "   └── bin/"
echo ""
echo "또는 WSL에서 wget으로 다운로드 가능:"
echo "wget '$DOWNLOAD_URL' -O ffmpeg-dev.zip"
echo "unzip ffmpeg-dev.zip"
echo "mv ffmpeg-n${FFMPEG_VERSION}-*-win64-gpl-shared-${FFMPEG_VERSION}/* ffmpeg/"

