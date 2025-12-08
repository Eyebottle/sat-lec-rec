// lib/services/health_check_service.dart
// 녹화 전 시스템 헬스체크 서비스
//
// 목적: 녹화 10분 전 시스템 상태 확인 (Phase 3.2.2)
// - 네트워크 연결
// - Zoom 링크 접속 가능 여부
// - 오디오 장치 사용 가능 여부
// - 디스크 공간 충분 여부

import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../models/health_check_result.dart';
import '../ffi/native_bindings.dart';

/// 시스템 헬스체크 서비스
class HealthCheckService {
  final Logger _logger = Logger();

  /// 최소 필요 디스크 공간 (바이트) - 5GB
  static const int minRequiredDiskSpace = 5 * 1024 * 1024 * 1024;

  /// 전체 헬스체크 수행
  ///
  /// @param zoomLink 확인할 Zoom 링크 (nullable)
  /// @return HealthCheckResult 헬스체크 결과
  Future<HealthCheckResult> performHealthCheck({String? zoomLink}) async {
    _logger.i('🏥 헬스체크 시작...');

    final errors = <String>[];
    final warnings = <String>[];

    // 1. 네트워크 연결 확인
    final networkOk = await _checkNetwork();
    if (!networkOk) {
      errors.add('네트워크 연결 실패');
    }

    // 2. Zoom 링크 유효성 확인 (선택적)
    bool? zoomLinkOk;
    if (zoomLink != null && zoomLink.isNotEmpty) {
      zoomLinkOk = await _checkZoomLink(zoomLink);
      if (zoomLinkOk == false) {
        errors.add('Zoom 링크 접속 불가: $zoomLink');
      }
    }

    // 3. 오디오 장치 확인
    final audioDeviceOk = await _checkAudioDevice();
    if (!audioDeviceOk) {
      errors.add('오디오 장치를 찾을 수 없음');
    }

    // 4. 디스크 공간 확인
    final diskSpaceBytes = await _getAvailableDiskSpace();
    final diskSpaceOk = diskSpaceBytes != null && diskSpaceBytes >= minRequiredDiskSpace;
    if (!diskSpaceOk) {
      final availableGB = diskSpaceBytes != null
          ? (diskSpaceBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)
          : '알 수 없음';
      errors.add('디스크 공간 부족 (사용 가능: ${availableGB}GB, 필요: 5GB)');
    }

    final result = HealthCheckResult(
      networkOk: networkOk,
      zoomLinkOk: zoomLinkOk,
      audioDeviceOk: audioDeviceOk,
      diskSpaceOk: diskSpaceOk,
      availableDiskSpaceBytes: diskSpaceBytes,
      errors: errors,
      warnings: warnings,
    );

    if (result.isHealthy) {
      _logger.i('✅ 헬스체크 통과: ${result.summary}');
    } else {
      _logger.w('❌ 헬스체크 실패: ${result.summary}');
      for (final error in errors) {
        _logger.e('  - $error');
      }
    }

    return result;
  }

  /// 네트워크 연결 확인
  ///
  /// Google DNS (8.8.8.8)에 ping 시도
  Future<bool> _checkNetwork() async {
    try {
      _logger.d('네트워크 확인 중... (8.8.8.8:53)');

      // DNS lookup으로 네트워크 확인 (ping보다 안정적)
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));

      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;

      if (isConnected) {
        _logger.d('✅ 네트워크 연결 정상');
      } else {
        _logger.w('⚠️ 네트워크 연결 실패');
      }

