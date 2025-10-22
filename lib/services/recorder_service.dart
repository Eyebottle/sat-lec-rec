// lib/services/recorder_service.dart
// 화면 + 오디오 녹화 서비스
//
// 목적: Windows Native API(Graphics Capture + WASAPI)를 FFI로 호출하여 화면과 오디오를 동시에 녹화
// 작성일: 2025-10-22

import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:ffi/ffi.dart';
import '../ffi/native_bindings.dart';

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
/// Windows Native API를 FFI로 호출하여 구현
class RecorderService {
  bool _isInitialized = false;
  DateTime? _sessionStartTime;
  String? _currentFilePath;

  /// 녹화 중 여부
  bool get isRecording {
    if (!_isInitialized) return false;
    return NativeRecorderBindings.isRecording() == 1;
  }

  /// 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    final result = NativeRecorderBindings.initialize();
    if (result != 0) {
      final error = getNativeLastError();
      throw Exception('네이티브 녹화 초기화 실패: $error');
    }

    _isInitialized = true;
    _logger.i('✅ 네이티브 녹화 초기화 완료');
  }

  /// 녹화 시작
  ///
  /// @param durationSeconds 녹화 시간 (초 단위)
  /// @return 저장된 파일 경로
  Future<String?> startRecording({required int durationSeconds}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (isRecording) {
      _logger.w('이미 녹화 중입니다');
      return null;
    }

    try {
      _logger.i('🎬 녹화 시작 요청 ($durationSeconds초)');

      // 저장 경로 생성
      final outputPath = await _generateOutputPath();
      _logger.i('📁 저장 경로: $outputPath');

      // 네이티브 녹화 시작
      final pathPtr = outputPath.toNativeUtf8();
      try {
        final result = NativeRecorderBindings.startRecording(
          pathPtr,
          1920,  // TODO: 설정에서 가져오기
          1080,
          24,    // FPS
        );

        if (result != 0) {
          final error = getNativeLastError();
          throw Exception('네이티브 녹화 시작 실패: $error');
        }
      } finally {
        malloc.free(pathPtr);
      }

      _sessionStartTime = DateTime.now();
      _currentFilePath = outputPath;
      _logger.i('✅ 녹화 시작 완료');

      // N초 후 자동 중지
      Timer(Duration(seconds: durationSeconds), () async {
        await stopRecording();
      });

      return outputPath;
    } catch (e, stackTrace) {
      _logger.e('❌ 녹화 시작 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 녹화 중지
  ///
  /// @return 저장된 파일 경로
  Future<String?> stopRecording() async {
    if (!isRecording) {
      _logger.w('녹화 중이 아닙니다');
      return null;
    }

    try {
      _logger.i('⏹️  녹화 중지 요청');

      // 네이티브 녹화 중지
      final result = NativeRecorderBindings.stopRecording();
      if (result != 0) {
        final error = getNativeLastError();
        throw Exception('네이티브 녹화 중지 실패: $error');
      }

      // 통계 출력
      if (_sessionStartTime != null) {
        final duration = DateTime.now().difference(_sessionStartTime!);
        _logger.i('📊 세션 통계:');
        _logger.i('  - 시작 시각: ${_sessionStartTime!.toIso8601String()}');
        _logger.i('  - 총 녹화 시간: ${duration.inSeconds}초');
      }
      _sessionStartTime = null;

      // 파일 정보
      final filePath = _currentFilePath;
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          final fileSize = await file.length();
          _logger.i('📁 파일 저장 완료');
          _logger.i('  - 경로: $filePath');
          _logger.i('  - 크기: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');
        } else {
          _logger.w('⚠️  파일이 생성되지 않음: $filePath');
        }
      }

      _logger.i('✅ 녹화 중지 완료');
      _currentFilePath = null;
      return filePath;
    } catch (e, stackTrace) {
      _logger.e('❌ 녹화 중지 실패', error: e, stackTrace: stackTrace);
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
    if (_isInitialized) {
      NativeRecorderBindings.cleanup();
      _isInitialized = false;
      _logger.i('✅ 네이티브 녹화 리소스 정리 완료');
    }
  }
}
