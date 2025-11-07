// lib/services/zoom_launcher_service.dart
// Zoom 자동 실행 서비스
//
// 목적: 스케줄된 녹화 시작 전 Zoom 회의 자동 실행
// - Zoom 링크로 기본 브라우저 열기
// - Zoom 앱 자동 실행 대기
// - 회의 참가 확인

import 'dart:io';
import 'package:logger/logger.dart';

/// Zoom 자동 실행 서비스
class ZoomLauncherService {
  final Logger _logger = Logger();

  /// Zoom 링크로 회의 시작
  ///
  /// @param zoomLink Zoom 회의 링크 (예: https://zoom.us/j/123456789)
  /// @param waitSeconds 실행 후 대기 시간 (초, 기본 10초)
  /// @return 성공 여부
  Future<bool> launchZoomMeeting({
    required String zoomLink,
    int waitSeconds = 10,
  }) async {
    try {
      _logger.i('🚀 Zoom 회의 실행 시작: $zoomLink');

      // 1. URL 유효성 검증
      final uri = Uri.tryParse(zoomLink);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        _logger.e('❌ 잘못된 Zoom 링크: $zoomLink');
        return false;
      }

      // 2. Zoom 링크인지 확인
      if (!uri.host.contains('zoom.us') && !uri.host.contains('zoom.com')) {
        _logger.w('⚠️ Zoom 링크가 아닙니다: $zoomLink');
        // 경고만 하고 계속 진행 (사용자 지정 Zoom 도메인 지원)
      }

      // 3. Windows에서 기본 브라우저로 열기
      // start 명령어는 URL을 기본 브라우저로 열고, Zoom 앱이 설치되어 있으면 자동으로 실행됨
      final result = await Process.run(
        'cmd',
        ['/c', 'start', '', zoomLink],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        _logger.e('❌ Zoom 링크 실행 실패 (exit code: ${result.exitCode})');
        _logger.e('  stdout: ${result.stdout}');
        _logger.e('  stderr: ${result.stderr}');
        return false;
      }

      _logger.i('✅ Zoom 링크 실행 완료');

      // 4. Zoom 앱이 실행될 때까지 대기
      _logger.i('⏳ Zoom 앱 실행 대기 중... ($waitSeconds초)');
      await Future.delayed(Duration(seconds: waitSeconds));

      // 5. Zoom 프로세스가 실행 중인지 확인
      final isZoomRunning = await _isZoomProcessRunning();
      if (isZoomRunning) {
        _logger.i('✅ Zoom 앱 실행 확인됨');
      } else {
        _logger.w('⚠️ Zoom 앱이 실행되지 않은 것 같습니다 (수동 확인 필요)');
        // 경고만 하고 계속 진행 (사용자가 수동으로 참가할 수 있음)
      }

      return true;
    } catch (e, stackTrace) {
      _logger.e('❌ Zoom 회의 실행 실패', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Zoom 프로세스가 실행 중인지 확인
  ///
  /// @return Zoom.exe가 실행 중이면 true
  Future<bool> _isZoomProcessRunning() async {
    try {
      // Windows tasklist 명령어로 Zoom 프로세스 확인
      final result = await Process.run(
        'tasklist',
        ['/FI', 'IMAGENAME eq Zoom.exe', '/NH'],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        _logger.w('⚠️ tasklist 명령 실패 (exit code: ${result.exitCode})');
        return false;
      }

      final output = result.stdout.toString();

      // "Zoom.exe"가 출력에 포함되어 있으면 실행 중
      final isRunning = output.toLowerCase().contains('zoom.exe');

      if (isRunning) {
        _logger.d('✅ Zoom 프로세스 확인됨');
      } else {
        _logger.d('⚠️ Zoom 프로세스 없음');
      }

      return isRunning;
    } catch (e) {
      _logger.e('❌ Zoom 프로세스 확인 실패', error: e);
      return false;
    }
  }

  /// Zoom 앱이 설치되어 있는지 확인
  ///
  /// @return Zoom이 설치되어 있으면 true
  Future<bool> isZoomInstalled() async {
    try {
      _logger.d('🔍 Zoom 설치 확인 중...');

      // Zoom 기본 설치 경로들
      final possiblePaths = [
        r'C:\Program Files\Zoom\bin\Zoom.exe',
        r'C:\Program Files (x86)\Zoom\bin\Zoom.exe',
        Platform.environment['APPDATA'] != null
            ? '${Platform.environment['APPDATA']}\\Zoom\\bin\\Zoom.exe'
            : null,
      ];

      for (final path in possiblePaths) {
        if (path == null) continue;

        final file = File(path);
        if (await file.exists()) {
          _logger.i('✅ Zoom 설치 확인됨: $path');
          return true;
        }
      }

      _logger.w('⚠️ Zoom 설치를 찾을 수 없습니다 (기본 경로에서)');
      return false;
    } catch (e) {
      _logger.e('❌ Zoom 설치 확인 실패', error: e);
      return false;
    }
  }

  /// Zoom 회의 종료
  ///
  /// 녹화가 끝난 후 Zoom 앱을 종료합니다.
  /// @param force 강제 종료 여부 (기본 false)
  Future<bool> closeZoomMeeting({bool force = false}) async {
    try {
      _logger.i('🚪 Zoom 회의 종료 시작...');

      // Zoom 프로세스 종료
      final result = await Process.run(
        'taskkill',
        ['/IM', 'Zoom.exe', if (force) '/F'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        _logger.i('✅ Zoom 앱 종료 완료');
        return true;
      } else if (result.exitCode == 128) {
        // 프로세스가 없는 경우
        _logger.d('ℹ️ Zoom 프로세스가 실행 중이지 않음');
        return true;
      } else {
        _logger.w('⚠️ Zoom 종료 실패 (exit code: ${result.exitCode})');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Zoom 종료 실패', error: e);
      return false;
    }
  }
}
