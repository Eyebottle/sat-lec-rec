// lib/services/logger_service.dart
// 로그 파일 관리 서비스
//
// 목적: 앱 전체에서 사용하는 통합 로깅 시스템
// - 로그 파일 크기 제한 (10MB)
// - 자동 로테이션 (일별 또는 크기 기준)
// - 오래된 로그 자동 삭제 (30일 이상)
// 작성일: 2025-11-07

import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

/// 로그 파일 관리 서비스
///
/// 앱 전체에서 사용하는 통합 로깅 시스템
/// - 콘솔 출력 + 파일 출력
/// - 로그 파일 크기 제한 및 자동 로테이션
/// - 오래된 로그 자동 삭제
class LoggerService {
  static LoggerService? _instance;
  static LoggerService get instance => _instance ??= LoggerService._();

  LoggerService._() {
    _initializeLogger();
  }

  late final Logger _logger;
  File? _currentLogFile;
  static const int _maxLogFileSizeMB = 10; // 10MB
  static const int _maxLogFileSizeBytes = _maxLogFileSizeMB * 1024 * 1024;
  static const int _maxLogAgeDays = 30; // 30일

  /// Logger 인스턴스 가져오기
  Logger get logger => _logger;

  /// 로거 초기화
  void _initializeLogger() {
    try {
      // 로그 디렉토리 생성
      final logDir = _getLogDirectory();
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }

      // 오래된 로그 파일 정리
      _cleanupOldLogs(logDir);

      // 현재 로그 파일 생성
      _currentLogFile = _getCurrentLogFile(logDir);

      // Logger 설정
      _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 5,
          lineLength: 120,
          colors: true,
          printEmojis: true,
          printTime: true,
        ),
        output: MultiOutput([
          ConsoleOutput(),
          _RotatingFileOutput(_currentLogFile!),
        ]),
        level: Level.info,  // debug → info로 변경하여 디버그 로그 제거
      );

      _logger.i('✅ LoggerService 초기화 완료');
      _logger.i('📁 로그 파일: ${_currentLogFile!.path}');
    } catch (e) {
      // 로그 초기화 실패 시 콘솔만 사용
      _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 5,
          lineLength: 80,
          colors: true,
          printEmojis: true,
        ),
      );
      _logger.e('❌ LoggerService 초기화 실패 (콘솔만 사용)', error: e);
    }
  }

  /// 로그 디렉토리 경로 가져오기
  Directory _getLogDirectory() {
    // Windows: C:\SatLecRec\logs
    // WSL: /mnt/c/SatLecRec/logs
    final logDirPath = r'C:\SatLecRec\logs';
    return Directory(logDirPath);
  }

  /// 현재 로그 파일 경로 가져오기
  File _getCurrentLogFile(Directory logDir) {
    final now = DateTime.now();
    final dateStr = '${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}';
    final filename = 'sat_lec_rec_$dateStr.log';
    return File(path.join(logDir.path, filename));
  }

  /// 두 자리 숫자 포맷
  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// 오래된 로그 파일 정리
  void _cleanupOldLogs(Directory logDir) {
    try {
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: _maxLogAgeDays));

      final logFiles = logDir.listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.log'))
          .toList();

      int deletedCount = 0;
      for (final file in logFiles) {
        final stat = file.statSync();
        final modified = DateTime.fromMillisecondsSinceEpoch(
          stat.modified.millisecondsSinceEpoch,
        );

        if (modified.isBefore(cutoffDate)) {
          file.deleteSync();
          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        print('🗑️ 오래된 로그 파일 $deletedCount개 삭제됨');
      }
    } catch (e) {
      print('⚠️ 로그 파일 정리 실패: $e');
    }
  }

  /// 로그 파일 크기 확인 및 로테이션
  void rotateLogIfNeeded() {
    if (_currentLogFile == null) return;

    try {
      if (_currentLogFile!.existsSync()) {
        final fileSize = _currentLogFile!.lengthSync();
        if (fileSize >= _maxLogFileSizeBytes) {
          _rotateLogFile();
        }
      }
    } catch (e) {
      print('⚠️ 로그 파일 크기 확인 실패: $e');
    }
  }

  /// 로그 파일 로테이션
  void _rotateLogFile() {
    if (_currentLogFile == null) return;

    try {
      final now = DateTime.now();
      final timestamp = '${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}_'
          '${_twoDigits(now.hour)}${_twoDigits(now.minute)}${_twoDigits(now.second)}';
      final rotatedPath = _currentLogFile!.path.replaceAll(
        '.log',
        '_$timestamp.log',
      );

      _currentLogFile!.renameSync(rotatedPath);
      _logger.i('🔄 로그 파일 로테이션: $rotatedPath');

      // 새 로그 파일 생성
      final logDir = _getLogDirectory();
      _currentLogFile = _getCurrentLogFile(logDir);

      // Logger 재초기화 (새 파일로)
      _initializeLogger();
    } catch (e) {
      _logger.e('❌ 로그 파일 로테이션 실패', error: e);
    }
  }

  /// 리소스 정리
  void dispose() {
    _logger.i('📍 LoggerService 종료');
  }
}

/// 로그 파일 출력 (로테이션 지원)
class _RotatingFileOutput extends LogOutput {
  final File file;
  IOSink? _sink;

  _RotatingFileOutput(this.file) {
    _sink = file.openWrite(mode: FileMode.append);
  }

  @override
  void output(OutputEvent event) {
    if (_sink == null) return;

    try {
      _sink!.writeAll(event.lines, '\n');
      _sink!.writeln();
      _sink!.flush();

      // 파일 크기 확인 (10MB마다)
      final fileSize = file.lengthSync();
      if (fileSize >= LoggerService._maxLogFileSizeBytes) {
        LoggerService.instance.rotateLogIfNeeded();
      }
    } catch (e) {
      print('⚠️ 로그 파일 쓰기 실패: $e');
    }
  }

  @override
  Future<void> destroy() async {
    await _sink?.close();
    _sink = null;
  }
}

