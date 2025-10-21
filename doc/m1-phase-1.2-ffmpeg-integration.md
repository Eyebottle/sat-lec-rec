# M1 Phase 1.2: 화면 녹화 패키지 통합 계획 (아키텍처 재설계)

**목표**: ~~C++에서 FFmpeg 프로세스 실행~~ → Flutter 패키지(`desktop_screen_recorder`)를 사용한 간소화된 녹화 구현

**예상 소요 시간**: ~~2~3시간~~ → 4~6시간 (아키텍처 변경 포함)

**의존성**: M0 완료, ~~FFI 기초 동작 확인~~ → Flutter 패키지 생태계 활용

**변경 사유**: C++ FFI 기반 FFmpeg 경로 해결 문제 지속 발생, eyebottlelee 프로젝트 참고하여 Flutter 패키지 기반으로 재설계

**작성일**: 2025-10-22 (재설계)

---

## 아키텍처 비교

### 기존 방식 (C++ FFI + FFmpeg) ❌
```
복잡도: Dart → C++ FFI → FFmpeg 프로세스 → Named Pipe → 인코딩

문제점:
- FFmpeg 경로 해결 실패 (fs::exists 문제, 5회 빌드 실패)
- 플랫폼 종속적 (Windows 전용)
- 수동 바이너리 관리 필요 (170MB ffmpeg.exe)
- 복잡한 디버깅
- 6개 파일 (C++ 4개, Dart 2개, CMakeLists.txt)
```

### 새로운 방식 (Flutter 패키지) ✅
```
단순화: Dart → desktop_screen_recorder → 자동 인코딩

장점:
- 경로 관리 자동화 (패키지가 처리)
- 크로스 플랫폼 (Windows/Linux/macOS)
- FFmpeg 바이너리 불필요
- 간단한 디버깅
- eyebottlelee 프로젝트와 동일한 패턴
- 1-2개 파일 (RecorderService)
```

---

## 1. 기존 코드 정리 (삭제)

### 1.1 C++ FFI 파일 삭제
```bash
# 다음 파일들 삭제
windows/runner/ffmpeg_runner.h
windows/runner/ffmpeg_runner.cpp
windows/runner/native_recorder_plugin.h
windows/runner/native_recorder_plugin.cpp
lib/ffi/native_bindings.dart
```

### 1.2 CMakeLists.txt 원복
```cmake
# windows/runner/CMakeLists.txt
# ffmpeg_runner.cpp, native_recorder_plugin.cpp 제거
# Flutter 기본 구조로 복원
```

### 1.3 main.dart FFI 코드 제거
```dart
// lib/main.dart에서 제거
// NativeRecorder.initialize();
// NativeRecorder.hello();
// NativeRecorder.checkFFmpeg();
// NativeRecorder.getFFmpegPath();
```

### 1.4 FFmpeg 바이너리 삭제
```bash
# third_party/ffmpeg/ 폴더 전체 삭제 (더 이상 불필요)
rm -rf third_party/ffmpeg/
```

---

## 2. Flutter 패키지 추가

### 2.1 pubspec.yaml 수정
```yaml
dependencies:
  flutter:
    sdk: flutter

  # 기존 패키지들...
  window_manager: ^0.5.1
  system_tray: ^2.0.3
  shared_preferences: ^2.3.2
  logger: ^2.4.0
  cron: ^0.5.1

  # 새로 추가: 화면 녹화 패키지
  desktop_screen_recorder: ^0.1.0  # 최신 버전 확인 필요
```

### 2.2 패키지 정보 확인
**desktop_screen_recorder** (pub.dev)
- Windows/Linux/macOS 지원
- H.264 MP4 인코딩 (네이티브 API 사용)
- 최소 CPU 부하
- FFmpeg 내장 (별도 배포 불필요)

### 2.3 패키지 설치
```bash
# WSL에서 실행
cd ~/projects/sat-lec-rec
flutter pub get
```

---

## 3. RecorderService 구현

### 3.1 파일 구조
```
lib/
├── main.dart
├── services/
│   └── recorder_service.dart  (새로 생성)
└── models/
    └── recording_session.dart  (선택: 메타데이터 관리)
```

### 3.2 RecorderService 기본 구조

