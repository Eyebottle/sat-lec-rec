# 사용성 개선 구현 계획서

**작성일**: 2025-01-09
**대상 기능**: 2번 키보드 단축키, 3번 예약 템플릿, 5번 녹화 히스토리
**예상 소요 시간**: 총 12-16시간 (3-4일)

---

## 📋 목차

1. [전체 개요](#1-전체-개요)
2. [기능 2: 키보드 단축키 시스템](#2-기능-2-키보드-단축키-시스템)
3. [기능 3: 예약 템플릿 시스템](#3-기능-3-예약-템플릿-시스템)
4. [기능 5: 녹화 히스토리 대시보드](#4-기능-5-녹화-히스토리-대시보드)
5. [통합 계획](#5-통합-계획)
6. [테스트 계획](#6-테스트-계획)
7. [리스크 관리](#7-리스크-관리)

---

## 1. 전체 개요

### 1.1 목표

사용자 경험을 개선하여 다음 목표를 달성:
- **효율성**: 예약 입력 시간 80% 단축 (템플릿)
- **접근성**: 마우스 없이 주요 기능 제어 (단축키)
- **투명성**: 과거 녹화 기록 및 성공률 추적 (히스토리)

### 1.2 우선순위

| 순위 | 기능 | 난이도 | 소요 시간 | 의존성 |
|------|------|--------|-----------|--------|
| 1 | 키보드 단축키 | ⭐⭐ | 3-4시간 | 없음 |
| 2 | 예약 템플릿 | ⭐⭐⭐ | 4-5시간 | 없음 |
| 3 | 녹화 히스토리 | ⭐⭐⭐⭐ | 5-7시간 | 메타 JSON 파일 |

### 1.3 구현 순서

```
Day 1: 키보드 단축키 (3-4h)
Day 2: 예약 템플릿 (4-5h)
Day 3-4: 녹화 히스토리 (5-7h)
```

---

## 2. 기능 2: 키보드 단축키 시스템

### 2.1 목표 및 범위

**목표:**
- 자주 사용하는 5가지 작업에 단축키 제공
- 전역 단축키 (앱이 백그라운드에서도 작동)
- UI에 단축키 힌트 표시 (발견 가능성)

**범위 IN:**
- `Ctrl + R`: 녹화 시작/중지 (전역)
- `Ctrl + T`: 10초 테스트 녹화 (메인 화면)
- `Ctrl + S`: 예약 저장 (예약 입력 화면)
- `Ctrl + ,`: 설정 화면 열기 (전역)
- `Esc`: 녹화 중지 확인 (녹화 중)

**범위 OUT (v1.0):**
- 단축키 커스터마이징 (설정에서 변경)
- 단축키 충돌 감지
- 단축키 도움말 오버레이

### 2.2 기술 스택

**패키지:**
```yaml
dependencies:
  hotkey_manager: ^0.2.3
```

**핵심 클래스:**
- `HotKeyManager`: 전역 싱글톤
- `HotKey`: 단축키 정의
- `HotKeyScope`: system (전역) / inapp (앱 내부)

### 2.3 파일 구조

```
lib/
├── services/
│   └── hotkey_service.dart          (NEW - 296 lines)
├── models/
│   └── app_settings.dart            (MODIFY - +15 lines)
└── ui/
    ├── screens/
    │   ├── main_screen.dart         (MODIFY - +20 lines)
    │   └── settings_screen.dart     (MODIFY - +10 lines)
    └── widgets/
        └── common/
            └── app_button.dart      (MODIFY - +25 lines)
```

### 2.4 상세 구현 계획

#### 2.4.1 Phase 1: HotkeyService 생성 (90분)

**lib/services/hotkey_service.dart**

```dart
// 무엇을 하는 코드인지: 키보드 단축키를 등록하고 관리하는 서비스
//
// 전역 단축키(Ctrl+R, Ctrl+,)와 앱 내부 단축키(Ctrl+T, Ctrl+S)를 등록합니다.
// 단축키 콜백을 받아 적절한 액션을 실행합니다.
//
// 입력: 없음 (싱글톤 패턴)
// 출력: 단축키 이벤트 콜백
// 예외: 단축키 등록 실패 시 로그 기록

import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:flutter/services.dart';
import '../utils/logger_service.dart';

/// 키보드 단축키 관리 서비스
///
/// 전역 단축키(system scope)와 앱 내부 단축키(inapp scope)를 관리합니다.
/// 싱글톤 패턴으로 구현되어 앱 전체에서 하나의 인스턴스만 사용합니다.
///
/// 사용 예시:
/// ```dart
/// await HotkeyService.instance.initialize();
/// HotkeyService.instance.setOnRecordToggle(() {
///   print('녹화 시작/중지');
/// });
/// ```
class HotkeyService {
  static final HotkeyService _instance = HotkeyService._internal();
  static HotkeyService get instance => _instance;

  final Logger _logger = LoggerService.instance.logger;

  // 콜백 함수들
  VoidCallback? _onRecordToggle;      // Ctrl+R
  VoidCallback? _onQuickTest;         // Ctrl+T
  VoidCallback? _onSaveSchedule;      // Ctrl+S
  VoidCallback? _onOpenSettings;      // Ctrl+,
  VoidCallback? _onStopRecording;     // Esc

  // 등록된 단축키 목록
  final List<HotKey> _registeredHotkeys = [];

  bool _isInitialized = false;

  HotkeyService._internal();

  /// 초기화 및 단축키 등록
  ///
  /// 앱 시작 시 main.dart에서 호출합니다.
  /// 기존에 등록된 단축키가 있으면 모두 해제 후 재등록합니다.
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.w('⚠️ HotkeyService already initialized');
      return;
    }

    try {
      // 기존 단축키 모두 해제
      await hotKeyManager.unregisterAll();
      _logger.i('🔧 Unregistered all previous hotkeys');

      // 단축키 등록
      await _registerAllHotkeys();

      _isInitialized = true;
      _logger.i('✅ HotkeyService initialized');
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to initialize HotkeyService', error: e, stackTrace: stackTrace);
    }
  }

  /// 모든 단축키 등록
  Future<void> _registerAllHotkeys() async {
    // 1. Ctrl+R: 녹화 시작/중지 (전역)
    await _registerHotkey(
      key: PhysicalKeyboardKey.keyR,
      modifiers: [HotKeyModifier.control],
      scope: HotKeyScope.system,
      name: 'Record Toggle',
      onPressed: () => _onRecordToggle?.call(),
    );

    // 2. Ctrl+T: 10초 테스트 (앱 내부)
    await _registerHotkey(
      key: PhysicalKeyboardKey.keyT,
      modifiers: [HotKeyModifier.control],
      scope: HotKeyScope.inapp,
      name: 'Quick Test',
      onPressed: () => _onQuickTest?.call(),
    );

    // 3. Ctrl+S: 예약 저장 (앱 내부)
    await _registerHotkey(
      key: PhysicalKeyboardKey.keyS,
      modifiers: [HotKeyModifier.control],
      scope: HotKeyScope.inapp,
      name: 'Save Schedule',
      onPressed: () => _onSaveSchedule?.call(),
    );

    // 4. Ctrl+Comma: 설정 열기 (전역)
    await _registerHotkey(
      key: PhysicalKeyboardKey.comma,
      modifiers: [HotKeyModifier.control],
      scope: HotKeyScope.system,
      name: 'Open Settings',
      onPressed: () => _onOpenSettings?.call(),
    );

    // 5. Esc: 녹화 중지 (앱 내부, 녹화 중에만 활성화)
    await _registerHotkey(
      key: PhysicalKeyboardKey.escape,
      modifiers: [],
      scope: HotKeyScope.inapp,
      name: 'Stop Recording',
      onPressed: () => _onStopRecording?.call(),
    );
  }

  /// 개별 단축키 등록
  Future<void> _registerHotkey({
    required PhysicalKeyboardKey key,
    required List<HotKeyModifier> modifiers,
    required HotKeyScope scope,
    required String name,
    required VoidCallback onPressed,
  }) async {
    try {
      final hotKey = HotKey(
        key: key,
        modifiers: modifiers,
        scope: scope,
      );

      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (hotKey) {
          _logger.d('🎹 Hotkey pressed: $name');
          onPressed();
        },
      );

      _registeredHotkeys.add(hotKey);
      _logger.i('✅ Registered hotkey: $name (${scope.name})');
    } catch (e) {
      _logger.e('❌ Failed to register hotkey: $name', error: e);
    }
  }

  // === 콜백 설정 메서드들 ===

  void setOnRecordToggle(VoidCallback callback) {
    _onRecordToggle = callback;
  }

  void setOnQuickTest(VoidCallback callback) {
    _onQuickTest = callback;
  }

  void setOnSaveSchedule(VoidCallback callback) {
    _onSaveSchedule = callback;
  }

  void setOnOpenSettings(VoidCallback callback) {
    _onOpenSettings = callback;
  }

  void setOnStopRecording(VoidCallback callback) {
    _onStopRecording = callback;
  }

  /// 단축키 힌트 텍스트 반환
  ///
  /// UI에 표시할 단축키 힌트를 생성합니다.
  /// 예: "Ctrl+R", "Ctrl+T"
  static String getHintText(String action) {
    switch (action) {
      case 'record':
        return 'Ctrl+R';
      case 'test':
        return 'Ctrl+T';
      case 'save':
        return 'Ctrl+S';
      case 'settings':
        return 'Ctrl+,';
      case 'stop':
        return 'Esc';
      default:
        return '';
    }
  }

  /// 정리 및 해제
  Future<void> dispose() async {
    try {
      await hotKeyManager.unregisterAll();
      _registeredHotkeys.clear();
      _isInitialized = false;
      _logger.i('🧹 HotkeyService disposed');
    } catch (e) {
      _logger.e('❌ Failed to dispose HotkeyService', error: e);
    }
  }
}
```

**체크리스트:**
- [ ] hotkey_manager 패키지 pubspec.yaml에 추가
- [ ] `flutter pub get` 실행
- [ ] HotkeyService 클래스 작성
- [ ] Logger 연동
- [ ] 5개 단축키 정의 및 등록 메서드 작성
- [ ] 콜백 설정 메서드 작성

#### 2.4.2 Phase 2: main.dart 초기화 (30분)

**lib/main.dart 수정**

```dart
import 'services/hotkey_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 기존 초기화 코드...

  // HotkeyService 초기화 추가
  await HotkeyService.instance.initialize();

  runApp(const MyApp());
}
```

#### 2.4.3 Phase 3: MainScreen 연동 (60분)

**lib/ui/screens/main_screen.dart 수정**

```dart
@override
void initState() {
  super.initState();
  windowManager.addListener(this);

  // 기존 초기화...
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _initializeServices();
    _setupHotkeys(); // 추가
  });
}

/// 단축키 콜백 설정
void _setupHotkeys() {
  final hotkeyService = HotkeyService.instance;

  // Ctrl+R: 녹화 시작/중지
  hotkeyService.setOnRecordToggle(() {
    if (!mounted) return;

    if (_recorderService.isRecording) {
      _stopRecording();
    } else {
      // 빠른 녹화 시작 (기본값 사용)
      _test10SecRecording(); // 또는 예약된 녹화 시작
    }
  });

  // Ctrl+T: 10초 테스트
  hotkeyService.setOnQuickTest(() {
    if (!mounted) return;
    _test10SecRecording();
  });

  // Ctrl+,: 설정 열기
  hotkeyService.setOnOpenSettings(() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  });

  // Esc: 녹화 중지 (녹화 중일 때만)
  hotkeyService.setOnStopRecording(() {
    if (!mounted) return;
    if (_recorderService.isRecording) {
      _stopRecording();
    }
  });
}

