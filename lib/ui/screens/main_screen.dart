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

            // 4. 테스트 도구 (필요시 접어서 보여주거나 하단 배치)
            _buildQuickTestSection(),
            
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

  /// 다음 예약 히어로 카드 (디자인 개선)
  Widget _buildNextScheduleHeroCard() {
    final schedules = _scheduleService.enabledSchedules;
    
    // 예약이 없을 때
    if (schedules.isEmpty) {
      return AppCard(
        color: Colors.white,
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              '예정된 녹화가 없습니다',
              style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScheduleScreen()),
                );
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('새 스케줄 추가하기'),
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

    final now = DateTime.now();
    final isPast = nextTime.isBefore(now); // 이미 지났는데 녹화가 안 된 경우 등

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_alarm_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'NEXT RECORDING',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_horiz, color: Colors.white.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            nextSchedule.name,
            style: AppTypography.displaySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${nextSchedule.scheduleDisplayName} · ${nextSchedule.startTimeFormatted} 시작',
            style: AppTypography.titleMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 32),
          
          // 카운트다운 타이머
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '녹화 시작까지',
                        style: AppTypography.labelMedium.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      CountdownTimer(
                        targetTime: nextTime,
                        style: AppTypography.headlineMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Monospace', // 숫자가 튀지 않게 고정폭 폰트 권장
                        ),
                        onComplete: () => setState(() {}),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ScheduleScreen()),
                    );
                  }, 
                  icon: const Icon(Icons.edit_calendar_rounded, color: Colors.white),
                  tooltip: '예약 수정',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 녹화 중 상태 카드 (Stop & Save 기능 포함)
  Widget _buildRecordingActiveCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // 애니메이션 효과가 들어간 아이콘 (간단히 구현)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 1),
            builder: (context, value, child) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error.withValues(alpha: 0.1),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.2 * value),
                      blurRadius: 20 * value,
                      spreadRadius: 5 * value,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fiber_manual_record_rounded,
                  color: AppColors.error,
                  size: 48,
                ),
              );
            },
            onEnd: () => setState(() {}), // 계속 반복되도록 (단순 트리거)
          ),
          const SizedBox(height: 24),
          Text(
            '녹화가 진행 중입니다',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '화면과 시스템 오디오를 캡처하고 있습니다.\n종료하려면 아래 버튼을 누르세요.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _stopRecordingSafely,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.stop_circle_outlined, size: 28),
              label: const Text(
                '녹화 중단 및 파일 저장',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
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

  /// 빠른 테스트 섹션
  Widget _buildQuickTestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '시스템 테스트',
            style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: AppButton.tonal(
                onPressed: _recorderService.isRecording ? null : _test10SecRecording,
                icon: Icons.timer_10,
                child: const Text('10초 녹화 테스트'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton.secondary(
                onPressed: _testZoomLaunch,
                icon: Icons.videocam_outlined,
                child: const Text('Zoom 실행 테스트'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Actions ---

  Future<void> _test10SecRecording() async {
    logger.i('10초 테스트 버튼 클릭');
    try {
      final filePath = await _recorderService.startRecording(
        durationSeconds: 10,
      );

      if (filePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('10초 녹화 시작\n$filePath'),
            duration: const Duration(seconds: 3),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      logger.e('녹화 시작 실패', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('녹화 시작 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _testZoomLaunch() async {
    logger.i('Zoom 실행 테스트 버튼 클릭');
    try {
      const testLink = 'https://zoom.us/test';
      final success = await _zoomLauncherService.launchZoomMeeting(
        zoomLink: testLink,
        waitSeconds: 5,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Zoom 실행 성공!' : 'Zoom 실행 실패',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zoom 실행 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

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
