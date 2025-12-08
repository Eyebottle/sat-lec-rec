import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'services/logger_service.dart';
import 'ui/screens/main_screen.dart';
import 'ui/style/app_theme.dart';

final logger = LoggerService.instance.logger;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Window initialization
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1000, 700), // Slightly larger for new UI
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'SatLecRec - 토요일 강의 자동 녹화',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  logger.i('App Started: SatLecRec (Light Theme)');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SatLecRec',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,  // 라이트 테마 사용
      home: const MainScreen(),    // MainScreen 사용
    );
  }
}