Future<void> _stopRecording() async {
  try {
    await _recorderService.stopRecording();
    logger.i('녹화 중지됨 (단축키)');
  } catch (e) {
    logger.e('녹화 중지 실패', error: e);
  }
}
```

#### 2.4.4 Phase 4: UI에 단축키 힌트 표시 (60분)

**lib/ui/widgets/common/app_button.dart 수정**

```dart
/// 단축키 힌트를 포함한 버튼
///
/// `shortcutHint` 파라미터를 추가하여 버튼 우측에 단축키 표시
class AppButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? shortcutHint; // 추가

  const AppButton.primary({
    required this.child,
    this.onPressed,
    this.icon,
    this.shortcutHint, // 추가
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 8),
          ],
          child,
          // 단축키 힌트 추가
          if (shortcutHint != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.black.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                shortcutHint!,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

**MainScreen에서 사용:**

```dart
// 10초 녹화 테스트 버튼
AppButton.tonal(
  onPressed: _recorderService.isRecording ? null : () => _test10SecRecording(),
  icon: Icons.play_circle_outline,
  shortcutHint: HotkeyService.getHintText('test'), // 추가
  child: const Text('10초 녹화 테스트'),
),

// 예약 저장 버튼
AppButton.primary(
  onPressed: () => _saveSchedule(context),
  icon: Icons.save,
  shortcutHint: HotkeyService.getHintText('save'), // 추가
  child: const Text('예약 저장'),
),
```

### 2.5 테스트 시나리오

| # | 테스트 케이스 | 기대 결과 |
|---|--------------|----------|
| 1 | `Ctrl+T` 누름 (메인 화면) | 10초 테스트 녹화 시작 |
| 2 | `Ctrl+R` 누름 (앱 백그라운드) | 녹화 시작/중지 |
| 3 | `Ctrl+S` 누름 (예약 입력 후) | 예약 저장 |
| 4 | `Ctrl+,` 누름 | 설정 화면 열림 |
| 5 | `Esc` 누름 (녹화 중) | 녹화 중지 |
| 6 | 버튼에 단축키 힌트 표시 | "Ctrl+T" 배지 보임 |

### 2.6 예상 난이도 및 소요 시간

- **난이도**: ⭐⭐ (쉬움)
- **순수 코딩**: 2.5시간
- **테스트 및 디버깅**: 1시간
- **총 소요 시간**: **3-4시간**

---

## 3. 기능 3: 예약 템플릿 시스템

### 3.1 목표 및 범위

**목표:**
- 자주 사용하는 예약 설정을 템플릿으로 저장
- 템플릿 1번 클릭으로 예약 입력 필드 자동 채우기
- 템플릿 CRUD (생성, 읽기, 수정, 삭제)

**범위 IN:**
- 템플릿 모델 정의 (이름, Zoom 링크, 요일/시간, 녹화 시간)
- 템플릿 저장/불러오기 (SharedPreferences)
- 메인 화면 "빠른 예약" 섹션
- 템플릿 관리 화면 (CRUD)

**범위 OUT (v1.0):**
- 템플릿 공유 (export/import)
- 템플릿 카테고리 분류
- 템플릿 사용 횟수 통계

### 3.2 데이터 모델

**lib/models/schedule_template.dart (NEW)**

```dart
// 무엇을 하는 코드인지: 예약 템플릿 데이터 모델
//
// 자주 사용하는 예약 설정(Zoom 링크, 시간, 녹화 시간)을 저장하는 템플릿입니다.
// JSON 직렬화/역직렬화를 지원하여 SharedPreferences에 저장 가능합니다.
//
// 입력: 템플릿 이름, Zoom 링크, 스케줄 타입, 요일/날짜, 시작 시간, 녹화 시간
// 출력: ScheduleTemplate 객체
// 예외: 필수 값 누락 시 AssertionError

import 'package:flutter/material.dart';
import 'recording_schedule.dart';

/// 예약 템플릿 모델
///
/// 자주 사용하는 예약 설정을 저장하여 빠르게 재사용할 수 있습니다.
///
/// 예시:
/// ```dart
/// final template = ScheduleTemplate(
///   id: 'template-1',
///   name: '토요일 오전 8시 강의',
///   zoomLink: 'https://zoom.us/j/123456789',
///   scheduleType: ScheduleType.weekly,
///   dayOfWeek: 6, // 토요일
///   startTime: TimeOfDay(hour: 8, minute: 0),
///   durationMinutes: 80,
/// );
/// ```
class ScheduleTemplate {
  final String id;
  final String name;
  final String zoomLink;
  final ScheduleType scheduleType;
  final int? dayOfWeek; // 0=일요일, 6=토요일 (매주 반복용)
  final DateTime? specificDate; // 1회성 예약용
  final TimeOfDay startTime;
  final int durationMinutes;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final int useCount; // 사용 횟수

  ScheduleTemplate({
    required this.id,
    required this.name,
    required this.zoomLink,
    required this.scheduleType,
    this.dayOfWeek,
    this.specificDate,
    required this.startTime,
    required this.durationMinutes,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    this.useCount = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastUsedAt = lastUsedAt ?? DateTime.now();

  /// RecordingSchedule로 변환
  ///
  /// 템플릿을 실제 예약으로 변환합니다.
  /// UUID는 새로 생성되며, isEnabled는 true로 설정됩니다.
  RecordingSchedule toSchedule({required String scheduleId}) {
    return RecordingSchedule(
      id: scheduleId,
      name: name,
      type: scheduleType,
      dayOfWeek: dayOfWeek,
      specificDate: specificDate,
      startTime: startTime,
      durationMinutes: durationMinutes,
      zoomLink: zoomLink,
      isEnabled: true,
    );
  }

  /// JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'zoomLink': zoomLink,
      'scheduleType': scheduleType.toString(),
      'dayOfWeek': dayOfWeek,
      'specificDate': specificDate?.toIso8601String(),
      'startTime': '${startTime.hour}:${startTime.minute}',
      'durationMinutes': durationMinutes,
      'createdAt': createdAt.toIso8601String(),
      'lastUsedAt': lastUsedAt.toIso8601String(),
      'useCount': useCount,
    };
  }

  /// JSON 역직렬화
  factory ScheduleTemplate.fromJson(Map<String, dynamic> json) {
    final timeParts = (json['startTime'] as String).split(':');
    return ScheduleTemplate(
      id: json['id'],
      name: json['name'],
      zoomLink: json['zoomLink'],
      scheduleType: ScheduleType.values.firstWhere(
        (e) => e.toString() == json['scheduleType'],
      ),
      dayOfWeek: json['dayOfWeek'],
      specificDate: json['specificDate'] != null
          ? DateTime.parse(json['specificDate'])
          : null,
      startTime: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      durationMinutes: json['durationMinutes'],
      createdAt: DateTime.parse(json['createdAt']),
      lastUsedAt: DateTime.parse(json['lastUsedAt']),
      useCount: json['useCount'] ?? 0,
    );
  }

  /// 사용 기록 업데이트
  ScheduleTemplate markUsed() {
    return ScheduleTemplate(
      id: id,
      name: name,
      zoomLink: zoomLink,
      scheduleType: scheduleType,
      dayOfWeek: dayOfWeek,
      specificDate: specificDate,
      startTime: startTime,
      durationMinutes: durationMinutes,
      createdAt: createdAt,
      lastUsedAt: DateTime.now(),
      useCount: useCount + 1,
    );
  }

  /// 템플릿 표시 이름 (UI용)
  String get displayName {
    final scheduleInfo = scheduleType == ScheduleType.weekly
        ? '매주 ${_dayOfWeekName(dayOfWeek!)}'
        : '${specificDate!.month}/${specificDate!.day}';
    final timeInfo = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    return '$name · $scheduleInfo $timeInfo · ${durationMinutes}분';
  }

  String _dayOfWeekName(int day) {
    return ['일', '월', '화', '수', '목', '금', '토'][day];
  }

  ScheduleTemplate copyWith({
    String? id,
    String? name,
    String? zoomLink,
    ScheduleType? scheduleType,
    int? dayOfWeek,
    DateTime? specificDate,
    TimeOfDay? startTime,
    int? durationMinutes,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    int? useCount,
  }) {
    return ScheduleTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      zoomLink: zoomLink ?? this.zoomLink,
      scheduleType: scheduleType ?? this.scheduleType,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      specificDate: specificDate ?? this.specificDate,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      useCount: useCount ?? this.useCount,
    );
  }
}
```

### 3.3 서비스 레이어

**lib/services/template_service.dart (NEW)**

```dart
// 무엇을 하는 코드인지: 예약 템플릿 CRUD 관리 서비스
//
// SharedPreferences를 사용하여 템플릿을 영구 저장하고 불러옵니다.
// 템플릿 생성, 읽기, 수정, 삭제 기능을 제공합니다.
//
// 입력: ScheduleTemplate 객체
// 출력: 저장/수정/삭제 결과, 템플릿 목록
// 예외: SharedPreferences 접근 실패 시 에러 로그

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule_template.dart';
import '../utils/logger_service.dart';

