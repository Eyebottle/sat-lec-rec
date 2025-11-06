// lib/services/tray_service.dart
// 시스템 트레이 관리 서비스
//
// 목적: Windows 시스템 트레이 통합 (Phase 3.2.3)
// - 창 최소화 시 트레이로 숨김
// - 트레이 아이콘 클릭으로 창 복원
// - 트레이 메뉴 제공 (열기, 스케줄 관리, 종료 등)
// - 녹화 시작/종료 시 알림

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 시스템 트레이 관리 서비스 (싱글톤)
class TrayService {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  final Logger _logger = Logger();
  final SystemTray _systemTray = SystemTray();
  final AppWindow _appWindow = AppWindow();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// 트레이 초기화
  ///
  /// 시스템 트레이 아이콘과 메뉴를 설정합니다.
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.w('⚠️ TrayService 이미 초기화됨');
      return;
    }

    try {
      _logger.i('📍 TrayService 초기화 시작...');

      // 트레이 아이콘 준비
      final String iconPath = await _prepareIcon();
      _logger.d('트레이 아이콘 경로: $iconPath');

      // 파일 존재 여부 최종 확인
      final File iconFile = File(iconPath);
      if (!await iconFile.exists()) {
        throw Exception('트레이 아이콘 파일이 존재하지 않습니다: $iconPath');
      }

      // Windows 경로 형식으로 변환 (백슬래시 사용)
      String normalizedPath = iconPath;
      if (Platform.isWindows) {
        normalizedPath = iconPath.replaceAll('/', '\\');
        _logger.d('Windows 경로로 변환: $normalizedPath');
      }

      // Windows에서는 toolTip이 null이면 안 될 수 있음
      try {
        await _systemTray.initSystemTray(
          title: "sat-lec-rec",
          iconPath: normalizedPath,
          toolTip: "토요일 강의 자동 녹화",
        );
      } catch (e, stackTrace) {
        _logger.e('❌ initSystemTray 호출 실패', error: e, stackTrace: stackTrace);
        _logger.d('사용된 경로: $normalizedPath');
        _logger.d('원본 경로: $iconPath');
        rethrow;
      }

      // 트레이 메뉴 생성
      await _buildTrayMenu();

      // 트레이 메뉴 클릭 이벤트 등록
      _systemTray.registerSystemTrayEventHandler((eventName) {
        _logger.d('트레이 이벤트: $eventName');

        if (eventName == kSystemTrayEventClick) {
          // 단일 클릭: 창 표시/숨김 토글
          _toggleWindowVisibility();
        } else if (eventName == kSystemTrayEventRightClick) {
          // 오른쪽 클릭: 컨텍스트 메뉴 표시
          _systemTray.popUpContextMenu();
        }
      });

      _isInitialized = true;
      _logger.i('✅ TrayService 초기화 완료');
    } catch (e, stackTrace) {
      _logger.e('❌ TrayService 초기화 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 트레이 아이콘 준비
  ///
  /// assets에서 아이콘을 로드하거나, 없으면 임시 디렉토리에 추출합니다.
  /// Windows에서는 .ico 파일을 우선적으로 사용합니다.
  Future<String> _prepareIcon() async {
    try {
      // Windows에서는 .ico 파일을 우선적으로 사용
      // macOS/Linux에서는 .png 파일 사용
      final List<String> iconNames = Platform.isWindows
          ? ['tray_icon.ico', 'tray_icon.png']
          : ['tray_icon.png', 'tray_icon.ico'];

      for (final iconName in iconNames) {
        try {
          // assets에서 로드 시도
          final ByteData data = await rootBundle.load('assets/icons/$iconName');

          // 임시 디렉토리에 저장
          final Directory tempDir = await getTemporaryDirectory();
          final String iconPath = path.join(tempDir.path, iconName);
          final File iconFile = File(iconPath);

          await iconFile.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );

          // 파일이 실제로 존재하는지 확인
          if (!await iconFile.exists()) {
            _logger.w('⚠️ 파일 저장 후 존재하지 않음: $iconPath');
            continue;
          }

          // 절대 경로로 변환 (Windows 호환성)
          final String absolutePath = iconFile.absolute.path;
          _logger.i('✅ 트레이 아이콘 준비 완료: $absolutePath');
          return absolutePath;
        } catch (e) {
          // 이 아이콘 파일이 없으면 다음 시도
          _logger.d('$iconName 없음, 다음 시도...');
          continue;
        }
      }

      // 2. 모든 아이콘이 없으면 에러
      throw Exception('트레이 아이콘 파일을 찾을 수 없습니다: $iconNames');
    } catch (e) {
      _logger.e('❌ 트레이 아이콘 준비 실패', error: e);
      rethrow;
    }
  }

  /// 트레이 메뉴 구성
  Future<void> _buildTrayMenu() async {
    final menu = Menu();

    // 앱 상태 표시 (비활성)
    await menu.buildFrom([
      MenuItemLabel(
        label: '📺 sat-lec-rec',
        enabled: false,
      ),
      MenuSeparator(),

      // 창 열기
      MenuItemLabel(
        label: '열기',
        onClicked: (menuItem) => _showWindow(),
      ),

      // 스케줄 관리 (TODO: 직접 스케줄 화면 열기)
      MenuItemLabel(
        label: '스케줄 관리',
        onClicked: (menuItem) => _showWindow(),
      ),

      MenuSeparator(),

      // 녹화 상태 (동적으로 업데이트 필요)
      MenuItemLabel(
        label: '상태: 대기 중',
        enabled: false,
      ),

      MenuSeparator(),

      // 종료
      MenuItemLabel(
        label: '종료',
        onClicked: (menuItem) => _exitApp(),
      ),
    ]);

    await _systemTray.setContextMenu(menu);
  }

  /// 창 표시/숨김 토글
  Future<void> _toggleWindowVisibility() async {
    try {
      final isVisible = await windowManager.isVisible();

      if (isVisible) {
        await hideWindow();
      } else {
        await _showWindow();
      }
    } catch (e) {
      _logger.e('❌ 창 토글 실패', error: e);
    }
  }

  /// 창 표시
  Future<void> _showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
      _logger.d('🪟 창 표시됨');
    } catch (e) {
      _logger.e('❌ 창 표시 실패', error: e);
    }
  }

  /// 창 숨김 (트레이로 최소화)
  Future<void> hideWindow() async {
    try {
      await windowManager.hide();
      _logger.d('🫥 창 숨김 (트레이로 최소화)');

      // 트레이 알림 (선택적)
      await showNotification(
        title: 'sat-lec-rec',
        message: '백그라운드에서 실행 중입니다.',
      );
    } catch (e) {
      _logger.e('❌ 창 숨김 실패', error: e);
    }
  }

  /// 트레이 알림 표시
  ///
  /// @param title 알림 제목
  /// @param message 알림 내용
  Future<void> showNotification({
    required String title,
    required String message,
  }) async {
    try {
      // system_tray 패키지는 직접 알림을 지원하지 않음
      // Windows 10+ Toast 알림을 사용하려면 별도 패키지 필요
      // 임시로 로그만 출력
      _logger.i('📢 알림: $title - $message');

      // TODO: Phase 4에서 win_toast 패키지 추가하여 실제 알림 구현
    } catch (e) {
      _logger.e('❌ 알림 표시 실패', error: e);
    }
  }

  /// 녹화 상태 업데이트
  ///
  /// 트레이 메뉴의 상태 표시를 업데이트합니다.
  /// @param isRecording 녹화 중 여부
  Future<void> updateRecordingStatus(bool isRecording) async {
    try {
      final menu = Menu();

      await menu.buildFrom([
        MenuItemLabel(
          label: '📺 sat-lec-rec',
          enabled: false,
        ),
        MenuSeparator(),

        MenuItemLabel(
          label: '열기',
          onClicked: (menuItem) => _showWindow(),
        ),

        MenuItemLabel(
          label: '스케줄 관리',
          onClicked: (menuItem) => _showWindow(),
        ),

        MenuSeparator(),

        // 녹화 상태 표시 (동적)
        MenuItemLabel(
          label: isRecording ? '🔴 상태: 녹화 중' : '⚪ 상태: 대기 중',
          enabled: false,
        ),

        MenuSeparator(),

        MenuItemLabel(
          label: '종료',
          onClicked: (menuItem) => _exitApp(),
        ),
      ]);

      await _systemTray.setContextMenu(menu);
      _logger.d('✅ 트레이 메뉴 업데이트 (녹화: $isRecording)');
    } catch (e) {
      _logger.e('❌ 트레이 메뉴 업데이트 실패', error: e);
    }
  }

  /// 앱 종료
  Future<void> _exitApp() async {
    try {
      _logger.i('🚪 앱 종료 요청');

      // TODO: 녹화 중인지 확인하고 경고
      // if (RecorderService().isRecording) {
      //   // 사용자에게 확인 다이얼로그 표시
      //   return;
      // }

      await dispose();
      await windowManager.destroy();
    } catch (e) {
      _logger.e('❌ 앱 종료 실패', error: e);
    }
  }

  /// 트레이 정리
  Future<void> dispose() async {
    try {
      _logger.i('📍 TrayService 종료 중...');
      await _systemTray.destroy();
      _isInitialized = false;
      _logger.i('✅ TrayService 종료 완료');
    } catch (e) {
      _logger.e('❌ TrayService 종료 실패', error: e);
    }
  }
}
