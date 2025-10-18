# sat-lec-rec

토요일 Zoom 강의 무인 자동 녹화 애플리케이션 (Windows Desktop)

[![GitHub](https://img.shields.io/badge/GitHub-Eyebottle%2Fsat--lec--rec-blue?logo=github)](https://github.com/Eyebottle/sat-lec-rec)
[![Flutter](https://img.shields.io/badge/Flutter-3.35.6-02569B?logo=flutter)](https://flutter.dev)
[![Windows](https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows)](https://www.microsoft.com/windows)

## 📋 개요

매주 토요일 강의를 정시에 자동으로 입장하고 안정적으로 녹화하는 Flutter Windows 데스크톱 앱입니다.

### 핵심 기능

- 🕐 **정시 자동 입장**: T0±3초 내 정확한 시작
- 🎥 **화면+소리 녹화**: Windows Graphics Capture + WASAPI
- ⚡ **하드웨어 가속**: NVENC/QSV/AMF 자동 감지
- 💾 **세그먼트 저장**: 45분 단위 안전 분할
- 🔧 **크래시 복구**: Fragmented MP4 기반 복구
- 📊 **헬스체크**: T-10분 사전 점검, T-2분 예열
- 🔔 **시스템 트레이**: 백그라운드 동작

## 🛠️ 기술 스택

- **Flutter 3.35.6** (Windows Desktop)
- **Dart 3.9.2**
- **C++ Native Plugin** (dart:ffi)
- **FFmpeg** (H.264/AAC encoding)
- **Windows Graphics Capture API**
- **WASAPI** (Audio Loopback)

## 📂 프로젝트 구조

```
sat-lec-rec/
├── lib/
│   ├── main.dart           # 엔트리 포인트
│   ├── services/           # 녹화, 스케줄, 트레이 서비스
│   ├── models/             # 데이터 모델
│   ├── ui/
│   │   ├── screens/       # 메인 화면, 설정 화면
│   │   └── widgets/       # UI 컴포넌트
│   └── utils/              # 유틸리티
├── windows/                # Windows 네이티브 코드
├── third_party/ffmpeg/     # FFmpeg 바이너리 (별도 다운로드)
├── doc/                    # PRD 및 개발 문서
└── scripts/                # WSL↔Windows 동기화 스크립트
```

## 🚀 시작하기

### 필수 요구사항

#### WSL (Ubuntu 24.04.2)
- Flutter SDK 3.35.6+
- Git, rsync

#### Windows 11
- Flutter SDK 3.35.6+
- Visual Studio 2022 (Desktop development with C++)
- Android Studio (선택)
- FFmpeg 바이너리 (https://github.com/BtbN/FFmpeg-Builds/releases)

### WSL 설치

```bash
# Flutter SDK 설치
cd ~/
git clone https://github.com/flutter/flutter.git -b stable ~/.local/flutter --depth 1

# PATH 추가
echo 'export PATH="$HOME/.local/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Flutter 확인
flutter doctor

# Windows desktop 활성화
flutter config --enable-windows-desktop
```

### 프로젝트 설정

```bash
# 프로젝트 클론
cd ~/projects
git clone git@github.com:Eyebottle/sat-lec-rec.git
cd sat-lec-rec

# 의존성 설치
flutter pub get

# 동기화 alias 추가 (이미 ~/.bashrc에 있음)
alias syncsat='~/projects/sat-lec-rec/scripts/sync_wsl_to_windows.sh'
```

### FFmpeg 설정

1. [FFmpeg Builds](https://github.com/BtbN/FFmpeg-Builds/releases)에서 다운로드
   - 권장: `ffmpeg-master-latest-win64-gpl.zip`
2. 압축 해제 후 `bin/` 내 파일을 `C:\ws-workspace\sat-lec-rec\third_party\ffmpeg\`에 복사
   - `ffmpeg.exe`
   - `ffprobe.exe`

### Windows 경로 준비

PowerShell에서 실행:

```powershell
# 디렉토리 생성
New-Item -ItemType Directory -Path C:\ws-workspace\sat-lec-rec

# Windows Defender 예외 추가 (선택, 성능 향상)
Add-MpPreference -ExclusionPath "C:\ws-workspace\sat-lec-rec"
```

## 💻 개발 워크플로우

### WSL에서 개발

```bash
# 코드 작성
code .

# 분석
flutter analyze

# 동기화 상태 확인
checksync

# 빠른 동기화 (동기화 + 실행 안내)
qsync

# Git 커밋 (자동 동기화됨)
git add .
git commit -m "feat: 새 기능 추가"
```

### Windows에서 빌드/실행

#### 방법 1: 안드로이드 스튜디오 (권장)
```
1. 프로젝트 열기: C:\ws-workspace\sat-lec-rec
2. Shift+F10 또는 Run 버튼 클릭
3. 자동으로 코드 변경 감지 및 핫 리로드
```

#### 방법 2: 명령줄
```bash
cd C:\ws-workspace\sat-lec-rec
flutter run -d windows
```

#### 방법 3: 수동 동기화 후 실행
```bash
# WSL에서
syncsat

# Windows에서
flutter run -d windows
```

### 🔄 동기화 명령어

| 명령어 | 설명 |
|--------|------|
| `syncsat` | WSL → Windows 수동 동기화 |
| `checksync` | 동기화 상태 확인 |
| `qsync` | 빠른 동기화 + 실행 가이드 |
| `git commit` | 커밋 시 자동 동기화 (post-commit 훅) |

## 📖 문서

- [CLAUDE.md](./CLAUDE.md) - AI 협업 가이드
- [doc/sat-lec-rec-prd.md](./doc/sat-lec-rec-prd.md) - 제품 요구사항 정의서
- [doc/developing.md](./doc/developing.md) - 개발 진행 메모
- [doc/setting-sync-workflow.md](./doc/setting-sync-workflow.md) - 동기화 가이드

## 🧪 테스트

```bash
# 단위 테스트
flutter test

# 통합 테스트
flutter test integration_test/

# 분석
flutter analyze
```

## 📦 빌드

```bash
# Windows에서 실행
flutter build windows --release

# 산출물
build/windows/x64/runner/Release/sat_lec_rec.exe
```

## 🔍 주요 마일스톤

- [x] **M0**: 프로젝트 초기 설정
- [ ] **M1**: 녹화 코어 (화면+소리, 10초 테스트, Fragmented MP4)
- [ ] **M2**: 정시 자동화 (예약, 헬스체크, 예열, 정시 시작)
- [ ] **M3**: 안정성 (세그먼트, 크래시 복구, 장치 가드)
- [ ] **M4**: UX/배포 (트레이, 핫키, 코드 서명)

## 🎯 성공 기준

- **정시성**: T0±3초 내 녹화 시작
- **완성률**: 4주 연속 95% 이상 성공률
- **품질**: 720p/24fps, 드롭률 < 1%
- **성능**: CPU 50% 미만, 메모리 증가 500MB 이하

## ⚠️ 라이선스

FFmpeg는 GPL 라이선스입니다. 상업 배포 시 라이선스 준수 필요.

## 🤝 기여

PRD 및 CLAUDE.md를 참고하여 기여해주세요.