#### lib/services/recorder_service.dart
```dart
// lib/services/recorder_service.dart
// 화면 + 오디오 녹화 서비스
//
// 목적: desktop_screen_recorder 패키지를 사용하여 화면과 오디오를 동시에 녹화
// 작성일: 2025-10-22

import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:desktop_screen_recorder/desktop_screen_recorder.dart';
import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
  ),
);

/// 화면 + 오디오 녹화 서비스
///
/// desktop_screen_recorder 패키지를 사용하여 간단하게 구현
class RecorderService {
  final ScreenRecorder _recorder = ScreenRecorder();
  bool _isRecording = false;
  DateTime? _sessionStartTime;

  /// 녹화 중 여부
  bool get isRecording => _isRecording;

  /// 녹화 시작
  ///
  /// @param duration 녹화 시간 (초 단위)
  /// @return 저장된 파일 경로
  Future<String?> startRecording({required int durationSeconds}) async {
    if (_isRecording) {
      logger.w('이미 녹화 중입니다');
      return null;
    }

    try {
      logger.i('🎬 녹화 시작 요청 ($durationSeconds초)');

      // 저장 경로 생성
      final outputPath = await _generateOutputPath();
      logger.i('📁 저장 경로: $outputPath');

      // 녹화 시작
      await _recorder.start(
        outputPath: outputPath,
        recordAudio: true,  // 오디오 포함
        fps: 24,            // 24fps
        quality: RecordingQuality.high,
      );

      _isRecording = true;
      _sessionStartTime = DateTime.now();
      logger.i('✅ 녹화 시작 완료');

      // N초 후 자동 중지
      Timer(Duration(seconds: durationSeconds), () async {
        await stopRecording();
      });

      return outputPath;
    } catch (e, stackTrace) {
      logger.e('❌ 녹화 시작 실패', error: e, stackTrace: stackTrace);
      _isRecording = false;
      rethrow;
    }
  }

  /// 녹화 중지
  ///
  /// @return 저장된 파일 경로
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      logger.w('녹화 중이 아닙니다');
      return null;
    }

    try {
      logger.i('⏹️  녹화 중지 요청');

      // 녹화 중지
      final filePath = await _recorder.stop();
      _isRecording = false;

      // 통계 출력
      if (_sessionStartTime != null) {
        final duration = DateTime.now().difference(_sessionStartTime!);
        logger.i('📊 세션 통계:');
        logger.i('  - 시작 시각: ${_sessionStartTime!.toIso8601String()}');
        logger.i('  - 총 녹화 시간: ${duration.inSeconds}초');
      }
      _sessionStartTime = null;

      // 파일 정보
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          final fileSize = await file.length();
          logger.i('📁 파일 저장 완료');
          logger.i('  - 경로: $filePath');
          logger.i('  - 크기: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');
        }
      }

      logger.i('✅ 녹화 중지 완료');
      return filePath;
    } catch (e, stackTrace) {
      logger.e('❌ 녹화 중지 실패', error: e, stackTrace: stackTrace);
      _isRecording = false;
      rethrow;
    }
  }

  /// 저장 파일 경로 생성
  ///
  /// @return 절대 경로 (예: D:/SaturdayZoomRec/20251022_0835_test.mp4)
  Future<String> _generateOutputPath() async {
    // TODO: 설정에서 저장 경로 가져오기 (SharedPreferences)
    // 현재는 Documents 폴더 사용
    final documentsDir = await getApplicationDocumentsDirectory();
    final recordingDir = Directory('${documentsDir.path}/SaturdayZoomRec');

    // 폴더 생성 (없으면)
    if (!await recordingDir.exists()) {
      await recordingDir.create(recursive: true);
    }

    // 파일명 생성: YYYYMMDD_HHMM_test.mp4
    final now = DateTime.now();
    final filename = '${_formatDate(now)}_${_formatTime(now)}_test.mp4';

    return '${recordingDir.path}/$filename';
  }

  /// 날짜 포맷 (YYYYMMDD)
  String _formatDate(DateTime dt) {
    return '${dt.year}${_twoDigits(dt.month)}${_twoDigits(dt.day)}';
  }

  /// 시간 포맷 (HHMM)
  String _formatTime(DateTime dt) {
    return '${_twoDigits(dt.hour)}${_twoDigits(dt.minute)}';
  }

  /// 두 자리 숫자 포맷
  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// 리소스 정리
  void dispose() {
    _recorder.dispose();
  }
}
```

---

## 4. UI 연동

### 4.1 main.dart 수정
```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'services/recorder_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Window 관리 초기화 (기존 코드 유지)
  await windowManager.ensureInitialized();
  // ... (기존 windowOptions 코드)

  runApp(const MyApp());
}

// ... (MyApp, MainScreen 기존 코드)

// _MainScreenState에 RecorderService 추가
class _MainScreenState extends State<MainScreen> with WindowListener {
  final RecorderService _recorderService = RecorderService();

  @override
  void dispose() {
    _recorderService.dispose();
    windowManager.removeListener(this);
    super.dispose();
  }

  // "10초 테스트" 버튼 핸들러 수정
  void _onTestRecordingPressed() async {
    try {
      final filePath = await _recorderService.startRecording(
        durationSeconds: 10,
      );

      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('10초 녹화 시작: $filePath')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('녹화 시작 실패: $e')),
      );
    }
  }

  // ... (기존 build 메서드, 버튼 onPressed에 _onTestRecordingPressed 연결)
}
```

