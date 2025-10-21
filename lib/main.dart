import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:logger/logger.dart';
import 'ffi/native_bindings.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FFI 초기화 및 테스트
  try {
    NativeRecorder.initialize();
    final message = NativeRecorder.hello();
    logger.i('FFI 테스트 성공: $message');

    // FFmpeg 경로 확인 (디버깅)
    final ffmpegPath = NativeRecorder.getFFmpegPath();
    logger.i('🔍 FFmpeg 탐색 경로: $ffmpegPath');

    // FFmpeg 바이너리 존재 여부 확인
    final ffmpegExists = NativeRecorder.checkFFmpeg();
    if (ffmpegExists) {
      logger.i('✅ FFmpeg 바이너리 확인됨');
    } else {
      logger.w('⚠️  FFmpeg 바이너리를 찾을 수 없습니다');
      logger.w('   third_party/ffmpeg/ 폴더에 ffmpeg.exe를 배치하세요');
    }
  } catch (e, stackTrace) {
    logger.e('FFI 초기화 실패', error: e, stackTrace: stackTrace);
  }

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
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    logger.i('창 닫기 요청');
    // TODO: 녹화 중인지 확인 후 안전 종료
    windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('sat-lec-rec - 토요일 강의 자동 녹화'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              logger.d('설정 버튼 클릭');
              // TODO: 설정 화면으로 이동
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('설정 화면 준비 중...')),
              );
            },
          ),
        ],
      ),
      body: Padding(
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
                      decoration: const InputDecoration(
                        labelText: 'Zoom 링크',
                        hintText: 'https://zoom.us/j/...',
                        prefixIcon: Icon(Icons.link),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        logger.d('Zoom 링크 입력: $value');
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // 시작 시간 입력
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: '시작 시간',
                              hintText: '08:00',
                              prefixIcon: Icon(Icons.access_time),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              logger.d('시작 시간 입력: $value');
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // 녹화 시간 입력
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: '녹화 시간 (분)',
                              hintText: '80',
                              prefixIcon: Icon(Icons.timer),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              logger.d('녹화 시간 입력: $value');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              logger.i('예약 저장 버튼 클릭');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('예약 저장 기능 준비 중...')),
                              );
                            },
                            icon: const Icon(Icons.save),
                            label: const Text('예약 저장'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            logger.i('10초 테스트 버튼 클릭');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('10초 테스트 기능 준비 중...')),
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('10초 테스트'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 상태 표시 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '상태: 대기 중',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '예약된 녹화가 없습니다.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
    );
  }
}
