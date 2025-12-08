// lib/services/log_diagnostics_service.dart
// 실행 로그를 분석해 자동 복구에 필요한 단서를 제공하는 서비스
//
// 목적:
// - LoggerService가 기록한 최신 로그를 읽고 대표적인 오류 패턴을 감지
// - Zoom 자동화 실패 원인을 코드가 스스로 파악할 수 있게 지원
// - 감지된 문제 유형을 기반으로 ZoomLauncherService가 자가 복구를 시도하도록 돕는다
import 'package:logger/logger.dart';

import 'logger_service.dart';

/// 로그에서 감지할 문제 유형
/// - [zoomProcessMissing]: Zoom 프로세스가 예상대로 뜨지 않은 상황
/// - [autoJoinTimeout]: 참가 버튼을 끝까지 찾지 못해 자동화가 중단된 상황
/// - [winToastThreadViolation]: WinToast 플러그인이 잘못된 스레드에서 호출된 상황
enum LogIssueType {
  zoomProcessMissing,
  autoJoinTimeout,
  winToastThreadViolation,
}

/// 로그에서 발견된 문제 한 건을 표현
class DetectedLogIssue {
  /// [type]: 문제 유형, [evidence]: 증거가 된 로그 문자열
  const DetectedLogIssue({
    required this.type,
    required this.evidence,
  });

  final LogIssueType type;
  final String evidence;

  /// 사람이 읽기 쉬운 문제 설명
  String describe() {
    switch (type) {
      case LogIssueType.zoomProcessMissing:
        return 'Zoom 프로세스가 예상대로 실행되지 않았습니다.';
      case LogIssueType.autoJoinTimeout:
        return '참가 버튼을 찾지 못해 자동 입장이 중단되었습니다.';
      case LogIssueType.winToastThreadViolation:
        return 'WinToast 알림이 잘못된 스레드에서 호출되었습니다.';
    }
  }
}

/// 로그 분석 전담 서비스
class LogDiagnosticsService {
  LogDiagnosticsService();

  final Logger _logger = LoggerService.instance.logger;

  /// 최신 로그를 읽어 대표적인 오류 패턴을 찾아낸다.
  /// 입력: [maxLines]는 분석에 사용할 최대 줄 수.
  /// 출력: 발견된 [DetectedLogIssue] 리스트.
  /// 예외: 파일 접근 실패 시 빈 리스트를 돌려준다.
  Future<List<DetectedLogIssue>> analyzeRecentIssues({
    int maxLines = 400,
  }) async {
    final lines =
        await LoggerService.instance.readRecentLogLines(maxLines: maxLines);
    if (lines.isEmpty) {
      _logger.d('🔍 로그가 비어 있어 진단을 생략합니다.');
      return [];
    }

    final issues = <DetectedLogIssue>[];

    if (_containsPattern(
      lines,
      keywords: ['Zoom 앱이 실행되지 않은 것 같습니다'],
    )) {
      issues.add(
        const DetectedLogIssue(
          type: LogIssueType.zoomProcessMissing,
          evidence: 'Zoom 앱이 실행되지 않은 것 같습니다',
        ),
      );
    }

    final joinButtonFailures = lines
        .where((line) => line.contains('참가 버튼을 찾지 못함'))
        .length;
    final timeoutRaised = _containsPattern(
      lines,
      keywords: ['Zoom 자동 진입 타임아웃'],
    );
    if (timeoutRaised || joinButtonFailures >= 5) {
      issues.add(
        const DetectedLogIssue(
          type: LogIssueType.autoJoinTimeout,
          evidence: '참가 버튼 탐색 실패 또는 자동 진입 타임아웃',
        ),
      );
    }

    if (_containsPattern(
      lines,
      keywords: ['win_toast', 'non-platform thread'],
    )) {
      issues.add(
        const DetectedLogIssue(
          type: LogIssueType.winToastThreadViolation,
          evidence: 'WinToast가 잘못된 스레드에서 호출됨',
        ),
      );
    }

    if (issues.isEmpty) {
      _logger.d('🔍 최근 로그에서 즉시 대응이 필요한 패턴을 찾지 못했습니다.');
    } else {
      _logger.w(
        '🩺 로그 진단 결과: ${issues.map((i) => i.describe()).join(' / ')}',
      );
    }
    return issues;
  }

  bool _containsPattern(
    List<String> lines, {
    required List<String> keywords,
  }) {
    return lines.any((line) {
      for (final keyword in keywords) {
        if (!line.contains(keyword)) {
          return false;
        }
      }
      return true;
    });
  }
}


