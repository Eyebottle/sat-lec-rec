// lib/services/schedule_service.dart
// 녹화 스케줄 관리 서비스
//
// 목적: Cron 기반 예약 녹화 관리 (Phase 3.2.1)
// - 스케줄 CRUD
// - Cron 작업 등록/해제
// - SharedPreferences 기반 영속화
// - RecorderService 연동

import 'dart:async';
import 'dart:convert';
import 'package:cron/cron.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recording_schedule.dart';
import 'recorder_service.dart';
import 'health_check_service.dart';  // Phase 3.2.2

/// 스케줄 관리 서비스 (싱글톤)
class ScheduleService {
  static final ScheduleService _instance = ScheduleService._internal();
  factory ScheduleService() => _instance;
  ScheduleService._internal();

  final Logger _logger = Logger();
  final Cron _cron = Cron();

  /// 스케줄 목록 (메모리 캐시)
  final List<RecordingSchedule> _schedules = [];

  /// Cron 작업 맵 (스케줄 ID → ScheduledTask)
  final Map<String, ScheduledTask> _cronTasks = {};

  /// T-10 헬스체크 타이머 맵 (스케줄 ID → Timer) - Phase 3.2.2
  final Map<String, Timer> _healthCheckTimers = {};

  /// RecorderService 참조
  final RecorderService _recorderService = RecorderService();

  /// HealthCheckService 참조 - Phase 3.2.2
  final HealthCheckService _healthCheckService = HealthCheckService();

  /// SharedPreferences 키
  static const String _schedulesPrefKey = 'recording_schedules';

