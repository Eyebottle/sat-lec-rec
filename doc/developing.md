# sat-lec-rec 개발 진행 메모

이 문서는 sat-lec-rec 프로젝트의 개발 환경 설정, 동기화, 기본 워크플로우를 기록한다. 실제 조치가 완료된 항목과 TODO를 함께 관리한다.

## 1. 필수 도구 체크리스트

- [ ] WSL2(Ubuntu) 최신 업데이트 (`sudo apt update && sudo apt upgrade`)
- [ ] Git, rsync 설치 (`sudo apt install git rsync`)
- [ ] Flutter SDK 설치 및 경로 설정(WSL) (`flutter doctor` 정상)
- [ ] Windows 11 측 Flutter SDK 설치 및 `flutter doctor` 정상
- [ ] Visual Studio 2022 Desktop development with C++ 워크로드 설치
- [ ] FFmpeg 64bit 바이너리 다운로드 후 `C:\ws-workspace\sat-lec-rec\third_party\ffmpeg` 배치
- [ ] Windows Defender 예외에 `C:\ws-workspace\sat-lec-rec` 추가

> NOTE: 아직 OS 레벨 설치는 수동 진행이 필요하며, 완료 후 체크 표시 예정.

## 2. 현재까지 수행한 설정

- [x] 프로젝트 루트에 `scripts/` 디렉터리 생성
- [x] `scripts/sync_wsl_to_windows.sh` 작성 및 실행 권한 부여
- [x] 동기화 스크립트 기본 제외 목록 정의 (`.git/`, `build/`, `.dart_tool/`, `.claude/`, `windows/flutter/ephemeral/`, `.vscode/settings.json`)
- [x] `git init` 실행으로 저장소 초기화 (2025-10-17)
- [x] `~/.bashrc`에 `alias syncsat=~/projects/sat-lec-rec/scripts/sync_wsl_to_windows.sh` 추가 (2025-10-17, WSL 계정 기준)
- [x] `.git/hooks/post-commit`에 동기화 스크립트 호출 훅 추가 (2025-10-17, git init 완료 후)
- [x] 동기화 스크립트 수동 실행으로 `C:\ws-workspace\sat-lec-rec` 초기 동기화 완료 (2025-10-17)
- [x] Flutter 프로젝트 초기화 및 기본 구조 생성 (2025-10-18)
- [x] WSL/Windows 별도 Flutter SDK 경로 설정 (`.vscode/settings.json`) (2025-10-18)

```bash
# 동기화 스크립트 실행 예시
~/projects/sat-lec-rec/scripts/sync_wsl_to_windows.sh
```

## 3. Windows 경로 준비 가이드

1. PowerShell 관리자 권한으로 실행
2. `New-Item -ItemType Directory -Path C:\ws-workspace\sat-lec-rec`로 빈 폴더 생성
3. Defender 실시간 보호 예외 등록
4. FFmpeg 압축 해제 후 `third_party\ffmpeg` 폴더 구성
5. Visual Studio에서 `C:\ws-workspace\sat-lec-rec`를 열어 Flutter Windows 빌드를 준비

## 4. 빌드 및 테스트 워크플로우(초안)

1. WSL에서 기능 개발 → `flutter analyze`, 단위 테스트 실행(Dart TBD)
2. `git commit` 실행 → post-commit 훅(설정 시)으로 Windows 경로 동기화
3. Windows 터미널에서 `flutter build windows` 또는 `flutter run -d windows`
4. 빌드 산출물 확인 후 메타 로그/QA 시트 업데이트

## 5. TODO / 다음 단계

- [ ] `.bashrc` alias, post-commit 훅 생성 후 이 문서에 완료 표시
- [ ] Flutter 프로젝트 초기화(`flutter create`) 시나리오 확정 및 공유
- [ ] FFmpeg 번들 버전/라이선스 검증
- [ ] Windows ↔ WSL 양방향 동기화 필요 여부 평가
- [ ] CI/CD(Windows Runner) 도입 검토 및 문서화

## 6. 참고 문서

- `doc/setting-sync-workflow.md`: 동기화 세부 가이드
- `doc/sat-lec-rec-prd.md`: PRD 및 체크리스트

## 7. 진행 로그

- 2025-10-17: Git 저장소 초기화, post-commit 훅 구성, `syncsat` alias 추가, 최초 rsync 수행으로 Windows 경로 생성 확인.
- 2025-10-18: Flutter 프로젝트 초기화 완료, 기본 UI 스캐폴딩 작성, 첫 커밋 및 GitHub 저장소 생성 완료 (https://github.com/Eyebottle/sat-lec-rec).
  - WSL Flutter SDK 3.35.6 설치
  - 의존성 37개 패키지 추가
  - VSCode/안드로이드 스튜디오 Dart SDK 설정
  - 동기화 스크립트 개선 (checksync, qsync 추가)
  - M0 마일스톤 완료: 프로젝트 초기 설정
- 2025-10-21: M1 Phase 1.1 FFI 기초 구조 구축 완료, M1 Phase 1.2 FFmpeg 런타임 통합 시도
  - C++ FFmpegRunner 클래스 구현 (ffmpeg_runner.h/cpp)
  - Dart FFI 바인딩 구현 (native_bindings.dart)
  - FFmpeg 경로 해결 시도 (5회 빌드, 모두 실패)
- 2025-10-22: **M1 Phase 1.2 아키텍처 재설계** (C++ FFI → Flutter 패키지)
  - C++ FFI 방식의 FFmpeg 경로 해결 문제 지속 (fs::exists 실패)
  - eyebottlelee 프로젝트 참고: `record` 패키지 사용 확인
  - **새로운 방향**: `desktop_screen_recorder` 패키지 기반 재설계 결정
  - 문서 업데이트:
    - `m1-phase-1.2-ffmpeg-integration.md`: 전면 재작성 (v2.0)
    - `development-roadmap.md`: Phase 1.2/1.3 수정
    - `developing.md`: 진행 로그 추가
  - **다음 작업**: 기존 C++ FFI 코드 제거 → RecorderService 구현
