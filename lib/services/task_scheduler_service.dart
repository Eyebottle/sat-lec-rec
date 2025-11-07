// lib/services/task_scheduler_service.dart
// Windows Task Scheduler 연동 서비스
//
// 목적: Windows Task Scheduler를 사용한 자동 실행 및 절전 해제
// - 예약 시각에 절전 모드에서 깨우기
// - 시작 시 자동 실행 등록

import 'dart:io';
import 'package:logger/logger.dart';

/// Task Scheduler 연동 서비스
class TaskSchedulerService {
  final Logger _logger = Logger();

  /// 작업 이름
  static const String taskName = 'SatLecRec_AutoWake';

  /// 시작 시 자동 실행 등록
  ///
  /// Windows Task Scheduler에 로그온 시 실행되는 작업을 등록합니다.
  /// @param enable true면 등록, false면 삭제
  Future<bool> registerStartupTask({required bool enable}) async {
    try {
      if (enable) {
        _logger.i('🚀 시작 시 자동 실행 등록 시도...');

        // 현재 실행 파일 경로
        final exePath = Platform.resolvedExecutable;

        // schtasks를 사용하여 작업 등록
        // /SC ONLOGON: 로그온 시 실행
        // /RL HIGHEST: 최고 권한으로 실행
        final result = await Process.run(
          'schtasks',
          [
            '/Create',
            '/TN', taskName,
            '/TR', '"$exePath"',
            '/SC', 'ONLOGON',
            '/RL', 'HIGHEST',
            '/F',  // 기존 작업 덮어쓰기
          ],
          runInShell: true,
        );

        if (result.exitCode == 0) {
          _logger.i('✅ 시작 시 자동 실행 등록 완료');
          return true;
        } else {
          _logger.e('❌ 시작 시 자동 실행 등록 실패 (exit code: ${result.exitCode})');
          _logger.e('  stdout: ${result.stdout}');
          _logger.e('  stderr: ${result.stderr}');
          return false;
        }
      } else {
        _logger.i('🗑️ 시작 시 자동 실행 해제 시도...');

        // 작업 삭제
        final result = await Process.run(
          'schtasks',
          [
            '/Delete',
            '/TN', taskName,
            '/F',  // 확인 없이 삭제
          ],
          runInShell: true,
        );

        if (result.exitCode == 0) {
          _logger.i('✅ 시작 시 자동 실행 해제 완료');
          return true;
        } else if (result.stdout.toString().contains('ERROR: The system cannot find the file specified')) {
          // 작업이 없는 경우
          _logger.d('ℹ️ 등록된 작업 없음');
          return true;
        } else {
          _logger.e('❌ 시작 시 자동 실행 해제 실패 (exit code: ${result.exitCode})');
          _logger.e('  stdout: ${result.stdout}');
          _logger.e('  stderr: ${result.stderr}');
          return false;
        }
      }
    } catch (e, stackTrace) {
      _logger.e('❌ 시작 시 자동 실행 설정 실패', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 특정 시각에 절전 해제 작업 등록
  ///
  /// @param wakeTime 깨어날 시각
  /// @param taskName 작업 이름
  Future<bool> registerWakeupTask({
    required DateTime wakeTime,
    String? customTaskName,
  }) async {
    try {
      final taskNameToUse = customTaskName ?? '${taskName}_Wake';
      _logger.i('⏰ 절전 해제 작업 등록: ${wakeTime.toString()}');

      // 현재 실행 파일 경로
      final exePath = Platform.resolvedExecutable;

      // 시각 포맷: HH:MM
      final timeStr = '${wakeTime.hour.toString().padLeft(2, '0')}:${wakeTime.minute.toString().padLeft(2, '0')}';

      // schtasks를 사용하여 작업 등록
      // /SC ONCE: 1회만 실행
      // /ST: 시작 시각
      // /Z: 작업 완료 후 삭제
      final result = await Process.run(
        'powershell',
        [
          '-Command',
          '''
\$action = New-ScheduledTaskAction -Execute "$exePath"
\$trigger = New-ScheduledTaskTrigger -Once -At "$timeStr"
\$settings = New-ScheduledTaskSettingsSet -WakeToRun -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "$taskNameToUse" -Action \$action -Trigger \$trigger -Settings \$settings -Force
          '''
        ],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        _logger.i('✅ 절전 해제 작업 등록 완료');
        return true;
      } else {
        _logger.e('❌ 절전 해제 작업 등록 실패 (exit code: ${result.exitCode})');
        _logger.e('  stdout: ${result.stdout}');
        _logger.e('  stderr: ${result.stderr}');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('❌ 절전 해제 작업 등록 실패', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 등록된 작업 삭제
  ///
  /// @param taskName 삭제할 작업 이름
  Future<bool> deleteTask(String taskName) async {
    try {
      _logger.i('🗑️ 작업 삭제: $taskName');

      final result = await Process.run(
        'schtasks',
        [
          '/Delete',
          '/TN', taskName,
          '/F',
        ],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        _logger.i('✅ 작업 삭제 완료');
        return true;
      } else {
        _logger.w('⚠️ 작업 삭제 실패 또는 작업 없음 (exit code: ${result.exitCode})');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('❌ 작업 삭제 실패', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 작업이 등록되어 있는지 확인
  ///
  /// @param taskName 확인할 작업 이름
  Future<bool> isTaskRegistered(String taskName) async {
    try {
      final result = await Process.run(
        'schtasks',
        [
          '/Query',
          '/TN', taskName,
        ],
        runInShell: true,
      );

      // exit code 0이면 작업 존재
      return result.exitCode == 0;
    } catch (e) {
      _logger.e('❌ 작업 확인 실패', error: e);
      return false;
    }
  }
}
