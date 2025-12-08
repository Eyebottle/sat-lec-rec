# sat-lec-rec AI 협업 가이드

본 문서는 AI(Claude)와 협업 시 준수해야 할 프로젝트 규칙과 컨텍스트입니다.

## 프로젝트 개요

**이름**: sat-lec-rec (토요일 강의 녹화)
**타입**: Flutter Windows Desktop 애플리케이션
**목적**: 토요일 Zoom 강의를 무인 자동 녹화하여 안정적으로 저장
**타깃**: 토요일 강의 운영자 (1인 사용자)

## 핵심 가치

1. **정시성**: T0±3초 내 녹화 시작
2. **완성률**: 4주 연속 95% 이상 성공률
3. **안정성**: Fragmented MP4 기반 크래시 복구
4. **단순함**: 링크·시각·시간 3가지만 입력

## 기술 스택

### 언어 및 프레임워크
- **Flutter 3.35.6** (Windows Desktop)
- **Dart 3.9.2**
- **C++** (네이티브 플러그인)

### 핵심 라이브러리
- `window_manager`: 창 관리
- `system_tray`: 시스템 트레이
- `shared_preferences`: 설정 저장
- `logger`: 구조화 로깅
- `cron`: 스케줄링
- `ffi`: Dart ↔ C++ 통신

### 네이티브 기술
- **Windows Graphics Capture API**: 화면 캡처
- **WASAPI Loopback**: 오디오 캡처
- **FFmpeg**: H.264/AAC 인코딩 (Named Pipe)
- **Task Scheduler**: 절전 해제 및 자동 실행

## 개발 환경

### WSL ↔ Windows 동기화 구조
```
WSL (Ubuntu 24.04.2)          Windows 11
~/projects/sat-lec-rec   →→→  C:\ws-workspace\sat-lec-rec
(개발 & 커밋)                  (빌드 & 실행)
```

### 워크플로우
1. WSL에서 코드 작성 및 `flutter analyze`
2. `git commit` → post-commit 훅으로 Windows 자동 동기화
3. Windows Android Studio에서 빌드 및 실행
4. 또는 수동 동기화: `syncsat` 명령어

### 빌드 산출물 제외
- `build/`, `.dart_tool/`, `.git/`은 동기화 제외
- `windows/flutter/ephemeral/`도 제외

## 코딩 컨벤션

### Dart 코드 스타일
- **명명**: camelCase (변수/함수), PascalCase (클래스)
- **파일명**: snake_case.dart
- **라인 길이**: 80자 권장, 120자 최대
- **정렬**: `dart format` 사용

### 디렉토리 구조
```
lib/
├── main.dart               # 엔트리 포인트
├── services/               # 비즈니스 로직 (녹화, 스케줄, 트레이, FFmpeg)
├── models/                 # 데이터 모델
├── ui/
│   ├── screens/           # 메인 화면, 설정 화면
│   └── widgets/           # 재사용 가능한 UI 컴포넌트
└── utils/                  # 유틸리티 함수

windows/                    # C++ 네이티브 플러그인
third_party/ffmpeg/         # FFmpeg 바이너리 (Git 제외)
```

### 주석 원칙
- 공개 API는 DartDoc (`///`) 필수
- 복잡한 로직은 `//` 주석으로 설명
- TODO는 `// TODO(이름): 설명` 형식

### 에러 처리
```dart
try {
  await riskyOperation();
} catch (e, stackTrace) {
  logger.error('작업 실패', error: e, stackTrace: stackTrace);
  // 사용자에게 알림 또는 재시도 로직
}
```

## 아키텍처 패턴

### 레이어 분리
```
UI Layer (Screens/Widgets)
    ↓
Service Layer (RecorderService, ScheduleService, ...)
    ↓
Native Layer (C++ FFI) → FFmpeg, WASAPI, Graphics Capture
```

### FFI 통신 패턴
```dart
// Dart → C++: 명령 전달만
nativeStartRecording();

// C++ → Dart: 상태 콜백
void Function(String status) onStatusChanged;
```

### 데이터 영속성
- **설정**: SharedPreferences (JSON)
- **녹화 메타**: `*.mp4.json` 파일
- **로그**: JSON Lines 형식, 30일/1GB 순환 보존

## 테스트 전략

### 단위 테스트
- 각 Service의 public 메서드
- Utils 함수

### 통합 테스트
- 예약 → 헬스체크 → 녹화 → 저장 End-to-End
- 장애 시나리오 (네트워크 단절, 디스크 부족, 장치 변경)

### 성능 테스트
- 120분 연속 녹화
- CPU 50% 이하, 메모리 증가 500MB 이하
- 드롭 프레임 1% 미만

## 문서 참고

- `doc/sat-lec-rec-prd.md`: 제품 요구사항 정의서
- `doc/developing.md`: 개발 진행 메모
- `doc/setting-sync-workflow.md`: 동기화 가이드

## Git 커밋 메시지

Conventional Commits 형식 사용:
```
feat: T-10 헬스체크 로직 구현
fix: 오디오 장치 변경 시 크래시 수정
docs: README에 FFmpeg 다운로드 링크 추가
refactor: ScheduleService 코드 정리
test: RecorderService 단위 테스트 추가
```

## 금지 사항

1. **절대 커밋하지 말 것**
   - FFmpeg 바이너리 (third_party/ffmpeg/*.exe)
   - 빌드 산출물 (build/, *.dll, *.exe)
   - 개인 설정 (.idea/, *.iml)

2. **하드코딩 금지**
   - 파일 경로는 `path_provider` 사용
   - 시간 관련은 DateTime.now() 사용
   - 설정값은 SharedPreferences에서 로드

3. **동기화 주의**
   - WSL에서 `flutter build windows` 금지 (Windows에서만 빌드)
   - Windows 폴더를 직접 수정하지 말 것 (WSL에서만 수정)

## AI 협업 시 요청 사항

1. **변경 전 확인**
   - PRD 및 CLAUDE.md 숙지 후 작업
   - 디렉토리 구조 준수
   - 기존 패키지 버전과 호환성 확인

2. **코드 작성 시**
   - DartDoc 주석 필수
   - 에러 처리 포함
   - 로깅 추가 (logger 사용)

3. **테스트 작성**
   - 새 기능은 테스트 코드와 함께 제공
   - 성능 영향 고려 (특히 FFI 호출)

4. **문서 업데이트**
   - 새 서비스/모델 추가 시 README 업데이트
   - 중요한 결정은 doc/developing.md에 기록

## 라이선스

**GPL 주의**: FFmpeg는 GPL 라이선스이므로, 상업 배포 시 라이선스 준수 필요.