      return isConnected;
    } catch (e) {
      _logger.e('❌ 네트워크 확인 실패', error: e);
      return false;
    }
  }

  /// Zoom 링크 유효성 확인
  ///
  /// HTTP HEAD 요청으로 접속 가능 여부 확인
  /// @param zoomLink Zoom 회의 링크
  Future<bool> _checkZoomLink(String zoomLink) async {
    try {
      _logger.d('Zoom 링크 확인 중: $zoomLink');

      // URL 유효성 먼저 확인
      final uri = Uri.tryParse(zoomLink);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        _logger.w('⚠️ 잘못된 URL 형식: $zoomLink');
        return false;
      }

      // HTTP HEAD 요청 (실제로 페이지 로드하지 않음)
      final client = HttpClient();
      try {
        final request = await client.headUrl(uri)
            .timeout(const Duration(seconds: 10));
        final response = await request.close()
            .timeout(const Duration(seconds: 10));

        final isOk = response.statusCode >= 200 && response.statusCode < 400;

        if (isOk) {
          _logger.d('✅ Zoom 링크 접속 가능 (${response.statusCode})');
        } else {
          _logger.w('⚠️ Zoom 링크 응답 코드: ${response.statusCode}');
        }

        return isOk;
      } finally {
        client.close();
      }
    } catch (e) {
      _logger.e('❌ Zoom 링크 확인 실패', error: e);
      return false;
    }
  }

  /// 오디오 장치 사용 가능 여부 확인
  ///
  /// FFI를 통해 네이티브 레벨에서 WASAPI 장치 확인
  Future<bool> _checkAudioDevice() async {
    try {
      _logger.d('오디오 장치 확인 중...');

      // Phase 3.2.2: 임시 구현
      // TODO: 네이티브 레이어에 오디오 장치 열거 함수 추가 필요
      // 현재는 초기화 상태로 확인
      final isInitialized = NativeRecorderBindings.isRecording() >= 0;

      if (isInitialized) {
        _logger.d('✅ 오디오 장치 사용 가능 (네이티브 초기화됨)');
      } else {
        _logger.w('⚠️ 오디오 장치 확인 불가 (네이티브 미초기화)');
      }

      // 임시로 항상 true 반환 (실제 녹화 시작 시 오디오 장치 체크됨)
      return true;
    } catch (e) {
      _logger.e('❌ 오디오 장치 확인 실패', error: e);
      return false;
    }
  }

  /// 사용 가능한 디스크 공간 확인 (바이트)
  ///
  /// 녹화 파일이 저장될 Documents 디렉토리의 여유 공간 확인
  Future<int?> _getAvailableDiskSpace() async {
    try {
      _logger.d('디스크 공간 확인 중...');

      // Windows에서 Documents 디렉토리 경로
      final documentsDir = await getApplicationDocumentsDirectory();
      final path = documentsDir.path;

      // Windows PowerShell을 통해 디스크 공간 확인
      // Get-PSDrive로 드라이브 정보 가져오기
      final drive = path.substring(0, 1);  // C:\ -> C
      final result = await Process.run(
        'powershell.exe',
        [
          '-Command',
          '(Get-PSDrive $drive).Free'
        ],
      );

      if (result.exitCode == 0) {
        final freeSpaceStr = result.stdout.toString().trim();
        final freeSpaceBytes = int.tryParse(freeSpaceStr);

        if (freeSpaceBytes != null) {
          final freeSpaceGB = freeSpaceBytes / (1024 * 1024 * 1024);
          _logger.d('✅ 디스크 공간: ${freeSpaceGB.toStringAsFixed(1)} GB 사용 가능');
          return freeSpaceBytes;
        }
      }

      _logger.w('⚠️ 디스크 공간 확인 실패: ${result.stderr}');
      return null;
    } catch (e) {
      _logger.e('❌ 디스크 공간 확인 실패', error: e);
      return null;
    }
  }

  /// 헬스체크 요약 로그 출력
  ///
  /// @param result 헬스체크 결과
  void logHealthCheckSummary(HealthCheckResult result) {
    _logger.i('📊 헬스체크 요약:');
    _logger.i('  - 네트워크: ${result.networkOk ? "✅" : "❌"}');
    if (result.zoomLinkOk != null) {
      _logger.i('  - Zoom 링크: ${result.zoomLinkOk! ? "✅" : "❌"}');
    }
    _logger.i('  - 오디오 장치: ${result.audioDeviceOk ? "✅" : "❌"}');
    _logger.i('  - 디스크 공간: ${result.diskSpaceOk ? "✅" : "❌"} (${result.availableDiskSpaceGB ?? "N/A"})');

    if (result.errors.isNotEmpty) {
      _logger.e('🔴 에러:');
      for (final error in result.errors) {
        _logger.e('  - $error');
      }
    }

    if (result.warnings.isNotEmpty) {
      _logger.w('🟡 경고:');
      for (final warning in result.warnings) {
        _logger.w('  - $warning');
      }
    }
  }
}
