import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'services/logger_service.dart';
import 'ui/style/app_theme.dart';
import 'ui/screens/main_screen.dart';

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
      theme: AppTheme.lightTheme, // 새로운 디자인 시스템 테마 적용
      home: const MainScreen(),
    );
  }
}