---

## 5. 테스트 시나리오

### 5.1 패키지 설치 확인
```bash
# WSL
cd ~/projects/sat-lec-rec
flutter pub get

# Windows (동기화 후)
cd C:\ws-workspace\sat-lec-rec
flutter pub get
```

### 5.2 빌드 테스트
```bash
# Windows
cd C:\ws-workspace\sat-lec-rec
flutter build windows --debug
```

### 5.3 10초 녹화 테스트
```
1. 앱 실행
2. "10초 테스트" 버튼 클릭
3. 로그 확인:
   - "🎬 녹화 시작 요청 (10초)"
   - "📁 저장 경로: ..."
   - "✅ 녹화 시작 완료"
4. 10초 대기
5. 로그 확인:
   - "⏹️  녹화 중지 요청"
   - "📊 세션 통계: ..."
   - "📁 파일 저장 완료"
   - "✅ 녹화 중지 완료"
6. 파일 탐색기에서 mp4 파일 확인
7. VLC로 재생: 화면 + 소리 확인
```

---

## 6. 체크리스트

### Phase 1: 기존 코드 정리
- [ ] `windows/runner/ffmpeg_runner.*` 삭제
- [ ] `windows/runner/native_recorder_plugin.*` 삭제
- [ ] `lib/ffi/native_bindings.dart` 삭제
- [ ] `windows/runner/CMakeLists.txt` 원복
- [ ] `lib/main.dart`에서 FFI 코드 제거
- [ ] `third_party/ffmpeg/` 폴더 삭제

### Phase 2: 패키지 통합
- [ ] `pubspec.yaml`에 `desktop_screen_recorder` 추가
- [ ] `flutter pub get` 실행 (WSL & Windows)
- [ ] `lib/services/recorder_service.dart` 생성
- [ ] RecorderService 기본 구조 구현

### Phase 3: UI 연동
- [ ] `lib/main.dart`에 RecorderService 추가
- [ ] "10초 테스트" 버튼 핸들러 연결
- [ ] 녹화 상태 UI 업데이트 (선택)

### Phase 4: 테스트
- [ ] WSL → Windows 동기화
- [ ] Windows에서 빌드 (`flutter build windows --debug`)
- [ ] 10초 녹화 테스트 성공
- [ ] MP4 파일 생성 및 재생 확인
- [ ] 로그 확인 (정상 흐름)

---

## 7. 예상 효과

| 항목 | 기존 방식 (C++ FFI) | 새로운 방식 (Flutter 패키지) |
|------|-------------------|--------------------------|
| **코드 복잡도** | 6개 파일, C++ + Dart | 1-2개 파일, Dart만 |
| **경로 관리** | 수동 (실패함) | 자동 (패키지가 처리) |
| **FFmpeg 배포** | 필요 (170MB) | 불필요 (패키지 내장) |
| **디버깅 난이도** | 매우 어려움 | 쉬움 |
| **크로스 플랫폼** | Windows만 | Windows/Linux/macOS |
| **개발 속도** | 느림 (5회 실패) | 빠름 (eyebottlelee 참고) |

---

## 8. 다음 단계 (Phase 1.3)

- ~~Named Pipe 생성 및 테스트~~ → 패키지가 자동 처리
- ~~FFmpeg 프로세스에 stdin으로 데이터 전달~~ → 패키지가 자동 처리
- **Zoom 창 타깃 캡처** (desktop_screen_recorder API 확인)
- **오디오 장치 선택** (Loopback + 마이크 믹스)
- **세그먼트 저장** (45분 단위 분할)

---

## 참고 자료

### Flutter 패키지
- [desktop_screen_recorder - pub.dev](https://pub.dev/packages/desktop_screen_recorder)
- [record - pub.dev](https://pub.dev/packages/record) (eyebottlelee 프로젝트 사용)

### 참고 프로젝트
- eyebottlelee (`~/projects/eyebottlelee`): `record` 패키지 사용한 오디오 녹음 구현

---

**작성일**: 2025-10-22
**버전**: v2.0 (아키텍처 재설계)
**작성자**: AI 협업 (Claude Code)
