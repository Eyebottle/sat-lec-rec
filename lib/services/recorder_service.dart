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

final _logger = Logger(
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
  /// @param durationSeconds 녹화 시간 (초 단위)
  /// @return 저장된 파일 경로
  Future<String?> startRecording({required int durationSeconds}) async {
    if (_isRecording) {
      _logger.w('이미 녹화 중입니다');
      return null;
    }

    try {
      _logger.i('🎬 녹화 시작 요청 ($durationSeconds초)');

      // 저장 경로 생성
      final outputPath = await _generateOutputPath();
      _logger.i('📁 저장 경로: $outputPath');

      // 녹화 시작
      await _recorder.start(
        outputPath: outputPath,
        recordAudio: true,  // 오디오 포함
        fps: 24,            // 24fps
        quality: RecordingQuality.high,
      );

      _isRecording = true;
      _sessionStartTime = DateTime.now();
      _logger.i('✅ 녹화 시작 완료');

      // N초 후 자동 중지
      Timer(Duration(seconds: durationSeconds), () async {
        await stopRecording();
      });

      return outputPath;
    } catch (e, stackTrace) {
      _logger.e('❌ 녹화 시작 실패', error: e, stackTrace: stackTrace);
      _isRecording = false;
      rethrow;
    }
  }

  /// 녹화 중지
  ///
  /// @return 저장된 파일 경로
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      _logger.w('녹화 중이 아닙니다');
      return null;
    }

    try {
      _logger.i('⏹️  녹화 중지 요청');

      // 녹화 중지
      final filePath = await _recorder.stop();
      _isRecording = false;

      // 통계 출력
      if (_sessionStartTime != null) {
        final duration = DateTime.now().difference(_sessionStartTime!);
        _logger.i('📊 세션 통계:');
        _logger.i('  - 시작 시각: ${_sessionStartTime!.toIso8601String()}');
        _logger.i('  - 총 녹화 시간: ${duration.inSeconds}초');
      }
      _sessionStartTime = null;

      // 파일 정보
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          final fileSize = await file.length();
          _logger.i('📁 파일 저장 완료');
          _logger.i('  - 경로: $filePath');
          _logger.i('  - 크기: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');
        }
      }

      _logger.i('✅ 녹화 중지 완료');
      return filePath;
    } catch (e, stackTrace) {
      _logger.e('❌ 녹화 중지 실패', error: e, stackTrace: stackTrace);
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
