import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:uuid/uuid.dart';
import 'services/recorder_service.dart';
import 'services/schedule_service.dart';  // Phase 3.2.1
import 'services/tray_service.dart';  // Phase 3.2.3
import 'services/settings_service.dart';  // Phase 3.3.2
import 'services/zoom_launcher_service.dart';  // Phase 3.3.1
import 'services/logger_service.dart';  // 통합 로깅 시스템
import 'ui/widgets/recording_progress_widget.dart';
import 'ui/screens/schedule_screen.dart';  // Phase 3.2.1
import 'ui/screens/settings_screen.dart';  // Phase 3.3.2
import 'models/recording_schedule.dart';

// 통합 LoggerService 사용
final logger = LoggerService.instance.logger;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Window 관리 초기화
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(900, 700),
    minimumSize: Size(600, 500),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'sat-lec-rec - 토요일 강의 녹화',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  logger.i('sat-lec-rec 앱 시작');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sat-lec-rec',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WindowListener {
  final RecorderService _recorderService = RecorderService();
  final ScheduleService _scheduleService = ScheduleService();  // Phase 3.2.1
  final TrayService _trayService = TrayService();  // Phase 3.2.3
  final SettingsService _settingsService = SettingsService();  // Phase 3.3.2
  final ZoomLauncherService _zoomLauncherService = ZoomLauncherService();  // Phase 3.3.1

  // 예약 입력 필드 컨트롤러
  final TextEditingController _zoomLinkController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // 빌드 완료 후 초기화 실행 (비동기)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeServices();
    });
  }

  Future<void> _initializeServices() async {
    try {
      // Phase 3.3.2: SettingsService 초기화 (가장 먼저)
      logger.i('SettingsService 초기화 시작...');
      await _settingsService.initialize();
      logger.i('✅ SettingsService 초기화 완료');

      logger.i('RecorderService 초기화 시작...');
      await _recorderService.initialize();
      logger.i('✅ RecorderService 초기화 완료');

      // Phase 3.2.1: ScheduleService 초기화
      logger.i('ScheduleService 초기화 시작...');
      await _scheduleService.initialize();
      logger.i('✅ ScheduleService 초기화 완료');

      // Phase 3.2.3: TrayService 초기화 (선택적)
      try {
        logger.i('TrayService 초기화 시작...');
        await _trayService.initialize();
        logger.i('✅ TrayService 초기화 완료');
      } catch (e) {
        logger.w('⚠️ TrayService 초기화 실패 (앱은 계속 실행됨)', error: e);
        // 트레이 없이도 앱은 정상 작동
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
    _scheduleService.dispose();  // Phase 3.2.1
    _trayService.dispose();  // Phase 3.2.3
    _settingsService.dispose();  // Phase 3.3.2
    LoggerService.instance.dispose();  // 로그 서비스 정리
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    logger.i('창 닫기 요청');

    // 녹화 중인지 확인
    if (_recorderService.isRecording) {
      logger.w('⚠️ 녹화 중 - 창 닫기 취소');
      if (mounted) {
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
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('종료'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        );

        if (shouldClose != true) {
          return; // 사용자가 취소
        }

        // 녹화 중지
        try {
          await _recorderService.stopRecording();
          logger.i('녹화 중지 후 앱 종료');
        } catch (e) {
          logger.e('녹화 중지 실패', error: e);
        }
      }
    }

    // Phase 3.2.3: 창 닫기 시 트레이로 최소화
    if (_trayService.isInitialized) {
      logger.i('트레이로 최소화');
      await _trayService.hideWindow();
    } else {
      // 트레이가 초기화되지 않았으면 종료
      logger.w('트레이 미초기화 - 앱 종료');
      windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('sat-lec-rec - 토요일 강의 자동 녹화'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Phase 3.2.1: 스케줄 관리 버튼
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // 예약 정보 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.event,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '녹화 예약',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Zoom 링크 입력
                    TextField(
                      controller: _zoomLinkController,
                      decoration: const InputDecoration(
                        labelText: 'Zoom 링크',
                        hintText: 'https://zoom.us/j/...',
                        prefixIcon: Icon(Icons.link),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // 시작 시간 입력
                        Expanded(
                          child: TextField(
                            controller: _startTimeController,
                            decoration: const InputDecoration(
                              labelText: '시작 시간',
                              hintText: '08:00',
                              prefixIcon: Icon(Icons.access_time),
                              border: OutlineInputBorder(),
                            ),
                            onTap: () async {
                              // 시간 선택 다이얼로그
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (picked != null) {
                                _startTimeController.text = 
                                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                              }
                            },
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // 녹화 시간 입력
                        Expanded(
                          child: TextField(
                            controller: _durationController,
                            decoration: const InputDecoration(
                              labelText: '녹화 시간 (분)',
                              hintText: '80',
                              prefixIcon: Icon(Icons.timer),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _saveSchedule(context),
                            icon: const Icon(Icons.save),
                            label: const Text('예약 저장'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _recorderService.isRecording
                                ? null
                                : () async {
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
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      logger.e('녹화 시작 실패', error: e);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('녹화 시작 실패: $e')),
                                        );
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('10초 테스트'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.secondary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              logger.i('Zoom 실행 테스트 버튼 클릭');
                              try {
                                // 테스트용 Zoom 링크
                                const testLink = 'https://zoom.us/test';

                                final success = await _zoomLauncherService.launchZoomMeeting(
                                  zoomLink: testLink,
                                  waitSeconds: 5,
                                );

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                          ? 'Zoom 실행 성공!\nZoom이 열렸는지 확인하세요.'
                                          : 'Zoom 실행 실패\n로그를 확인하세요.',
                                      ),
                                      duration: const Duration(seconds: 3),
                                      backgroundColor: success ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                logger.e('Zoom 실행 테스트 실패', error: e);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Zoom 실행 실패: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.videocam),
                            label: const Text('Zoom 테스트'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 녹화 진행률 표시 (Phase 3.1.1)
            const RecordingProgressWidget(),
            const SizedBox(height: 16),
            // 상태 표시 카드
            _buildStatusCard(context),
            const SizedBox(height: 16),
            // 버전 정보
            Center(
              child: Text(
                'v1.0.0 (M0: 프로젝트 초기 설정)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// 예약 저장 메서드
  Future<void> _saveSchedule(BuildContext context) async {
    // 입력값 검증
    final zoomLink = _zoomLinkController.text.trim();
    final startTimeStr = _startTimeController.text.trim();
    final durationStr = _durationController.text.trim();

    if (zoomLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zoom 링크를 입력하세요')),
      );
      return;
    }

    if (startTimeStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시작 시간을 선택하세요')),
      );
      return;
    }

    if (durationStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹화 시간을 입력하세요')),
      );
      return;
    }

    // 시간 파싱 (HH:MM 형식)
    final timeParts = startTimeStr.split(':');
    if (timeParts.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시작 시간 형식이 올바르지 않습니다 (HH:MM)')),
      );
      return;
    }

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시작 시간이 올바르지 않습니다')),
      );
      return;
    }

    final durationMinutes = int.tryParse(durationStr);
    if (durationMinutes == null || durationMinutes < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹화 시간은 1분 이상이어야 합니다')),
      );
      return;
    }

    try {
      // 스케줄 생성 (기본: 오늘 요일, 이름은 자동 생성)
      final now = DateTime.now();
      final schedule = RecordingSchedule(
        id: const Uuid().v4(),
        name: '${now.month}/${now.day} ${startTimeStr} 녹화',
        dayOfWeek: now.weekday % 7, // DateTime.weekday는 1=월요일, 0=일요일로 변환
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 예약이 저장되었습니다: ${schedule.name}'),
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {}); // 상태 카드 업데이트
      }
    } catch (e) {
      logger.e('❌ 예약 저장 실패', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 예약 저장 실패: $e')),
        );
      }
    }
  }

  /// 상태 카드 빌더
  Widget _buildStatusCard(BuildContext context) {
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
      statusColor = Colors.red;
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
      statusColor = Colors.blue;
    } else if (activeSchedules.isNotEmpty) {
      statusText = '대기 중';
      detailText = '활성화된 예약 ${activeSchedules.length}개';
      statusIcon = Icons.pending;
      statusColor = Colors.orange;
    } else {
      statusText = '대기 중';
      detailText = '예약된 녹화가 없습니다';
      statusIcon = Icons.info_outline;
      statusColor = Theme.of(context).colorScheme.primary;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              statusIcon,
              color: statusColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '상태: $statusText',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detailText,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