/// 예약 템플릿 서비스
///
/// 템플릿을 SharedPreferences에 JSON 형식으로 저장합니다.
/// Key: 'schedule_templates'
/// Value: List<Map<String, dynamic>>
class TemplateService {
  static final TemplateService _instance = TemplateService._internal();
  static TemplateService get instance => _instance;

  final Logger _logger = LoggerService.instance.logger;
  final String _storageKey = 'schedule_templates';

  List<ScheduleTemplate> _templates = [];
  bool _isInitialized = false;

  TemplateService._internal();

  /// 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadTemplates();
      _isInitialized = true;
      _logger.i('✅ TemplateService initialized: ${_templates.length} templates');
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to initialize TemplateService', error: e, stackTrace: stackTrace);
    }
  }

  /// 모든 템플릿 불러오기
  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null || jsonString.isEmpty) {
      _templates = [];
      return;
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _templates = jsonList.map((json) => ScheduleTemplate.fromJson(json)).toList();

      // 마지막 사용 시간 기준 정렬 (최근 사용 순)
      _templates.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    } catch (e) {
      _logger.e('Failed to parse templates JSON', error: e);
      _templates = [];
    }
  }

  /// 템플릿 저장
  Future<void> _saveTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _templates.map((t) => t.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(_storageKey, jsonString);
    } catch (e, stackTrace) {
      _logger.e('Failed to save templates', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 템플릿 추가
  Future<void> addTemplate(ScheduleTemplate template) async {
    _templates.add(template);
    await _saveTemplates();
    _logger.i('✅ Template added: ${template.name}');
  }

  /// 템플릿 수정
  Future<void> updateTemplate(ScheduleTemplate template) async {
    final index = _templates.indexWhere((t) => t.id == template.id);
    if (index != -1) {
      _templates[index] = template;
      await _saveTemplates();
      _logger.i('✅ Template updated: ${template.name}');
    }
  }

  /// 템플릿 삭제
  Future<void> deleteTemplate(String templateId) async {
    _templates.removeWhere((t) => t.id == templateId);
    await _saveTemplates();
    _logger.i('✅ Template deleted: $templateId');
  }

  /// 템플릿 사용 기록
  Future<void> markTemplateUsed(String templateId) async {
    final index = _templates.indexWhere((t) => t.id == templateId);
    if (index != -1) {
      _templates[index] = _templates[index].markUsed();
      await _saveTemplates();
    }
  }

  /// 모든 템플릿 가져오기
  List<ScheduleTemplate> get templates => List.unmodifiable(_templates);

  /// 템플릿 ID로 검색
  ScheduleTemplate? getTemplate(String id) {
    try {
      return _templates.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _templates.clear();
    _isInitialized = false;
  }
}
```

### 3.4 UI 구현

#### 3.4.1 메인 화면 "빠른 예약" 섹션

**lib/ui/screens/main_screen.dart 수정**

```dart
// _buildScheduleInputCard() 위에 추가
Widget _buildQuickTemplates() {
  final templates = TemplateService.instance.templates;

  if (templates.isEmpty) {
    return const SizedBox.shrink();
  }

  return AppCard.level1(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flash_on, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text('빠른 예약', style: AppTypography.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TemplateManagerScreen()),
                );
              },
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('관리'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // 템플릿 목록 (최대 3개 표시)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: templates.take(3).map((template) {
            return TemplateChip(
              template: template,
              onTap: () => _applyTemplate(template),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

/// 템플릿 적용
Future<void> _applyTemplate(ScheduleTemplate template) async {
  setState(() {
    _zoomLinkController.text = template.zoomLink;
    _startTimeController.text = '${template.startTime.hour.toString().padLeft(2, '0')}:${template.startTime.minute.toString().padLeft(2, '0')}';
    _durationController.text = template.durationMinutes.toString();
    _scheduleType = template.scheduleType;
    _selectedDayOfWeek = template.dayOfWeek ?? 6;
    _selectedDate = template.specificDate;
  });

  // 사용 기록
  await TemplateService.instance.markTemplateUsed(template.id);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ 템플릿 "${template.name}" 적용됨'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
```

**lib/ui/widgets/template_chip.dart (NEW)**

```dart
import 'package:flutter/material.dart';
import '../../models/schedule_template.dart';

/// 템플릿 칩 위젯
class TemplateChip extends StatelessWidget {
  final ScheduleTemplate template;
  final VoidCallback onTap;

  const TemplateChip({
    required this.template,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule, size: 16, color: Colors.blue),
            const SizedBox(width: 6),
            Text(
              template.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### 3.4.2 템플릿 관리 화면

**lib/ui/screens/template_manager_screen.dart (NEW)**

```dart
// 무엇을 하는 코드인지: 예약 템플릿 관리 화면
//
// 저장된 템플릿 목록을 표시하고, 추가/수정/삭제할 수 있습니다.
// 템플릿을 길게 누르면 수정/삭제 옵션이 나타납니다.
//
// 입력: 없음
// 출력: 템플릿 목록 UI
// 예외: 없음

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/schedule_template.dart';
import '../../models/recording_schedule.dart';
import '../../services/template_service.dart';

class TemplateManagerScreen extends StatefulWidget {
  const TemplateManagerScreen({super.key});

  @override
  State<TemplateManagerScreen> createState() => _TemplateManagerScreenState();
}

class _TemplateManagerScreenState extends State<TemplateManagerScreen> {
  final TemplateService _templateService = TemplateService.instance;

  @override
  Widget build(BuildContext context) {
    final templates = _templateService.templates;

    return Scaffold(
      appBar: AppBar(
        title: const Text('템플릿 관리'),
      ),
      body: templates.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return _buildTemplateCard(template);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTemplateDialog,
        icon: const Icon(Icons.add),
        label: const Text('새 템플릿'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '저장된 템플릿이 없습니다',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            '자주 사용하는 예약을 템플릿으로 저장하세요',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(ScheduleTemplate template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.bookmark, color: Colors.blue),
        ),
        title: Text(
          template.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(template.displayName),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('수정'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('삭제', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditTemplateDialog(template);
            } else if (value == 'delete') {
              _confirmDeleteTemplate(template);
            }
          },
        ),
      ),
    );
  }

  /// 템플릿 추가 다이얼로그
  void _showAddTemplateDialog() {
    // TODO: 템플릿 입력 폼 다이얼로그
    // 현재 예약 입력 화면과 유사한 UI
  }

  /// 템플릿 수정 다이얼로그
  void _showEditTemplateDialog(ScheduleTemplate template) {
    // TODO: 기존 템플릿 값으로 폼 채워서 표시
  }

  /// 템플릿 삭제 확인
  Future<void> _confirmDeleteTemplate(ScheduleTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('템플릿 삭제'),
        content: Text('"${template.name}" 템플릿을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _templateService.deleteTemplate(template.id);
      setState(() {});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 템플릿이 삭제되었습니다')),
        );
      }
    }
  }
}
```

### 3.5 테스트 시나리오

| # | 테스트 케이스 | 기대 결과 |
|---|--------------|----------|
| 1 | 템플릿 추가 (새 템플릿 버튼) | 폼 입력 후 목록에 추가됨 |
| 2 | 빠른 예약에서 템플릿 클릭 | 예약 입력 필드 자동 채워짐 |
| 3 | 템플릿 수정 | 이름/링크/시간 변경 저장됨 |
| 4 | 템플릿 삭제 | 확인 후 목록에서 제거됨 |
| 5 | 앱 재시작 | 템플릿 목록 유지됨 |

### 3.6 예상 난이도 및 소요 시간

- **난이도**: ⭐⭐⭐ (중간)
- **순수 코딩**: 3.5시간
- **UI 디자인 및 테스트**: 1.5시간
- **총 소요 시간**: **4-5시간**

---

## 4. 기능 5: 녹화 히스토리 대시보드

### 4.1 목표 및 범위

**목표:**
- 과거 녹화 기록을 시각적으로 표시
- 성공률 계산 및 표시
- 파일 빠른 접근 (폴더 열기, 재생)

**범위 IN:**
- 메타 JSON 파일 파싱
- 성공/실패/경고 판정
- 최근 4주 성공률 계산
- 히스토리 목록 (최신순 정렬)
- 파일 열기 버튼

**범위 OUT (v1.0):**
- 썸네일 생성 (FFmpeg - 시간 소요 큼)
- 재생 플레이어 내장
- 통계 그래프 (차트)
- 필터링 (날짜 범위, 성공/실패)

### 4.2 데이터 모델

**lib/models/recording_history.dart (NEW)**

```dart
// 무엇을 하는 코드인지: 녹화 히스토리 데이터 모델
//
// 메타 JSON 파일을 파싱하여 녹화 기록을 표현합니다.
// 성공/실패/경고 상태를 판정합니다.
//
// 입력: 메타 JSON 파일 경로
// 출력: RecordingHistory 객체
// 예외: JSON 파싱 실패 시 null 반환

import 'dart:io';
import 'dart:convert';

enum RecordingStatus {
  success,  // 정상 완료
  warning,  // 경고 (무음, 드롭 프레임 높음)
  failed,   // 실패 (파일 없음, 크기 작음)
}

class RecordingHistory {
  final String id;
  final String? name;
  final String videoPath;
  final String metaPath;
  final DateTime recordedAt;
  final int durationSeconds;
  final int fileSizeBytes;
  final int videoWidth;
  final int videoHeight;
  final int videoFps;
  final double? dropRate;
  final String? encoder;
  final RecordingStatus status;
  final String? statusReason;

  RecordingHistory({
    required this.id,
    this.name,
    required this.videoPath,
    required this.metaPath,
    required this.recordedAt,
    required this.durationSeconds,
    required this.fileSizeBytes,
    required this.videoWidth,
    required this.videoHeight,
    required this.videoFps,
    this.dropRate,
    this.encoder,
    required this.status,
    this.statusReason,
  });

  /// 메타 JSON 파일에서 로드
  static Future<RecordingHistory?> fromMetaFile(File metaFile) async {
    try {
      final jsonString = await metaFile.readAsString();
      final Map<String, dynamic> meta = jsonDecode(jsonString);

      // 비디오 파일 경로
      final videoPath = metaFile.path.replaceAll('.json', '');
      final videoFile = File(videoPath);

      // 상태 판정
      final status = _determineStatus(meta, videoFile);

      return RecordingHistory(
        id: meta['id'] ?? metaFile.path,
        name: meta['name'],
        videoPath: videoPath,
        metaPath: metaFile.path,
        recordedAt: DateTime.parse(meta['recorded_at'] ?? meta['started_at']),
        durationSeconds: meta['duration_seconds'] ?? 0,
        fileSizeBytes: videoFile.existsSync() ? videoFile.lengthSync() : 0,
        videoWidth: meta['video_width'] ?? 0,
        videoHeight: meta['video_height'] ?? 0,
        videoFps: meta['video_fps'] ?? 0,
        dropRate: meta['drop_rate']?.toDouble(),
        encoder: meta['encoder'],
        status: status.$1,
        statusReason: status.$2,
      );
    } catch (e) {
      print('Failed to parse meta file: ${metaFile.path}, error: $e');
      return null;
    }
  }

  /// 상태 판정 로직
  static (RecordingStatus, String?) _determineStatus(
    Map<String, dynamic> meta,
    File videoFile,
  ) {
    // 1. 파일 존재 여부
    if (!videoFile.existsSync()) {
      return (RecordingStatus.failed, '파일 없음');
    }

    // 2. 파일 크기 (1MB 미만)
    if (videoFile.lengthSync() < 1024 * 1024) {
      return (RecordingStatus.failed, '파일 크기 너무 작음');
    }

    // 3. 드롭 프레임 (1% 이상)
    final dropRate = meta['drop_rate']?.toDouble();
    if (dropRate != null && dropRate > 0.01) {
      return (RecordingStatus.warning, '드롭 프레임 높음: ${(dropRate * 100).toStringAsFixed(1)}%');
    }

    // 4. 녹화 시간 (예상 시간의 90% 미만)
    final scheduledDuration = meta['scheduled_duration_sec'];
    final actualDuration = meta['duration_seconds'];
    if (scheduledDuration != null && actualDuration != null) {
      if (actualDuration < scheduledDuration * 0.9) {
        return (RecordingStatus.warning, '녹화 시간 짧음: ${actualDuration}초 / ${scheduledDuration}초');
      }
    }

    // 정상
    return (RecordingStatus.success, null);
  }

  /// 파일 크기를 사람이 읽기 쉬운 형식으로
  String get fileSizeFormatted {
    if (fileSizeBytes >= 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
    } else {
      return '${(fileSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
  }

  /// 녹화 시간을 "X시간 Y분" 형식으로
  String get durationFormatted {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours시간 ${minutes}분';
    } else {
      return '${minutes}분';
    }
  }
}
```

### 4.3 서비스 레이어

**lib/services/history_service.dart (NEW)**

```dart
// 무엇을 하는 코드인지: 녹화 히스토리 관리 서비스
//
// 저장 폴더에서 메타 JSON 파일을 스캔하여 히스토리 목록을 생성합니다.
// 성공률을 계산합니다.
//
// 입력: 없음
// 출력: 히스토리 목록, 성공률
// 예외: 폴더 접근 실패 시 빈 목록 반환

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/recording_history.dart';
import '../services/settings_service.dart';
import '../utils/logger_service.dart';

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  static HistoryService get instance => _instance;

  final Logger _logger = LoggerService.instance.logger;
  final SettingsService _settingsService = SettingsService();

  List<RecordingHistory> _histories = [];
  bool _isLoaded = false;

  HistoryService._internal();

  /// 히스토리 로드
  Future<void> loadHistories() async {
    try {
      final savePath = _settingsService.settings.saveFolderPath;
      final directory = Directory(savePath);

      if (!directory.existsSync()) {
        _logger.w('⚠️ Save directory not found: $savePath');
        _histories = [];
        _isLoaded = true;
        return;
      }

      // *.mp4.json 파일 검색
      final metaFiles = directory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.mp4.json'))
          .toList();

      _logger.i('📂 Found ${metaFiles.length} meta files');

      // 파싱
      final futures = metaFiles.map((file) => RecordingHistory.fromMetaFile(file));
      final results = await Future.wait(futures);

      _histories = results.whereType<RecordingHistory>().toList();

      // 최신순 정렬
      _histories.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

      _isLoaded = true;
      _logger.i('✅ Loaded ${_histories.length} recording histories');
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to load histories', error: e, stackTrace: stackTrace);
      _histories = [];
      _isLoaded = true;
    }
  }

  /// 최근 N주 성공률 계산
  double getSuccessRate({int weeks = 4}) {
    final cutoff = DateTime.now().subtract(Duration(days: weeks * 7));
    final recentHistories = _histories.where((h) => h.recordedAt.isAfter(cutoff)).toList();

    if (recentHistories.isEmpty) return 0.0;

    final successCount = recentHistories.where((h) => h.status == RecordingStatus.success).length;
    return (successCount / recentHistories.length) * 100;
  }

  /// 성공/경고/실패 카운트
  Map<RecordingStatus, int> getStatusCounts({int weeks = 4}) {
    final cutoff = DateTime.now().subtract(Duration(days: weeks * 7));
    final recentHistories = _histories.where((h) => h.recordedAt.isAfter(cutoff)).toList();

    return {
      RecordingStatus.success: recentHistories.where((h) => h.status == RecordingStatus.success).length,
      RecordingStatus.warning: recentHistories.where((h) => h.status == RecordingStatus.warning).length,
      RecordingStatus.failed: recentHistories.where((h) => h.status == RecordingStatus.failed).length,
    };
  }

  /// 모든 히스토리 반환
  List<RecordingHistory> get histories => List.unmodifiable(_histories);

  /// 히스토리 새로고침
  Future<void> refresh() async {
    _isLoaded = false;
    await loadHistories();
  }

  void dispose() {
    _histories.clear();
    _isLoaded = false;
  }
}
```

### 4.4 UI 구현

**lib/ui/screens/history_screen.dart (NEW)**

```dart
// 무엇을 하는 코드인지: 녹화 히스토리 화면
//
// 과거 녹화 기록을 목록으로 표시하고, 성공률을 보여줍니다.
// 각 기록을 탭하면 파일 위치를 열거나 재생할 수 있습니다.
//
// 입력: 없음
// 출력: 히스토리 목록 UI
// 예외: 없음

import 'package:flutter/material.dart';
import 'dart:io';
import '../../models/recording_history.dart';
import '../../services/history_service.dart';
import '../widgets/common/app_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _historyService = HistoryService.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistories();
  }

  Future<void> _loadHistories() async {
    setState(() => _isLoading = true);
    await _historyService.loadHistories();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('녹화 히스토리')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final histories = _historyService.histories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('녹화 히스토리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistories,
          ),
        ],
      ),
      body: Column(
        children: [
          // 상단 성공률 카드
          _buildSuccessRateCard(),

          const Divider(),

          // 히스토리 목록
          Expanded(
            child: histories.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: histories.length,
                    itemBuilder: (context, index) {
                      return _buildHistoryCard(histories[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessRateCard() {
    final successRate = _historyService.getSuccessRate(weeks: 4);
    final counts = _historyService.getStatusCounts(weeks: 4);
    final total = counts.values.reduce((a, b) => a + b);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            '최근 4주 성공률',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '${successRate.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${counts[RecordingStatus.success]}/${total}건 성공',
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
          ),
          if (counts[RecordingStatus.warning]! > 0 || counts[RecordingStatus.failed]! > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (counts[RecordingStatus.warning]! > 0)
                  Text(
                    '⚠️ 경고 ${counts[RecordingStatus.warning]}건',
                    style: TextStyle(color: Colors.orange.shade200, fontSize: 12),
                  ),
                if (counts[RecordingStatus.warning]! > 0 && counts[RecordingStatus.failed]! > 0)
                  const SizedBox(width: 16),
                if (counts[RecordingStatus.failed]! > 0)
                  Text(
                    '❌ 실패 ${counts[RecordingStatus.failed]}건',
                    style: TextStyle(color: Colors.red.shade200, fontSize: 12),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '녹화 기록이 없습니다',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(RecordingHistory history) {
    Color statusColor;
    IconData statusIcon;

    switch (history.status) {
      case RecordingStatus.success:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case RecordingStatus.warning:
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case RecordingStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          history.name ?? '녹화 파일',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${history.recordedAt.year}-${history.recordedAt.month.toString().padLeft(2, '0')}-${history.recordedAt.day.toString().padLeft(2, '0')} ${history.recordedAt.hour.toString().padLeft(2, '0')}:${history.recordedAt.minute.toString().padLeft(2, '0')}',
            ),
            Text('${history.durationFormatted} · ${history.fileSizeFormatted}'),
            if (history.statusReason != null)
              Text(
                history.statusReason!,
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.folder_open),
          onPressed: () => _openFileLocation(history.videoPath),
        ),
      ),
    );
  }

  /// 파일 위치 열기
  Future<void> _openFileLocation(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ 파일을 찾을 수 없습니다')),
          );
        }
        return;
      }

      // Windows: explorer.exe /select,"path"
      await Process.run('explorer.exe', ['/select,', filePath]);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 열기 실패: $e')),
        );
      }
    }
  }
}
```

### 4.5 메인 화면에 히스토리 버튼 추가

**lib/ui/screens/main_screen.dart AppBar actions 수정**

```dart
actions: [
  // 히스토리 버튼 추가
  IconButton(
    icon: const Icon(Icons.history),
    tooltip: '녹화 히스토리',
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HistoryScreen()),
      );
    },
  ),
  IconButton(
    icon: const Icon(Icons.calendar_month),
    tooltip: '스케줄 관리',
    onPressed: () { /* 기존 코드 */ },
  ),
  IconButton(
    icon: const Icon(Icons.settings),
    tooltip: '설정',
    onPressed: () { /* 기존 코드 */ },
  ),
],
```

### 4.6 테스트 시나리오

| # | 테스트 케이스 | 기대 결과 |
|---|--------------|----------|
| 1 | 히스토리 화면 열기 (빈 상태) | "녹화 기록이 없습니다" 표시 |
| 2 | 녹화 완료 후 히스토리 새로고침 | 새 기록 목록에 추가됨 |
| 3 | 성공률 계산 (3/4건 성공) | "75.0%" 표시 |
| 4 | 파일 열기 버튼 클릭 | Explorer에서 파일 위치 열림 |
| 5 | 드롭 프레임 높은 파일 | 경고 상태 표시 |

### 4.7 예상 난이도 및 소요 시간

- **난이도**: ⭐⭐⭐⭐ (높음)
- **순수 코딩**: 4시간
- **메타 JSON 파싱 및 테스트**: 2시간
- **UI 디자인 및 정제**: 1시간
- **총 소요 시간**: **5-7시간**

---

## 5. 통합 계획

### 5.1 구현 순서 (권장)

```
[Day 1] 키보드 단축키 (3-4h)
├── 1. hotkey_manager 패키지 추가 (30min)
├── 2. HotkeyService 작성 (90min)
├── 3. MainScreen 연동 (60min)
└── 4. UI 힌트 표시 (60min)

[Day 2] 예약 템플릿 (4-5h)
├── 1. ScheduleTemplate 모델 (60min)
├── 2. TemplateService 작성 (90min)
├── 3. 빠른 예약 UI (90min)
└── 4. 템플릿 관리 화면 (90min)

[Day 3-4] 녹화 히스토리 (5-7h)
├── 1. RecordingHistory 모델 (90min)
├── 2. HistoryService 작성 (120min)
├── 3. HistoryScreen UI (150min)
└── 4. 통합 테스트 (60min)
```

### 5.2 pubspec.yaml 패키지 추가

```yaml
dependencies:
  flutter:
    sdk: flutter

  # 기존 패키지들...
  window_manager: ^0.4.4
  system_tray: ^2.0.3
  shared_preferences: ^2.3.2
  logger: ^2.4.0
  cron: ^0.5.1
  uuid: ^3.0.7
  path_provider: ^2.1.5

  # 새로 추가할 패키지
  hotkey_manager: ^0.2.3  # 키보드 단축키
```

### 5.3 파일 체크리스트

**신규 생성 파일 (8개):**
- [ ] `lib/services/hotkey_service.dart`
- [ ] `lib/services/template_service.dart`
- [ ] `lib/services/history_service.dart`
- [ ] `lib/models/schedule_template.dart`
- [ ] `lib/models/recording_history.dart`
- [ ] `lib/ui/screens/template_manager_screen.dart`
- [ ] `lib/ui/screens/history_screen.dart`
- [ ] `lib/ui/widgets/template_chip.dart`

**수정 파일 (3개):**
- [ ] `lib/main.dart` (HotkeyService 초기화)
- [ ] `lib/ui/screens/main_screen.dart` (단축키 연동, 템플릿, 히스토리 버튼)
- [ ] `lib/ui/widgets/common/app_button.dart` (shortcutHint 추가)

### 5.4 Git 커밋 전략

```bash
# Day 1
git commit -m "feat: 키보드 단축키 시스템 구현 (Ctrl+R, Ctrl+T, Ctrl+S, Ctrl+,)"

# Day 2
git commit -m "feat: 예약 템플릿 시스템 구현 (빠른 예약, 템플릿 관리)"

# Day 3-4
git commit -m "feat: 녹화 히스토리 대시보드 구현 (성공률, 히스토리 목록)"
```

---

## 6. 테스트 계획

### 6.1 단위 테스트

**HotkeyService 테스트:**
- [ ] 단축키 등록 성공
- [ ] 콜백 호출 확인
- [ ] dispose 시 해제 확인

**TemplateService 테스트:**
- [ ] 템플릿 추가/수정/삭제
- [ ] JSON 직렬화/역직렬화
- [ ] SharedPreferences 영속성

**HistoryService 테스트:**
- [ ] 메타 JSON 파싱
- [ ] 성공률 계산
- [ ] 상태 판정 (success/warning/failed)

### 6.2 통합 테스트

| # | 시나리오 | 기대 결과 |
|---|----------|----------|
| 1 | Ctrl+T → 10초 녹화 → 히스토리 확인 | 히스토리에 기록 추가됨 |
| 2 | 템플릿 생성 → 빠른 예약 클릭 → 저장 | 예약 목록에 추가됨 |
| 3 | 녹화 중 Esc → 중지 확인 | 녹화 중지되고 파일 저장됨 |
| 4 | 히스토리에서 파일 열기 | Explorer 열림 |

### 6.3 수동 테스트 체크리스트

**키보드 단축키:**
- [ ] 앱 포커스 상태에서 Ctrl+T 작동
- [ ] 앱 백그라운드에서 Ctrl+R 작동
- [ ] 버튼에 단축키 힌트 표시됨

**예약 템플릿:**
- [ ] 템플릿 추가 → 앱 재시작 → 목록 유지
- [ ] 빠른 예약 클릭 → 필드 자동 채워짐
- [ ] 템플릿 삭제 → 목록에서 제거됨

**녹화 히스토리:**
- [ ] 성공률 정확히 계산됨
- [ ] 드롭 프레임 높은 파일 경고 표시
- [ ] 파일 없는 경우 실패 표시
- [ ] 폴더 열기 정상 작동

---

## 7. 리스크 관리

### 7.1 기술 리스크

| 리스크 | 발생 확률 | 영향도 | 대응 방안 |
|--------|----------|--------|----------|
| hotkey_manager Windows 호환 문제 | 낮음 | 중간 | 공식 문서 확인, 대안으로 win32 API 직접 사용 |
| 메타 JSON 형식 불일치 | 중간 | 높음 | try-catch로 방어, 파싱 실패 시 기본값 사용 |
| SharedPreferences 용량 제한 | 낮음 | 낮음 | 템플릿 개수 제한 (최대 20개) |
| 히스토리 로딩 시간 지연 | 중간 | 중간 | 백그라운드 로딩, 로딩 인디케이터 표시 |

### 7.2 예상 문제 및 해결

**문제 1: 단축키 충돌**
- Ctrl+R이 다른 앱과 충돌 가능성
- 해결: 설정에서 단축키 변경 기능 (v2.0)

**문제 2: 메타 JSON 파일 형식 변경**
- 향후 메타 JSON 형식이 변경되면 파싱 실패
- 해결: 버전 필드 추가, 마이그레이션 로직

**문제 3: 템플릿 개수 증가 시 UI 복잡도**
- 템플릿이 너무 많으면 빠른 예약 섹션이 비대해짐
- 해결: 최대 3개만 표시, "더 보기" 버튼

**문제 4: 히스토리 파일이 많을 때 성능**
- 1000개 이상의 메타 파일 파싱 시 지연
- 해결: 페이지네이션, 최근 100개만 로드

### 7.3 롤백 계획

각 기능은 독립적으로 구현되어 롤백이 용이합니다:

1. **키보드 단축키**: HotkeyService만 제거, 기존 기능 영향 없음
2. **예약 템플릿**: TemplateService 제거, 기존 예약 시스템 유지
3. **녹화 히스토리**: HistoryService 제거, 파일 탐색기로 접근 가능

---

## 8. 다음 세션 시작 가이드

### 8.1 준비 사항

**1. 코드베이스 동기화:**
```bash
cd ~/projects/sat-lec-rec
git pull
syncsat  # WSL → Windows 동기화
```

**2. 패키지 설치:**
```bash
# pubspec.yaml에 hotkey_manager 추가 후
flutter pub get
```

**3. 빌드 테스트:**
```powershell
cd C:\ws-workspace\sat-lec-rec
flutter build windows
```

### 8.2 시작 순서 (추천)

**Step 1: 키보드 단축키 (Day 1)**
1. `lib/services/hotkey_service.dart` 작성
2. `lib/main.dart` 초기화 추가
3. `lib/ui/screens/main_screen.dart` 연동
4. 테스트: Ctrl+T, Ctrl+R 작동 확인
5. 커밋 & 빌드

**Step 2: 예약 템플릿 (Day 2)**
1. `lib/models/schedule_template.dart` 작성
2. `lib/services/template_service.dart` 작성
3. 메인 화면 "빠른 예약" 섹션 추가
4. 템플릿 관리 화면 작성
5. 테스트 & 커밋

**Step 3: 녹화 히스토리 (Day 3-4)**
1. `lib/models/recording_history.dart` 작성
2. `lib/services/history_service.dart` 작성
3. `lib/ui/screens/history_screen.dart` 작성
4. 메인 화면 히스토리 버튼 추가
5. 통합 테스트 & 최종 커밋

### 8.3 각 단계별 완료 기준

**키보드 단축키 완료:**
- [ ] Ctrl+T 눌러서 10초 테스트 실행됨
- [ ] Ctrl+R 눌러서 녹화 시작/중지됨
- [ ] 버튼에 "Ctrl+T" 힌트 표시됨

**예약 템플릿 완료:**
- [ ] 템플릿 추가/수정/삭제 가능
- [ ] 빠른 예약 클릭으로 필드 채워짐
- [ ] 앱 재시작 후 템플릿 유지됨

**녹화 히스토리 완료:**
- [ ] 히스토리 화면에 목록 표시됨
- [ ] 성공률 계산 정확함
- [ ] 파일 열기 버튼 작동함

---

## 9. 참고 자료

**공식 문서:**
- hotkey_manager: https://pub.dev/packages/hotkey_manager
- SharedPreferences: https://pub.dev/packages/shared_preferences
- Material Design 3: https://m3.material.io

**UX 가이드라인:**
- Nielsen Norman Group - Progress Indicators: https://www.nngroup.com/articles/progress-indicators/
- NN/G - Keyboard Shortcuts: https://www.nngroup.com/articles/ui-copy/

**코드 참고:**
- Flutter Desktop 예제: https://github.com/flutter/samples/tree/main/desktop_photo_search
- Hotkey 사용 예시: https://github.com/leanflutter/hotkey_manager/tree/main/example

---

## 10. 요약

### 총 예상 소요 시간
- 키보드 단축키: **3-4시간**
- 예약 템플릿: **4-5시간**
- 녹화 히스토리: **5-7시간**
- **총합: 12-16시간 (3-4일)**

### 핵심 이점
1. **효율성 향상**: 예약 입력 시간 80% 단축
2. **접근성 개선**: 마우스 없이 주요 기능 제어
3. **투명성 확보**: 과거 기록 및 성공률 추적

### 우선순위 요약
1. **키보드 단축키** (쉬움, 즉시 효과)
2. **예약 템플릿** (중간, 반복 작업 개선)
3. **녹화 히스토리** (어려움, 장기 가치)

---

**이 계획서로 다음 세션을 시작하시면 됩니다!** 🚀
