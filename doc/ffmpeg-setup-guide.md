# FFmpeg 개발 라이브러리 설치 가이드

**작성일**: 2025-01-04
**목적**: sat-lec-rec 빌드를 위한 FFmpeg 개발 라이브러리 설치 방법

---

## 개요

sat-lec-rec은 libavcodec/libavformat을 직접 사용하여 Video(H.264) + Audio(AAC)를 인코딩합니다.
빌드를 위해서는 FFmpeg 개발용 라이브러리(.lib, .dll, 헤더 파일)가 필요합니다.

---

## 필요한 파일

```
third_party/ffmpeg/
├── include/           ← 헤더 파일
│   ├── libavcodec/
│   ├── libavformat/
│   ├── libavutil/
│   ├── libswscale/
│   └── libswresample/
├── lib/               ← import 라이브러리
│   ├── avcodec.lib
│   ├── avformat.lib
│   ├── avutil.lib
│   ├── swscale.lib
│   └── swresample.lib
└── bin/               ← 런타임 DLL
    ├── avcodec-*.dll
    ├── avformat-*.dll
    ├── avutil-*.dll
    ├── swscale-*.dll
    └── swresample-*.dll
```

---

## 다운로드 방법

### 방법 1: BtbN FFmpeg Builds (권장)

BtbN에서 제공하는 사전 빌드된 FFmpeg를 사용합니다.

**장점**:
- ✅ Windows용 사전 빌드
- ✅ .lib + .dll + 헤더 파일 모두 포함
- ✅ 최신 버전 (FFmpeg 7.1)

**단계**:

1. **릴리스 페이지 방문**:
   ```
   https://github.com/BtbN/FFmpeg-Builds/releases
   ```

2. **파일 다운로드** (약 90MB):
   ```
   ffmpeg-n7.1-latest-win64-gpl-shared-7.1.zip
   ```

   > ⚠️ 주의: `gpl-shared` 버전을 다운로드하세요 (lgpl 아님!)

3. **압축 해제**:
   - Windows에서 다운로드 폴더에 압축 해제
   - 예: `C:\Users\YourName\Downloads\ffmpeg-n7.1-latest-win64-gpl-shared-7.1\`

4. **파일 복사**:
   ```powershell
   # PowerShell에서 실행
   cd C:\ws-workspace\sat-lec-rec\third_party\ffmpeg

   # 다운로드 폴더 경로 (본인 경로로 수정)
   $src = "C:\Users\YourName\Downloads\ffmpeg-n7.1-latest-win64-gpl-shared-7.1"

   # 파일 복사
   Copy-Item -Path "$src\include" -Destination . -Recurse -Force
   Copy-Item -Path "$src\lib" -Destination . -Recurse -Force
   Copy-Item -Path "$src\bin" -Destination . -Recurse -Force
   ```

5. **확인**:
   ```powershell
   ls include\libavcodec  # avcodec.h 등이 보여야 함
   ls lib                 # avcodec.lib 등이 보여야 함
   ls bin                 # avcodec-*.dll 등이 보여야 함
   ```

### 방법 2: WSL에서 wget 사용

WSL 환경에서 직접 다운로드할 수도 있습니다.

```bash
cd ~/projects/sat-lec-rec/third_party

# 다운로드 (약 90MB)
wget https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n7.1-latest-win64-gpl-shared-7.1.zip -O ffmpeg-dev.zip

# 압축 해제
unzip ffmpeg-dev.zip

# 파일 복사
cd ffmpeg
mv ../ffmpeg-n7.1-*-win64-gpl-shared-7.1/include .
mv ../ffmpeg-n7.1-*-win64-gpl-shared-7.1/lib .
mv ../ffmpeg-n7.1-*-win64-gpl-shared-7.1/bin .

