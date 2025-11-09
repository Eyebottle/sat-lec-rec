import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:uuid/uuid.dart';
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
import 'zoom_test_screen.dart';

final logger = LoggerService.instance.logger;

/// 메인 화면
///
/// 녹화 예약 입력, 빠른 테스트, 녹화 진행 상태를 표시하는 메인 화면입니다.
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

  // 예약 입력 필드 컨트롤러
  final TextEditingController _zoomLinkController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  // 스케줄 타입 선택
  ScheduleType _scheduleType = ScheduleType.weekly;
  int _selectedDayOfWeek = 6; // 기본값: 토요일 (0=일요일, 6=토요일)
  DateTime? _selectedDate; // 1회성 예약용

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeServices();
    });
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
  void dispose() {
    _zoomLinkController.dispose();
    _startTimeController.dispose();
    _durationController.dispose();
    _recorderService.dispose();
    _scheduleService.dispose();
    _trayService.dispose();
    _settingsService.dispose();
    LoggerService.instance.dispose();
    windowManager.removeListener(this);
    super.dispose();
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
        title: Text(
          'sat-lec-rec - 토요일 강의 자동 녹화',
          style: AppTypography.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
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
            icon: const Icon(Icons.settings),
            tooltip: '설정',
            onPressed: () {
              logger.d('설정 버튼 클릭');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 다음 예약 히어로 카드
            _buildNextScheduleHeroCard(),
            const SizedBox(height: AppSpacing.md),

            // 녹화 예약 카드
            _buildScheduleInputCard(),
            const SizedBox(height: AppSpacing.md),

            // 빠른 테스트 버튼
            _buildQuickTestSection(),
            const SizedBox(height: AppSpacing.md),

            // 녹화 진행률 위젯
            const RecordingProgressWidget(),
            const SizedBox(height: AppSpacing.md),

            // 상태 카드
            _buildStatusCard(),
            const SizedBox(height: AppSpacing.xl),

            // 버전 정보
            Center(
              child: Text(
                'v1.0.0 (M0: 프로젝트 초기 설정)',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 다음 예약 히어로 카드
  Widget _buildNextScheduleHeroCard() {
    // 활성화된 스케줄 목록 가져오기
    final schedules = _scheduleService.enabledSchedules;

    if (schedules.isEmpty) {
      // 예약이 없을 때는 카드 표시 안 함
      return const SizedBox.shrink();
    }

    // 다음 예약 찾기 (가장 가까운 미래 시간)
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
    final isPast = nextTime.isBefore(now);

    return Container(
      decoration: BoxDecoration(
        gradient: isPast
            ? const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFEE5A52)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF4158D0), Color(0xFFC850C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Row(
            children: [
              Icon(
                isPast ? Icons.warning_amber : Icons.event_available,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isPast ? '예약 시간이 지났습니다' : '다음 예약 강의',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 스케줄 이름
          Text(
            nextSchedule.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // 스케줄 정보
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: Colors.white.withValues(alpha: 0.9),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                nextSchedule.scheduleDisplayName,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.access_time,
                color: Colors.white.withValues(alpha: 0.9),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                nextSchedule.startTimeFormatted,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Countdown Timer
          Center(
            child: CountdownTimer(
              targetTime: nextTime,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
              onComplete: () {
                // 타이머 종료 시 화면 새로고침
                if (mounted) {
                  setState(() {});
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 녹화 예약 입력 카드
  Widget _buildScheduleInputCard() {
    return AppCard.level2(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.event,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '녹화 예약',
                style: AppTypography.headlineSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 스케줄 타입 선택
          Text(
            '예약 방식',
            style: AppTypography.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: RadioListTile<ScheduleType>(
                  title: const Text('매주 반복'),
                  value: ScheduleType.weekly,
                  // ignore: deprecated_member_use
                  groupValue: _scheduleType,
                  // ignore: deprecated_member_use
                  onChanged: (value) {
                    setState(() {
                      _scheduleType = value!;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              Expanded(
                child: RadioListTile<ScheduleType>(
                  title: const Text('1회성'),
                  value: ScheduleType.oneTime,
                  // ignore: deprecated_member_use
                  groupValue: _scheduleType,
                  // ignore: deprecated_member_use
                  onChanged: (value) {
                    setState(() {
                      _scheduleType = value!;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 매주 반복: 요일 선택
          if (_scheduleType == ScheduleType.weekly)
            DropdownButtonFormField<int>(
              initialValue: _selectedDayOfWeek,
              decoration: const InputDecoration(
                labelText: '요일 선택',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text('일요일')),
                DropdownMenuItem(value: 1, child: Text('월요일')),
                DropdownMenuItem(value: 2, child: Text('화요일')),
                DropdownMenuItem(value: 3, child: Text('수요일')),
                DropdownMenuItem(value: 4, child: Text('목요일')),
                DropdownMenuItem(value: 5, child: Text('금요일')),
                DropdownMenuItem(value: 6, child: Text('토요일')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedDayOfWeek = value!;
                });
              },
            ),

          // 1회성: 날짜 선택
          if (_scheduleType == ScheduleType.oneTime)
            InkWell(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '날짜 선택',
                  prefixIcon: Icon(Icons.event),
                ),
                child: Text(
                  _selectedDate != null
                      ? '${_selectedDate!.year}년 ${_selectedDate!.month}월 ${_selectedDate!.day}일'
                      : '날짜를 선택하세요',
                  style: _selectedDate != null ? null : TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),

          // Zoom 링크 입력
          TextField(
            controller: _zoomLinkController,
            decoration: const InputDecoration(
              labelText: 'Zoom 링크',
              hintText: 'https://zoom.us/j/...',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 시작 시간 & 녹화 시간
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startTimeController,
                  decoration: const InputDecoration(
                    labelText: '시작 시간',
                    hintText: '08:00',
                    prefixIcon: Icon(Icons.access_time),
                  ),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                      initialEntryMode: TimePickerEntryMode.input,
                    );
                    if (picked != null) {
                      _startTimeController.text =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    }
                  },
                  readOnly: true,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: '녹화 시간 (분)',
                    hintText: '80',
                    prefixIcon: Icon(Icons.timer),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 저장 버튼
          AppButton.primary(
            onPressed: () => _saveSchedule(context),
            icon: Icons.save,
            child: const Text('예약 저장'),
          ),
        ],
      ),
    );
  }

  /// 빠른 테스트 섹션
  Widget _buildQuickTestSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppButton.tonal(
                onPressed: _recorderService.isRecording
                    ? null
                    : () => _test10SecRecording(),
                icon: Icons.play_circle_outline,
                child: const Text('10초 녹화 테스트'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton.secondary(
                onPressed: () => _testZoomLaunch(),
                icon: Icons.videocam,
                child: const Text('Zoom 실행 테스트'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Zoom 자동화 테스트 화면으로 가는 버튼
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              logger.d('Zoom 자동화 테스트 화면 이동');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ZoomTestScreen()),
              );
            },
            icon: const Icon(Icons.science, size: 20),
            label: const Text('🧪 Zoom 자동화 전체 테스트'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 상태 카드
  Widget _buildStatusCard() {
    final schedules = _scheduleService.schedules;
    final activeSchedules = schedules.where((s) => s.isEnabled).toList();
    final nextSchedule = _scheduleService.getNextSchedule();

    String statusText;
    String detailText;
    IconData statusIcon;
    Color statusColor;

    if (_recorderService.isRecording) {
      statusText = '녹화 중';
      detailText = '현재 녹화가 진행 중입니다';
      statusIcon = Icons.fiber_manual_record;
      statusColor = AppColors.recordingActive;
    } else if (nextSchedule != null) {
      final schedule = nextSchedule.schedule;
      final nextExecution = nextSchedule.nextExecution;
      final remaining = nextExecution.difference(DateTime.now());

      String remainingText;
      if (remaining.inDays > 0) {
        remainingText = '${remaining.inDays}일 ${remaining.inHours % 24}시간';
      } else if (remaining.inHours > 0) {
        remainingText = '${remaining.inHours}시간 ${remaining.inMinutes % 60}분';
      } else {
        remainingText = '${remaining.inMinutes}분';
      }

      statusText = '다음 예약: ${schedule.name}';
      detailText = '$remainingText 후 시작 (${schedule.startTimeFormatted})';
      statusIcon = Icons.schedule;
      statusColor = AppColors.primary;
    } else if (activeSchedules.isNotEmpty) {
      statusText = '대기 중';
      detailText = '활성화된 예약 ${activeSchedules.length}개';
      statusIcon = Icons.pending;
      statusColor = AppColors.warning;
    } else {
      statusText = '대기 중';
      detailText = '예약된 녹화가 없습니다';
      statusIcon = Icons.info_outline;
      statusColor = AppColors.info;
    }

    return AppCard.level1(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '상태: $statusText',
                  style: AppTypography.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  detailText,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 10초 녹화 테스트
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
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('녹화 시작 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Zoom 실행 테스트
  Future<void> _testZoomLaunch() async {
    logger.i('Zoom 실행 테스트 버튼 클릭');
    try {
      const testLink = 'https://zoom.us/test';

      final success = await _zoomLauncherService.launchZoomMeeting(
        zoomLink: testLink,
        waitSeconds: 5,
      );

      if (context.mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Zoom 실행 성공!\nZoom이 열렸는지 확인하세요.'
                  : 'Zoom 실행 실패\n로그를 확인하세요.',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      logger.e('Zoom 실행 테스트 실패', error: e);
      if (context.mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zoom 실행 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// 예약 저장
  Future<void> _saveSchedule(BuildContext context) async {
    final zoomLink = _zoomLinkController.text.trim();
    final startTimeStr = _startTimeController.text.trim();
    final durationStr = _durationController.text.trim();

    // 검증
    if (zoomLink.isEmpty) {
      _showError('Zoom 링크를 입력하세요');
      return;
    }
    if (startTimeStr.isEmpty) {
      _showError('시작 시간을 선택하세요');
      return;
    }
    if (durationStr.isEmpty) {
      _showError('녹화 시간을 입력하세요');
      return;
    }

    // 시간 파싱
    final timeParts = startTimeStr.split(':');
    if (timeParts.length != 2) {
      _showError('시작 시간 형식이 올바르지 않습니다 (HH:MM)');
      return;
    }

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      _showError('시작 시간이 올바르지 않습니다');
      return;
    }

    final durationMinutes = int.tryParse(durationStr);
    if (durationMinutes == null || durationMinutes < 1) {
      _showError('녹화 시간은 1분 이상이어야 합니다');
      return;
    }

    // 1회성 예약은 날짜 필수
    if (_scheduleType == ScheduleType.oneTime && _selectedDate == null) {
      _showError('1회성 예약은 날짜를 선택해야 합니다');
      return;
    }

    try {
      // 스케줄 이름 자동 생성
      final scheduleName = _scheduleType == ScheduleType.weekly
          ? '매주 ${['일', '월', '화', '수', '목', '금', '토'][_selectedDayOfWeek]}요일 $startTimeStr 녹화'
          : '${_selectedDate!.month}/${_selectedDate!.day} $startTimeStr 녹화';

      final schedule = RecordingSchedule(
        id: const Uuid().v4(),
        name: scheduleName,
        type: _scheduleType,
        dayOfWeek: _scheduleType == ScheduleType.weekly ? _selectedDayOfWeek : null,
        specificDate: _scheduleType == ScheduleType.oneTime ? _selectedDate : null,
        startTime: TimeOfDay(hour: hour, minute: minute),
        durationMinutes: durationMinutes,
        zoomLink: zoomLink,
        isEnabled: true,
      );

      await _scheduleService.addSchedule(schedule);
      logger.i('✅ 예약 저장 완료: ${schedule.name}');

      // 입력 필드 초기화
      _zoomLinkController.clear();
      _startTimeController.clear();
      _durationController.clear();
      setState(() {
        _selectedDate = null;
        _scheduleType = ScheduleType.weekly;
        _selectedDayOfWeek = 6; // 토요일로 초기화
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 예약이 저장되었습니다: ${schedule.name}'),
            duration: const Duration(seconds: 3),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      logger.e('❌ 예약 저장 실패', error: e);
      _showError('예약 저장 실패: $e');
    }
  }

  void _showError(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