  /// 서비스 초기화
  /// 저장된 스케줄을 불러오고 Cron 작업을 등록
  Future<void> initialize() async {
    _logger.i('📅 ScheduleService 초기화 중...');

    try {
      await _loadSchedules();
      _registerAllCronJobs();
      _logger.i('✅ ScheduleService 초기화 완료 (${_schedules.length}개 스케줄)');
    } catch (e, stackTrace) {
      _logger.e('❌ ScheduleService 초기화 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 서비스 종료
  /// 모든 Cron 작업을 중지하고 리소스 정리
  Future<void> dispose() async {
    _logger.i('📅 ScheduleService 종료 중...');

    try {
      // Cron 작업 종료
      await _cron.close();
      _cronTasks.clear();

      // Phase 3.2.2: 헬스체크 타이머 모두 취소
      for (final timer in _healthCheckTimers.values) {
        timer.cancel();
      }
      _healthCheckTimers.clear();

      _logger.i('✅ ScheduleService 종료 완료');
    } catch (e) {
      _logger.e('❌ ScheduleService 종료 실패', error: e);
    }
  }

  /// 스케줄 목록 가져오기 (읽기 전용)
  List<RecordingSchedule> get schedules => List.unmodifiable(_schedules);

  /// 활성화된 스케줄 목록
  List<RecordingSchedule> get enabledSchedules =>
      _schedules.where((s) => s.isEnabled).toList();

  /// 스케줄 추가
  /// @param schedule 추가할 스케줄
  Future<void> addSchedule(RecordingSchedule schedule) async {
    _logger.i('➕ 스케줄 추가: ${schedule.name}');

    try {
      // 중복 ID 체크
      if (_schedules.any((s) => s.id == schedule.id)) {
        throw ArgumentError('이미 존재하는 스케줄 ID: ${schedule.id}');
      }

      _schedules.add(schedule);
      await _saveSchedules();

      // 활성화된 스케줄이면 Cron 작업 등록
      if (schedule.isEnabled) {
        _registerCronJob(schedule);
      }

      _logger.i('✅ 스케줄 추가 완료: ${schedule.name}');
    } catch (e, stackTrace) {
      _logger.e('❌ 스케줄 추가 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 스케줄 업데이트
  /// @param schedule 업데이트할 스케줄 (ID는 동일해야 함)
  Future<void> updateSchedule(RecordingSchedule schedule) async {
    _logger.i('✏️ 스케줄 업데이트: ${schedule.name}');

    try {
      final index = _schedules.indexWhere((s) => s.id == schedule.id);
      if (index == -1) {
        throw ArgumentError('스케줄을 찾을 수 없음: ${schedule.id}');
      }

      // 기존 Cron 작업 제거
      _unregisterCronJob(schedule.id);

      // 스케줄 업데이트
      _schedules[index] = schedule;
      await _saveSchedules();

      // 활성화된 스케줄이면 Cron 작업 재등록
      if (schedule.isEnabled) {
        _registerCronJob(schedule);
      }

      _logger.i('✅ 스케줄 업데이트 완료: ${schedule.name}');
    } catch (e, stackTrace) {
      _logger.e('❌ 스케줄 업데이트 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 스케줄 삭제
  /// @param scheduleId 삭제할 스케줄 ID
  Future<void> deleteSchedule(String scheduleId) async {
    _logger.i('🗑️ 스케줄 삭제: $scheduleId');

    try {
      final index = _schedules.indexWhere((s) => s.id == scheduleId);
      if (index == -1) {
        _logger.w('⚠️ 스케줄을 찾을 수 없음: $scheduleId');
        return;
      }

      final schedule = _schedules[index];

      // Cron 작업 제거
      _unregisterCronJob(scheduleId);

      // 스케줄 삭제
      _schedules.removeAt(index);
      await _saveSchedules();

      _logger.i('✅ 스케줄 삭제 완료: ${schedule.name}');
    } catch (e, stackTrace) {
      _logger.e('❌ 스케줄 삭제 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 스케줄 활성화/비활성화 토글
  /// @param scheduleId 토글할 스케줄 ID
  Future<void> toggleSchedule(String scheduleId) async {
    _logger.i('🔄 스케줄 토글: $scheduleId');

    try {
      final index = _schedules.indexWhere((s) => s.id == scheduleId);
      if (index == -1) {
        throw ArgumentError('스케줄을 찾을 수 없음: $scheduleId');
      }

      final schedule = _schedules[index];
      final updatedSchedule = schedule.copyWith(isEnabled: !schedule.isEnabled);

      await updateSchedule(updatedSchedule);
      _logger.i('✅ 스케줄 토글 완료: ${updatedSchedule.name} (${updatedSchedule.isEnabled ? "활성화" : "비활성화"})');
    } catch (e, stackTrace) {
      _logger.e('❌ 스케줄 토글 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Cron 작업 등록
  /// @param schedule 등록할 스케줄
  void _registerCronJob(RecordingSchedule schedule) {
    try {
      // 이미 등록된 작업이 있으면 제거
      _unregisterCronJob(schedule.id);

      // Cron 작업 생성 및 등록
      final task = _cron.schedule(
        Schedule.parse(schedule.cronExpression),
        () => _executeScheduledRecording(schedule),
      );

      _cronTasks[schedule.id] = task;

      // Phase 3.2.2: T-10분 헬스체크 타이머 등록
      _scheduleHealthCheck(schedule);

      final nextExecution = schedule.getNextExecutionTime();
      _logger.i('⏰ Cron 작업 등록: ${schedule.name} (${schedule.cronExpression}) - 다음 실행: $nextExecution');
    } catch (e, stackTrace) {
      _logger.e('❌ Cron 작업 등록 실패: ${schedule.name}', error: e, stackTrace: stackTrace);
    }
  }

  /// Cron 작업 해제
  /// @param scheduleId 해제할 스케줄 ID
  void _unregisterCronJob(String scheduleId) {
    final task = _cronTasks.remove(scheduleId);
    if (task != null) {
      // cron 패키지는 개별 작업 취소를 지원하지 않으므로
      // 맵에서만 제거 (dispose 시 _cron.close()로 모두 정리)
      _logger.d('🔕 Cron 작업 해제: $scheduleId');
    }

    // Phase 3.2.2: 헬스체크 타이머도 취소
    final timer = _healthCheckTimers.remove(scheduleId);
    if (timer != null) {
      timer.cancel();
      _logger.d('🔕 헬스체크 타이머 취소: $scheduleId');
    }
  }

  /// 모든 활성 스케줄의 Cron 작업 등록
  void _registerAllCronJobs() {
    for (final schedule in enabledSchedules) {
      _registerCronJob(schedule);
    }
  }

  /// 예약된 녹화 실행
  /// Cron에 의해 호출되는 콜백 함수
  /// @param schedule 실행할 스케줄
  Future<void> _executeScheduledRecording(RecordingSchedule schedule) async {
    _logger.i('🎬 예약 녹화 시작: ${schedule.name}');

    try {
      // RecorderService를 통해 녹화 시작
      final outputPath = await _recorderService.startRecordingWithZoomLink(
        zoomLink: schedule.zoomLink,
        durationMinutes: schedule.durationMinutes,
      );

      // 마지막 실행 시각 업데이트
      final updatedSchedule = schedule.copyWith(
        lastExecutedAt: DateTime.now(),
      );
      await updateSchedule(updatedSchedule);

      _logger.i('✅ 예약 녹화 시작 완료: $outputPath');
    } catch (e, stackTrace) {
      _logger.e('❌ 예약 녹화 시작 실패: ${schedule.name}', error: e, stackTrace: stackTrace);

      // TODO: Phase 3.2.2에서 사용자 알림 추가
      // - 시스템 트레이 알림
      // - 로그 기록
    }
  }

  /// T-10 헬스체크 스케줄링 (Phase 3.2.2)
  ///
  /// 다음 실행 10분 전에 시스템 상태 확인 타이머를 등록합니다.
  /// @param schedule 헬스체크를 예약할 스케줄
  void _scheduleHealthCheck(RecordingSchedule schedule) {
    try {
      // 기존 타이머 제거
      _healthCheckTimers[schedule.id]?.cancel();

      final nextExecution = schedule.getNextExecutionTime();
      final now = DateTime.now();
      final timeUntilExecution = nextExecution.difference(now);

      // T-10분 시각 계산
      final healthCheckTime = timeUntilExecution - const Duration(minutes: 10);

      if (healthCheckTime.isNegative || healthCheckTime.inMinutes < 1) {
        _logger.w('⚠️ 헬스체크 시간 부족 (${healthCheckTime.inMinutes}분): ${schedule.name}');
        return;
      }

      // T-10분 타이머 생성
      final timer = Timer(healthCheckTime, () async {
        await _performScheduledHealthCheck(schedule);
      });

      _healthCheckTimers[schedule.id] = timer;
      _logger.i('🏥 헬스체크 예약: ${schedule.name} - ${healthCheckTime.inMinutes}분 후 실행');
    } catch (e, stackTrace) {
      _logger.e('❌ 헬스체크 예약 실패: ${schedule.name}', error: e, stackTrace: stackTrace);
    }
  }

  /// 예약된 헬스체크 실행
  ///
  /// T-10분에 시스템 상태를 확인하고 결과를 로깅합니다.
  /// @param schedule 헬스체크를 수행할 스케줄
  Future<void> _performScheduledHealthCheck(RecordingSchedule schedule) async {
    _logger.i('🏥 T-10 헬스체크 실행: ${schedule.name}');

    try {
      final result = await _healthCheckService.performHealthCheck(
        zoomLink: schedule.zoomLink,
      );

      _healthCheckService.logHealthCheckSummary(result);

      if (!result.isHealthy) {
        _logger.w('⚠️ 헬스체크 실패 - 녹화 시작 전 문제 해결 필요');
        _logger.w('  문제: ${result.errors.join(', ')}');

        // TODO: Phase 3.2.3에서 시스템 트레이 알림 추가
        // - 사용자에게 헬스체크 실패 알림
        // - 문제 해결 가이드 표시
      } else {
        _logger.i('✅ 헬스체크 통과 - 녹화 준비 완료');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ 헬스체크 수행 실패: ${schedule.name}', error: e, stackTrace: stackTrace);
    }
  }

  /// SharedPreferences에서 스케줄 불러오기
  Future<void> _loadSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final schedulesJson = prefs.getString(_schedulesPrefKey);

      if (schedulesJson == null || schedulesJson.isEmpty) {
        _logger.i('📭 저장된 스케줄 없음');
        return;
      }

      final List<dynamic> schedulesList = jsonDecode(schedulesJson);
      _schedules.clear();

      for (final scheduleJson in schedulesList) {
        try {
          final schedule = RecordingSchedule.fromJson(scheduleJson);
          _schedules.add(schedule);
        } catch (e) {
          _logger.w('⚠️ 스케줄 파싱 실패 (건너뜀)', error: e);
        }
      }

      _logger.i('📥 스케줄 불러오기 완료: ${_schedules.length}개');
    } catch (e, stackTrace) {
      _logger.e('❌ 스케줄 불러오기 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// SharedPreferences에 스케줄 저장
  Future<void> _saveSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final schedulesList = _schedules.map((s) => s.toJson()).toList();
      final schedulesJson = jsonEncode(schedulesList);

      await prefs.setString(_schedulesPrefKey, schedulesJson);
      _logger.d('💾 스케줄 저장 완료: ${_schedules.length}개');
    } catch (e, stackTrace) {
      _logger.e('❌ 스케줄 저장 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 다음 예약 녹화 정보 가져오기
  /// @return (스케줄, 실행 예정 시각) 튜플, 예약이 없으면 null
  ({RecordingSchedule schedule, DateTime nextExecution})? getNextSchedule() {
    if (enabledSchedules.isEmpty) return null;

    // 모든 활성 스케줄의 다음 실행 시각 계산
    final schedulesWithNext = enabledSchedules.map((schedule) {
      return (
        schedule: schedule,
        nextExecution: schedule.getNextExecutionTime(),
      );
    }).toList();

    // 가장 빠른 실행 시각 찾기
    schedulesWithNext.sort((a, b) => a.nextExecution.compareTo(b.nextExecution));

    return schedulesWithNext.first;
  }
}

// RecorderService 확장 (임시 구현 - 실제로는 RecorderService 수정 필요)
extension _RecorderServiceScheduleExtension on RecorderService {
  /// Zoom 링크 기반 녹화 시작 (Phase 3.2.1 임시 구현)
  ///
  /// TODO: RecorderService에 실제 구현 필요
  /// - Zoom 창 열기
  /// - 화면 녹화 시작
  /// - 지정 시간 후 자동 정지
  Future<String> startRecordingWithZoomLink({
    required String zoomLink,
    required int durationMinutes,
  }) async {
    final logger = Logger();
    logger.w('⚠️ startRecordingWithZoomLink() 임시 구현 - 실제 Zoom 연동 필요');

    // 임시: 일반 녹화 시작 (RecorderService의 실제 시그니처에 맞춤)
    final filePath = await startRecording(
      durationSeconds: durationMinutes * 60,
    );

    return filePath ?? 'recording_failed.mp4';
  }
}
