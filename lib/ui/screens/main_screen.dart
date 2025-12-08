import 'package:flutter/material.dart';
import 'dart:io'; // 폴더 열기 및 프로세스 실행용
import 'dart:async'; // Timer용
import 'package:window_manager/window_manager.dart';
// uuid 패키지는 더 이상 이 파일에서 직접 사용하지 않을 수 있음 (스케줄 생성을 제거하므로)
import '../../services/recorder_service.dart';
import '../../services/schedule_service.dart';
import '../../services/tray_service.dart';
import '../../services/settings_service.dart';
import '../../services/zoom_launcher_service.dart';
import '../../services/logger_service.dart';
import '../../models/recording_schedule.dart';
import '../widgets/recording_progress_widget.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/countdown_timer.dart';
import '../style/app_colors.dart';
import '../style/app_typography.dart';
import '../style/app_spacing.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';

final logger = LoggerService.instance.logger;

/// 메인 화면 (대시보드)
///
/// 현재 녹화 상태, 다음 예약 정보, 녹화 제어 기능을 제공합니다.
/// 스케줄 입력 기능은 ScheduleScreen으로 이관되었습니다.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WindowListener {
  final RecorderService _recorderService = RecorderService();
  final ScheduleService _scheduleService = ScheduleService();
  final TrayService _trayService = TrayService();
  final SettingsService _settingsService = SettingsService();
  final ZoomLauncherService _zoomLauncherService = ZoomLauncherService();

  Timer? _statusCheckTimer; // 상태 체크 타이머

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeServices();
    });

    // 1초마다 상태 체크하여 UI 갱신 (자동 녹화 감지 및 타이머 갱신)
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _statusCheckTimer?.cancel();
    // 서비스들은 싱글톤이거나 앱 수명주기와 함께하므로 여기서 dispose 하지 않을 수 있음
    // 하지만 기존 코드 유지
    _recorderService.dispose();
    _scheduleService.dispose();
    _trayService.dispose();
    _settingsService.dispose();
    LoggerService.instance.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      logger.i('SettingsService 초기화 시작...');
      await _settingsService.initialize();
      logger.i('✅ SettingsService 초기화 완료');

      logger.i('RecorderService 초기화 시작...');
      await _recorderService.initialize();
      logger.i('✅ RecorderService 초기화 완료');

      logger.i('ScheduleService 초기화 시작...');
      await _scheduleService.initialize();
      logger.i('✅ ScheduleService 초기화 완료');

      try {
        logger.i('TrayService 초기화 시작...');
        await _trayService.initialize();
        logger.i('✅ TrayService 초기화 완료');
      } catch (e) {
        logger.w('⚠️ TrayService 초기화 실패 (앱은 계속 실행됨)', error: e);
      }
    } catch (e, stackTrace) {
      logger.e('❌ 서비스 초기화 실패', error: e, stackTrace: stackTrace);
    }
  }

  @override
  void onWindowClose() async {
    logger.i('창 닫기 요청');

    if (_recorderService.isRecording) {
      logger.w('⚠️ 녹화 중 - 창 닫기 취소');
      if (context.mounted) {
        final shouldClose = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('녹화 중'),
            content: const Text('현재 녹화가 진행 중입니다.\n정말 종료하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              AppButton.error(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('종료'),
              ),
            ],
          ),
        );

        if (shouldClose != true) {
          return;
        }

        try {
          await _recorderService.stopRecording();
          logger.i('녹화 중지 후 앱 종료');
        } catch (e) {
          logger.e('녹화 중지 실패', error: e);
        }
      }
    }

    if (_trayService.isInitialized) {
      logger.i('트레이로 최소화');
      await _trayService.hideWindow();
    } else {
      logger.w('트레이 미초기화 - 앱 종료');
      windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SatLecRec Dashboard',
              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '토요일 강의 자동 녹화 시스템',
              style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: '스케줄 관리',
            onPressed: () {
              logger.d('스케줄 관리 버튼 클릭');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScheduleScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: '설정',
            onPressed: () {
              logger.d('설정 버튼 클릭');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 녹화 중일 때: 녹화 상태 카드 (최상단 강조)
            if (_recorderService.isRecording) ...[
              _buildRecordingActiveCard(),
              const SizedBox(height: AppSpacing.xl),
              // 녹화 진행률 (선택적 표시)
              const RecordingProgressWidget(),
              const SizedBox(height: AppSpacing.xl),
            ] else ...[
              // 2. 대기 중일 때: 다음 예약 정보 (Hero Card)
              _buildNextScheduleHeroCard(),
              const SizedBox(height: AppSpacing.xl),
            ],

            // 3. 빠른 작업 및 상태 요약
            Row(
              children: [
                Expanded(child: _buildStatusSummaryCard()),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _buildUtilityCard()),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // 버전 정보
            Center(
              child: Text(
                'v1.0.0 (M0)',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 다음 예약 히어로 카드 (컴팩트 버전)
  Widget _buildNextScheduleHeroCard() {
    final schedules = _scheduleService.enabledSchedules;

    // 예약이 없을 때
    if (schedules.isEmpty) {
      return AppCard(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.event_busy_rounded, size: 32, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                '예정된 녹화가 없습니다',
                style: AppTypography.titleSmall.copyWith(color: AppColors.textSecondary),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScheduleScreen()),
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('추가'),
            )
          ],
        ),
      );
    }

    // 다음 예약 찾기
    RecordingSchedule? nextSchedule;
    DateTime? nextTime;

    for (final schedule in schedules) {
      final execTime = schedule.getNextExecutionTime();
      if (nextTime == null || execTime.isBefore(nextTime)) {
        nextTime = execTime;
        nextSchedule = schedule;
      }
    }

    if (nextSchedule == null || nextTime == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 라벨 + 예약명
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'NEXT',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nextSchedule.name,
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScheduleScreen()),
                  );
                },
                icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 20),
                tooltip: '예약 수정',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 중단: 일정 정보
          Text(
            '${nextSchedule.scheduleDisplayName} · ${nextSchedule.startTimeFormatted}',
            style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          // 하단: 카운트다운
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text('시작까지', style: AppTypography.bodySmall.copyWith(color: Colors.white70)),
                const SizedBox(width: 12),
                CountdownTimer(
                  targetTime: nextTime,
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Monospace',
                  ),
                  onComplete: () => setState(() {}),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 녹화 중 상태 카드 (컴팩트 버전)
  Widget _buildRecordingActiveCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // 녹화 아이콘 (깜빡임 효과)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error.withValues(alpha: 0.1 * value),
                ),
                child: Icon(
                  Icons.fiber_manual_record_rounded,
                  color: AppColors.error.withValues(alpha: value),
                  size: 28,
                ),
              );
            },
            onEnd: () => setState(() {}),
          ),
          const SizedBox(width: 16),
          // 텍스트
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '녹화 진행 중',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                Text(
                  '화면 및 오디오 캡처 중',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // 중단 버튼
          ElevatedButton.icon(
            onPressed: _stopRecordingSafely,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.stop_rounded, size: 20),
            label: const Text('중단', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// 상태 요약 카드
  Widget _buildStatusSummaryCard() {
    final activeCount = _scheduleService.enabledSchedules.length;
    
    return AppCard.level1(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.playlist_add_check_circle_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text('예약 상태', style: AppTypography.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$activeCount개의 예약 대기 중',
            style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '자동 녹화 시스템이 활성화되어 있습니다.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// 유틸리티 카드 (폴더 열기)
  Widget _buildUtilityCard() {
    return AppCard.level1(
      padding: const EdgeInsets.all(20),
      onTap: _openRecordingFolder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_special_rounded, color: AppColors.secondary, size: 24),
              const SizedBox(width: 8),
              Text('녹화 저장소', style: AppTypography.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '폴더 열기',
                style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '저장된 녹화 파일을 확인합니다.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // --- Actions ---

  Future<void> _openRecordingFolder() async {
    try {
      const path = r'C:\SatLecRec\recordings';
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await Process.run('explorer.exe', [path]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('폴더 열기 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _stopRecordingSafely() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('녹화 중단'),
        content: const Text(
          '현재 진행 중인 녹화를 중단하고\n파일을 저장하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          AppButton(
            onPressed: () => Navigator.pop(context, true),
            backgroundColor: AppColors.error,
            child: const Text('중단 및 저장'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _recorderService.stopRecording();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('녹화가 저장되었습니다.'),
              backgroundColor: AppColors.success,
            ),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('녹화 중단 실패: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
