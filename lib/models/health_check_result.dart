// lib/models/health_check_result.dart
// 헬스체크 결과 데이터 모델
//
// 목적: 녹화 시작 전 시스템 상태 확인 결과 저장 (Phase 3.2.2)

/// 헬스체크 결과를 담는 데이터 클래스
class HealthCheckResult {
  /// 전체 헬스체크 성공 여부
  bool get isHealthy =>
      networkOk &&
      diskSpaceOk &&
      audioDeviceOk &&
      (zoomLinkOk ?? true);  // Zoom 링크는 선택적

  /// 네트워크 연결 상태
  final bool networkOk;

  /// Zoom 링크 유효성 (nullable - Zoom 사용하지 않을 수도 있음)
  final bool? zoomLinkOk;

  /// 오디오 장치 사용 가능 여부
  final bool audioDeviceOk;

  /// 디스크 공간 충분 여부
  final bool diskSpaceOk;

  /// 사용 가능한 디스크 공간 (바이트)
  final int? availableDiskSpaceBytes;

  /// 에러 메시지 목록
  final List<String> errors;

  /// 경고 메시지 목록
  final List<String> warnings;

  /// 헬스체크 수행 시각
  final DateTime checkedAt;

  HealthCheckResult({
    required this.networkOk,
    this.zoomLinkOk,
    required this.audioDeviceOk,
    required this.diskSpaceOk,
    this.availableDiskSpaceBytes,
    List<String>? errors,
    List<String>? warnings,
    DateTime? checkedAt,
  })  : errors = errors ?? [],
        warnings = warnings ?? [],
        checkedAt = checkedAt ?? DateTime.now();

  /// 사람이 읽을 수 있는 요약 문자열
  String get summary {
    if (isHealthy) {
      return '✅ 모든 시스템 정상';
    }

    final issues = <String>[];
    if (!networkOk) issues.add('네트워크 연결 실패');
    if (zoomLinkOk == false) issues.add('Zoom 링크 접속 불가');
    if (!audioDeviceOk) issues.add('오디오 장치 없음');
    if (!diskSpaceOk) issues.add('디스크 공간 부족');

    return '❌ 문제 발견: ${issues.join(', ')}';
  }

  /// 디스크 공간을 읽기 쉬운 형식으로 변환 (GB)
  String? get availableDiskSpaceGB {
    if (availableDiskSpaceBytes == null) return null;
    final gb = availableDiskSpaceBytes! / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }

  /// copyWith 메서드
  HealthCheckResult copyWith({
    bool? networkOk,
    bool? zoomLinkOk,
    bool? audioDeviceOk,
    bool? diskSpaceOk,
    int? availableDiskSpaceBytes,
    List<String>? errors,
    List<String>? warnings,
    DateTime? checkedAt,
  }) {
    return HealthCheckResult(
      networkOk: networkOk ?? this.networkOk,
      zoomLinkOk: zoomLinkOk ?? this.zoomLinkOk,
      audioDeviceOk: audioDeviceOk ?? this.audioDeviceOk,
      diskSpaceOk: diskSpaceOk ?? this.diskSpaceOk,
      availableDiskSpaceBytes: availableDiskSpaceBytes ?? this.availableDiskSpaceBytes,
      errors: errors ?? this.errors,
      warnings: warnings ?? this.warnings,
      checkedAt: checkedAt ?? this.checkedAt,
    );
  }

  @override
  String toString() {
    return 'HealthCheckResult(isHealthy: $isHealthy, network: $networkOk, '
        'zoom: $zoomLinkOk, audio: $audioDeviceOk, disk: $diskSpaceOk, '
        'diskSpace: $availableDiskSpaceGB, errors: ${errors.length}, warnings: ${warnings.length})';
  }
}
