# sat-lec-rec 개발 환경 & 동기화 가이드

본 문서는 `/home/usereyebottle/projects/sat-lec-rec`(WSL)와 `C:\ws-workspace\sat-lec-rec`(Windows) 간 소스 동기화 및 Windows 빌드 실행 절차를 정리한다. Flutter Windows 앱을 안정적으로 빌드하려면 NTFS 경로에서도 동일한 소스를 유지해야 한다.

## 1. 준비 사항

- **필수 소프트웨어**
  - WSL2(Ubuntu) + Git + rsync
  - Windows 11 + PowerShell + Git for Windows
  - Flutter SDK(WSL 및 Windows 양쪽에 동일 버전 설치)
  - FFmpeg 바이너리(Windows 경로에 배포 예정)
- **권장 폴더 구조**
  - WSL 개발: `/home/usereyebottle/projects/sat-lec-rec`
  - Windows 빌드: `C:\ws-workspace\sat-lec-rec`
  - FFmpeg 런타임: `C:\ws-workspace\sat-lec-rec\third_party\ffmpeg`
- **초기 동기화**
  1. Windows에서 `C:\ws-workspace` 생성.
  2. PowerShell에서 빈 `sat-lec-rec` 폴더를 만들어 권한 확인.
  3. 첫 rsync 실행 전 Windows Defender 실시간 보호 예외에 `C:\ws-workspace\sat-lec-rec` 추가(대형 파일 복사 속도 향상).

## 2. 동기화 구성 요소

### 2.1 동기화 스크립트

- 생성 위치: `scripts/sync_wsl_to_windows.sh`
- 권장 내용:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  SRC="/home/usereyebottle/projects/sat-lec-rec/"
  DEST="/mnt/c/ws-workspace/sat-lec-rec/"

  rsync -a --delete \
    --exclude '.git/' \
    --exclude 'build/' \
    --exclude '.dart_tool/' \
    --exclude '.claude/' \
    --exclude 'windows/flutter/ephemeral/' \
    "$SRC" "$DEST"
  ```
- 스크립트 생성 후 `chmod +x scripts/sync_wsl_to_windows.sh` 수행.
- 필요 시 제외 목록에 `out/`, `artifacts/` 등 향후 빌드 산출물을 추가.

### 2.2 Git post-commit 훅(선택)

- 위치: `.git/hooks/post-commit`
- 역할: 커밋 직후 자동으로 동기화 스크립트 호출.
- 샘플:
  ```bash
  #!/usr/bin/env bash
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  "$REPO_ROOT/scripts/sync_wsl_to_windows.sh"
  ```
- 훅 파일에도 실행 권한 부여.

### 2.3 수동 실행 alias

- `~/.bashrc`에 아래 줄 추가:
  ```bash
  alias syncsat='~/projects/sat-lec-rec/scripts/sync_wsl_to_windows.sh'
  ```
- 새 터미널에서 `syncsat` 실행 시 즉시 동기화 가능.

## 3. 개발 흐름 권장 시나리오

1. WSL에서 코드 작성 및 `flutter analyze`/`dart test` 진행.
2. 기능이 안정화되면 `git commit` → post-commit 훅이 자동 동기화 실행.
3. Windows에서 `C:\ws-workspace\sat-lec-rec` 열어 `flutter build windows` 또는 Visual Studio로 실행.
4. 빌드 산출물은 Windows 폴더에 남고, WSL에는 생성되지 않으므로 디스크 사용량이 분리된다.

## 4. 수동 동기화가 필요한 상황

- 커밋 없이 빠르게 UI 변경 테스트.
- PRD 문서만 수정했지만 Windows 앱 실행 확인이 필요한 경우.
- 자동 동기화 스크립트 실패 후 재시도.

절차: WSL 터미널에서 `syncsat` 실행 → 완료 후 PowerShell/Explorer에서 변경 확인.

## 5. 검증 체크리스트

- [ ] `scripts/sync_wsl_to_windows.sh` 존재 및 실행 권한 확인.
- [ ] WSL과 Windows에 동일한 Flutter 버전(`flutter --version`) 사용.
- [ ] Windows 경로에서 `git status` 실행 시, 동기화 후 변경 사항 없음 확인.
- [ ] 첫 동기화 이후 Windows 빌드(`flutter build windows`) 성공.
- [ ] FFmpeg 및 기타 바이너리 경로가 Windows 쪽에서 올바르게 참조.

## 6. 문제 해결

| 증상 | 원인 | 해결 방법 |
|------|------|-----------|
| rsync Permission denied | Windows에서 파일 열려 있음 | Visual Studio/Explorer 종료 후 재시도 |
| rsync module not found | 경로 오타 | `SRC`, `DEST` 환경변수 확인 |
| Flutter ephemeral 폴더 충돌 | Windows 빌드 임시 폴더 권한 문제 | `windows/flutter/ephemeral/`을 삭제하고 재동기화, 제외 목록 유지 |
| 빌드 시 Dart SDK mismatch | Windows Flutter 버전 상이 | `flutter upgrade` 또는 동일 채널 재설치 |
| SmartScreen 경고 | 서명 없는 실행 파일 실행 | 사내 규정에 따라 예외 등록, 향후 코드 서명 적용 |

## 7. 향후 개선 아이디어

- inotify 기반 실시간 동기화(예: `watchexec`), 비활성화 시 CPU 사용량 고려.
- Windows → WSL 역방향 동기화 스크립트 작성(Windows에서만 수정하는 파일이 생길 경우).
- 동기화 로그를 `logs/sync.log`에 저장해 누락된 파일 추적.
- GitHub Actions 등 CI에서 Windows 빌드 후 생성물만 WSL로 풀어오는 자동화.

