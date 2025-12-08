// lib/services/settings_service.dart
// 앱 설정 관리 서비스
//
// 목적: 사용자 설정 저장/로드 관리
// - SharedPreferences 기반 영속화
// - 설정 변경 알림

import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import 'task_scheduler_service.dart';

/// 설정 관리 서비스 (싱글톤)
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final Logger _logger = Logger();
  final TaskSchedulerService _taskSchedulerService = TaskSchedulerService();

  /// 현재 설정
  AppSettings _settings = AppSettings.defaults();

  /// 설정 가져오기 (읽기 전용)
  AppSettings get settings => _settings;

  /// SharedPreferences 키
  static const String _settingsPrefKey = 'app_settings';

  /// 설정 변경 스트림 컨트롤러
  final _settingsStreamController = StreamController<AppSettings>.broadcast();

  /// 설정 변경 스트림
  Stream<AppSettings> get settingsStream => _settingsStreamController.stream;

  /// 서비스 초기화
  /// 저장된 설정을 불러옴
  Future<void> initialize() async {
    _logger.i('⚙️ SettingsService 초기화 중...');

    try {
      await _loadSettings();
      _logger.i('✅ SettingsService 초기화 완료: $_settings');
    } catch (e, stackTrace) {
      _logger.e('❌ SettingsService 초기화 실패', error: e, stackTrace: stackTrace);
      // 기본 설정 사용
      _settings = AppSettings.defaults();
    }
  }

  /// 서비스 종료
  Future<void> dispose() async {
    await _settingsStreamController.close();
    _logger.i('✅ SettingsService 종료 완료');
  }

  /// 설정 업데이트
  /// @param settings 새로운 설정
  Future<void> updateSettings(AppSettings settings) async {
    _logger.i('⚙️ 설정 업데이트: $settings');

    try {
      // launchAtStartup 설정이 변경되었는지 확인
      final launchAtStartupChanged = _settings.launchAtStartup != settings.launchAtStartup;

      _settings = settings;
      await _saveSettings();

      // launchAtStartup이 변경되었으면 Task Scheduler 업데이트
      if (launchAtStartupChanged) {
        _logger.i('🚀 시작 시 자동 실행 설정 변경 감지');
        await _taskSchedulerService.registerStartupTask(
          enable: settings.launchAtStartup,
        );
      }

      _settingsStreamController.add(_settings);
      _logger.i('✅ 설정 업데이트 완료');
    } catch (e, stackTrace) {
      _logger.e('❌ 설정 업데이트 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 설정 초기화 (기본값으로 리셋)
  Future<void> resetSettings() async {
    _logger.i('🔄 설정 초기화');

    try {
      _settings = AppSettings.defaults();
      await _saveSettings();
      _settingsStreamController.add(_settings);
      _logger.i('✅ 설정 초기화 완료');
    } catch (e, stackTrace) {
      _logger.e('❌ 설정 초기화 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// SharedPreferences에서 설정 불러오기
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsPrefKey);

      if (settingsJson == null || settingsJson.isEmpty) {
        _logger.i('📭 저장된 설정 없음 - 기본 설정 사용');
        _settings = AppSettings.defaults();
        return;
      }

      final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
      _settings = AppSettings.fromJson(settingsMap);

      _logger.i('📥 설정 불러오기 완료');
    } catch (e, stackTrace) {
      _logger.e('❌ 설정 불러오기 실패', error: e, stackTrace: stackTrace);
      _settings = AppSettings.defaults();
      rethrow;
    }
  }

  /// SharedPreferences에 설정 저장
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(_settings.toJson());

      await prefs.setString(_settingsPrefKey, settingsJson);
      _logger.d('💾 설정 저장 완료');
    } catch (e, stackTrace) {
      _logger.e('❌ 설정 저장 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