# 정리
rm -rf ../ffmpeg-n7.1-*-win64-gpl-shared-7.1 ../ffmpeg-dev.zip
```

---

## 빌드 설정 확인

CMakeLists.txt가 올바르게 설정되어 있는지 확인하세요:

```cmake
# FFmpeg 라이브러리 설정
set(FFMPEG_DIR "${CMAKE_SOURCE_DIR}/third_party/ffmpeg")
target_include_directories(${BINARY_NAME} PRIVATE "${FFMPEG_DIR}/include")
link_directories("${FFMPEG_DIR}/lib")

# FFmpeg 라이브러리 링크
target_link_libraries(${BINARY_NAME} PRIVATE
  avcodec
  avformat
  avutil
  swscale
  swresample
)
```

---

## 런타임 DLL 복사

빌드 후 실행 파일과 같은 디렉토리에 DLL이 있어야 합니다.

**자동 복사** (권장):

`windows/runner/CMakeLists.txt`에 다음 추가:

```cmake
# FFmpeg DLL 자동 복사
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${FFMPEG_DIR}/bin"
    $<TARGET_FILE_DIR:${BINARY_NAME}>
    COMMENT "Copying FFmpeg DLLs..."
)
```

**수동 복사**:

```powershell
# PowerShell에서
cd C:\ws-workspace\sat-lec-rec\build\windows\x64\runner\Debug
Copy-Item -Path "..\..\..\..\third_party\ffmpeg\bin\*.dll" -Destination .
```

---

## 문제 해결

### 1. "Cannot open include file: 'libavcodec/avcodec.h'"

**원인**: include 디렉토리가 없거나 경로가 잘못됨

**해결**:
```powershell
ls C:\ws-workspace\sat-lec-rec\third_party\ffmpeg\include\libavcodec
```
avcodec.h 파일이 보여야 합니다.

### 2. "Cannot open file 'avcodec.lib'"

**원인**: lib 디렉토리가 없거나 경로가 잘못됨

**해결**:
```powershell
ls C:\ws-workspace\sat-lec-rec\third_party\ffmpeg\lib
```
avcodec.lib 파일이 보여야 합니다.

### 3. 실행 시 "avcodec-*.dll을 찾을 수 없습니다"

**원인**: 런타임 DLL이 실행 파일과 같은 디렉토리에 없음

**해결**:
```powershell
cd C:\ws-workspace\sat-lec-rec\build\windows\x64\runner\Debug
Copy-Item -Path "..\..\..\..\third_party\ffmpeg\bin\*.dll" -Destination .
```

### 4. "LNK4272: library machine type 'x64' conflicts with target machine type 'x86'"

**원인**: 32비트 프로젝트로 빌드하려고 시도

**해결**:
- Flutter Windows 앱은 기본적으로 x64입니다
- `ffmpeg-n7.1-latest-win64-gpl-shared-7.1.zip` (64비트)를 사용하세요

---

## 버전 정보

- **FFmpeg**: 7.1 (2024-11)
- **빌드 타입**: GPL Shared
- **아키텍처**: x64 (64-bit)
- **빌더**: BtbN FFmpeg Builds

---

## Git 제외 설정

`.gitignore`에 다음이 포함되어 있는지 확인하세요:

```
# FFmpeg 바이너리 (용량이 크므로 Git에 포함하지 않음)
third_party/ffmpeg/bin/
third_party/ffmpeg/lib/
third_party/ffmpeg/include/

# 단, download_ffmpeg_dev.sh는 포함
!third_party/ffmpeg/download_ffmpeg_dev.sh
```

---

## 라이선스 주의사항

FFmpeg GPL 버전을 사용하므로:

- ✅ **개인 사용**: 문제 없음
- ✅ **오픈소스 배포**: GPL 라이선스 준수 필요
- ⚠️ **상업 배포**: GPL 조항에 따라 소스 코드 공개 의무

상업 배포를 고려한다면 LGPL 버전을 사용하거나 FFmpeg를 별도 프로세스로 실행하는 방식을 검토하세요.

---

## 참고 자료

- BtbN FFmpeg Builds: https://github.com/BtbN/FFmpeg-Builds
- FFmpeg 공식 문서: https://ffmpeg.org/documentation.html
- libavcodec API: https://ffmpeg.org/doxygen/trunk/group__lavc.html
