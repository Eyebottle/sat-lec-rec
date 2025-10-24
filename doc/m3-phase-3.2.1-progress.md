# Phase 3.2.1: Cron 기반 예약 녹화 - 완료 보고서

**작성일**: 2025-10-24
**단계**: M3 Phase 3.2.1 (스케줄링 - 예약 녹화)
**상태**: ✅ 완료

---

## 📋 목표

Cron 기반 예약 녹화 시스템 구현

### 요구사항
- 매주 특정 요일 + 시각에 자동 녹화 시작
- 여러 스케줄 관리 (추가/편집/삭제)
- SharedPreferences 기반 영속화
- Cron 표현식 자동 생성
- UI에서 스케줄 CRUD 지원

---

## ✅ 완료 항목

### 1. RecordingSchedule 모델 클래스 (`lib/models/recording_schedule.dart`)

#### 데이터 구조

```dart
class RecordingSchedule {
  final String id;                // UUID
  final String name;              // 스케줄 이름
  final int dayOfWeek;            // 0=일요일, 6=토요일
  final TimeOfDay startTime;      // 시작 시각
  final int durationMinutes;      // 녹화 시간 (분)
  final String zoomLink;          // Zoom 링크
  final bool isEnabled;           // 활성화 여부
  final DateTime createdAt;       // 생성일시
  final DateTime? lastExecutedAt; // 마지막 실행 일시
}
```

#### 주요 메서드

**Cron 표현식 생성** (`lib/models/recording_schedule.dart:66-71`):
```dart
String get cronExpression {
  return '${startTime.minute} ${startTime.hour} * * $dayOfWeek';
}
// 예: "0 10 * * 6" = 매주 토요일 10:00
```

**다음 실행 시각 계산** (`lib/models/recording_schedule.dart:76-98`):
```dart
DateTime getNextExecutionTime() {
  final now = DateTime.now();
  var nextExecution = DateTime(
    now.year, now.month, now.day,
    startTime.hour, startTime.minute,
  );

  final currentDayOfWeek = now.weekday % 7;
  var daysUntilNext = (dayOfWeek - currentDayOfWeek) % 7;

  if (daysUntilNext == 0 && now.isAfter(nextExecution)) {
    daysUntilNext = 7;  // 다음 주로
  }

  return nextExecution.add(Duration(days: daysUntilNext));
}
```

**JSON 직렬화** (`lib/models/recording_schedule.dart:101-133`):
```dart
Map<String, dynamic> toJson() {
  return {
    'id': id,
    'name': name,
    'dayOfWeek': dayOfWeek,
    'startTimeHour': startTime.hour,
    'startTimeMinute': startTime.minute,
    'durationMinutes': durationMinutes,
    'zoomLink': zoomLink,
    'isEnabled': isEnabled,
    'createdAt': createdAt.toIso8601String(),
    'lastExecutedAt': lastExecutedAt?.toIso8601String(),
  };
}

factory RecordingSchedule.fromJson(Map<String, dynamic> json) {
  // ... 역직렬화 로직
}
```

---

### 2. ScheduleService 서비스 (`lib/services/schedule_service.dart`)

#### 싱글톤 패턴

```dart
class ScheduleService {
  static final ScheduleService _instance = ScheduleService._internal();
  factory ScheduleService() => _instance;

  final Cron _cron = Cron();
  final List<RecordingSchedule> _schedules = [];
  final Map<String, ScheduledTask> _cronTasks = {};
}
```

#### 초기화 (`lib/services/schedule_service.dart:46-60`):

```dart
Future<void> initialize() async {
  _logger.i('📅 ScheduleService 초기화 중...');

  await _loadSchedules();          // SharedPreferences에서 로드
  _registerAllCronJobs();          // 활성 스케줄 Cron 등록

  _logger.i('✅ ScheduleService 초기화 완료 (${_schedules.length}개 스케줄)');
}
```

#### CRUD 작업

**스케줄 추가** (`lib/services/schedule_service.dart:87-106`):
```dart
Future<void> addSchedule(RecordingSchedule schedule) async {
  _schedules.add(schedule);
  await _saveSchedules();           // SharedPreferences 저장

  if (schedule.isEnabled) {
    _registerCronJob(schedule);     // Cron 작업 등록
  }
}
```

**스케줄 업데이트** (`lib/services/schedule_service.dart:111-135`):
```dart
Future<void> updateSchedule(RecordingSchedule schedule) async {
  _unregisterCronJob(schedule.id);  // 기존 Cron 제거

  final index = _schedules.indexWhere((s) => s.id == schedule.id);
  _schedules[index] = schedule;
  await _saveSchedules();

  if (schedule.isEnabled) {
    _registerCronJob(schedule);     // Cron 재등록
  }
}
```

**스케줄 삭제** (`lib/services/schedule_service.dart:140-161`):
```dart
Future<void> deleteSchedule(String scheduleId) async {
  _unregisterCronJob(scheduleId);

  final index = _schedules.indexWhere((s) => s.id == scheduleId);
  _schedules.removeAt(index);
  await _saveSchedules();
}
```

#### Cron 작업 관리 (`lib/services/schedule_service.dart:188-207`)

```dart
void _registerCronJob(RecordingSchedule schedule) {
  _unregisterCronJob(schedule.id);  // 중복 등록 방지

  final task = _cron.schedule(
    Schedule.parse(schedule.cronExpression),
    () => _executeScheduledRecording(schedule),
  );

  _cronTasks[schedule.id] = task;

  _logger.i('⏰ Cron 작업 등록: ${schedule.name} (${schedule.cronExpression})');
}
```

#### 예약 녹화 실행 (`lib/services/schedule_service.dart:226-249`)

```dart
Future<void> _executeScheduledRecording(RecordingSchedule schedule) async {
  _logger.i('🎬 예약 녹화 시작: ${schedule.name}');

  // RecorderService 통해 녹화 시작 (임시 구현)
  final outputPath = await _recorderService.startRecordingWithZoomLink(
    zoomLink: schedule.zoomLink,
    durationMinutes: schedule.durationMinutes,
  );

  // 마지막 실행 시각 업데이트
  final updatedSchedule = schedule.copyWith(
    lastExecutedAt: DateTime.now(),
  );
  await updateSchedule(updatedSchedule);
}
```

#### SharedPreferences 영속화 (`lib/services/schedule_service.dart:253-289`)

**저장**:
```dart
Future<void> _saveSchedules() async {
  final prefs = await SharedPreferences.getInstance();
  final schedulesList = _schedules.map((s) => s.toJson()).toList();
  final schedulesJson = jsonEncode(schedulesList);

  await prefs.setString(_schedulesPrefKey, schedulesJson);
}
```

**로드**:
```dart
Future<void> _loadSchedules() async {
  final prefs = await SharedPreferences.getInstance();
  final schedulesJson = prefs.getString(_schedulesPrefKey);

  if (schedulesJson != null) {
    final List<dynamic> schedulesList = jsonDecode(schedulesJson);
    _schedules.clear();

    for (final json in schedulesList) {
      _schedules.add(RecordingSchedule.fromJson(json));
    }
  }
}
```

---

### 3. ScheduleScreen UI (`lib/ui/screens/schedule_screen.dart`)

#### 화면 구성

1. **AppBar**: 다음 예약 정보 표시
2. **Body**: 스케줄 목록 (ListTile 카드)
3. **FAB**: 스케줄 추가 버튼

#### 다음 예약 정보 표시 (`lib/ui/screens/schedule_screen.dart:37-78`)

```dart
Widget _buildNextScheduleInfo() {
  final next = _scheduleService.getNextSchedule();

  if (next == null) {
    return const Text('예약 없음');
  }

  final remaining = next.nextExecution.difference(DateTime.now());
  String remainingText;

  if (remaining.inDays > 0) {
    remainingText = '${remaining.inDays}일 ${remaining.inHours % 24}시간';
  } else if (remaining.inHours > 0) {
    remainingText = '${remaining.inHours}시간 ${remaining.inMinutes % 60}분';
  } else {
    remainingText = '${remaining.inMinutes}분';
  }

  return Column(
    children: [
      Text('다음 예약'),
      Text(next.schedule.name),
      Text(remainingText),
    ],
  );
}
```

#### 스케줄 목록 (`lib/ui/screens/schedule_screen.dart:125-179`)

```dart
Widget _buildScheduleCard(RecordingSchedule schedule) {
  return Card(
    child: ListTile(
      leading: Icon(
        schedule.isEnabled ? Icons.alarm_on : Icons.alarm_off,
        color: schedule.isEnabled ? Colors.green : Colors.grey,
      ),
      title: Text(schedule.name),
      subtitle: Column(
        children: [
          Text('${schedule.dayOfWeekName} ${schedule.startTimeFormatted}'),
          if (schedule.isEnabled)
            Text('다음 실행: ${_formatDateTime(nextExecution)}'),
        ],
      ),
      trailing: Row(
        children: [
          Switch(
            value: schedule.isEnabled,
            onChanged: (value) async {
              await _scheduleService.toggleSchedule(schedule.id);
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditScheduleDialog(schedule),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDeleteSchedule(schedule),
          ),
        ],
      ),
    ),
  );
}
```

#### 스케줄 추가/편집 다이얼로그 (`lib/ui/screens/schedule_screen.dart:196-380`)

**입력 필드**:
- 스케줄 이름 (TextField)
- 요일 선택 (ChoiceChip x 7개)
- 시작 시각 (TimePicker)
- 녹화 시간 (Slider, 30~300분)
- Zoom 링크 (TextField)

```dart
void _showScheduleDialog(RecordingSchedule? existingSchedule) {
  // 폼 초기화
  final nameController = TextEditingController(text: existingSchedule?.name);
  final zoomLinkController = TextEditingController(text: existingSchedule?.zoomLink);
  int selectedDayOfWeek = existingSchedule?.dayOfWeek ?? 6;
  TimeOfDay selectedTime = existingSchedule?.startTime ?? TimeOfDay(hour: 10, minute: 0);
  int durationMinutes = existingSchedule?.durationMinutes ?? 120;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(existingSchedule == null ? '스케줄 추가' : '스케줄 편집'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameController),
              Wrap(children: [/* 요일 ChoiceChip */]),
              OutlinedButton(onPressed: /* TimePicker */),
              Slider(/* 녹화 시간 */),
              TextField(controller: zoomLinkController),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: /* 취소 */),
          ElevatedButton(onPressed: /* 저장 */),
        ],
      ),
    ),
  );
}
```

---

### 4. main.dart 통합 (`lib/main.dart`)

#### ScheduleService 초기화 (`lib/main.dart:92-105`):

```dart
Future<void> _initializeServices() async {
  // RecorderService 초기화
  await _recorderService.initialize();

  // Phase 3.2.1: ScheduleService 초기화
  _logger.i('ScheduleService 초기화 시작...');
  await _scheduleService.initialize();
  _logger.i('✅ ScheduleService 초기화 완료');
}

@override
void dispose() {
  _recorderService.dispose();
  _scheduleService.dispose();  // Phase 3.2.1
  super.dispose();
}
```

#### 스케줄 관리 버튼 (`lib/main.dart:129-140`):

```dart
AppBar(
  actions: [
    // Phase 3.2.1: 스케줄 관리 버튼
    IconButton(
      icon: const Icon(Icons.calendar_month),
      tooltip: '스케줄 관리',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ScheduleScreen()),
        );
      },
    ),
  ],
)
```

---

## 🧪 빌드 결과

```
✅ Windows 빌드 성공
   - 빌드 시간: 25.0초
   - 출력: build\windows\x64\runner\Release\sat_lec_rec.exe
   - 경고: 없음
```

### 빌드 과정 중 수정 사항

**1. UUID 패키지 버전 충돌**:
- 문제: `system_tray`가 `uuid ^3.0.6` 요구, 최초 `uuid ^4.5.1` 추가
- 해결: `pubspec.yaml`에서 `uuid: ^3.0.7`로 다운그레이드

**2. RecorderService 메서드 시그니처 불일치**:
- 문제: `schedule_service.dart:333`에서 존재하지 않는 `outputPath` 매개변수 사용
- 해결: `startRecording(durationSeconds: ...)` 형식으로 수정

---

## 📝 코드 변경 통계

| 파일 | 라인 수 | 설명 |
|------|---------|------|
| `lib/models/recording_schedule.dart` | 177 | 새 파일 - 스케줄 데이터 모델 |
| `lib/services/schedule_service.dart` | 339 | 새 파일 - 스케줄 관리 서비스 |
| `lib/ui/screens/schedule_screen.dart` | 398 | 새 파일 - 스케줄 관리 UI |
| `lib/main.dart` | +15 | ScheduleService 통합 |
| `pubspec.yaml` | +1 | uuid 패키지 추가 |
| **합계** | **+930** | 3개 신규 파일, 2개 수정 |

---

## 🎯 기능 요약

### ✅ 구현 완료
- [x] Cron 기반 스케줄 등록/해제
- [x] 여러 스케줄 관리 (CRUD)
- [x] SharedPreferences 영속화
- [x] UI에서 스케줄 추가/편집/삭제
- [x] 활성화/비활성화 토글
- [x] 다음 예약 시각 계산 및 표시
- [x] 요일 선택 (7개 ChoiceChip)
- [x] 시작 시각 선택 (TimePicker)
- [x] 녹화 시간 설정 (Slider)

### 🚧 미구현 (향후 단계)
- [ ] 실제 Zoom 링크 연동 (Phase 3.2.2에서 처리 예정)
- [ ] T-10분 헬스체크 (Phase 3.2.2)
- [ ] Windows Task Scheduler 통합 (Phase 3.2.3)
- [ ] 예약 녹화 실패 시 사용자 알림

---

## 🔧 기술적 세부 사항

### Cron 표현식

| 요일 | Cron 표현식 | 설명 |
|------|------------|------|
| 일요일 | `0 10 * * 0` | 매주 일요일 10:00 |
| 월요일 | `0 10 * * 1` | 매주 월요일 10:00 |
| 토요일 | `0 10 * * 6` | 매주 토요일 10:00 |

### 다음 실행 시각 계산 알고리즘

1. 현재 시각 기준으로 오늘 날짜 + 예약 시각 계산
2. 현재 요일과 예약 요일 간 차이 계산 (`(dayOfWeek - currentDayOfWeek) % 7`)
3. 같은 요일이지만 시간이 지났으면 7일 추가 (다음 주)
4. 결과 날짜 반환

### SharedPreferences 저장 형식

```json
{
  "recording_schedules": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "토요일 오전 강의",
      "dayOfWeek": 6,
      "startTimeHour": 10,
      "startTimeMinute": 0,
      "durationMinutes": 120,
      "zoomLink": "https://zoom.us/j/123456789",
      "isEnabled": true,
      "createdAt": "2025-10-24T10:00:00.000Z",
      "lastExecutedAt": null
    }
  ]
}
```

---

## 📈 예상 사용 시나리오

### 토요일 강의 예약

1. 사용자가 "스케줄 관리" 버튼 클릭
2. "스케줄 추가" 버튼 클릭
3. 입력:
   - 이름: "토요일 오전 강의"
   - 요일: 토요일
   - 시각: 10:00
   - 시간: 120분
   - Zoom: https://zoom.us/j/...
4. "추가" 버튼 클릭
5. ScheduleService가 Cron 작업 등록
6. 매주 토요일 10:00에 자동 녹화 시작

---

## 🚀 다음 단계

### Phase 3.2.2: T-10 헬스체크 (예정)
- Zoom 링크 유효성 확인
- 네트워크 연결 확인
- 오디오/비디오 장치 확인
- 디스크 공간 확인 (최소 5GB)
- 실패 시 사용자 알림 (시스템 트레이)

### Phase 3.2.3: Windows Task Scheduler 통합 (예정)
- schtasks.exe를 통한 작업 등록
- 절전 모드 해제 옵션
- 자동 시작 설정
- 예약 시각 10분 전 앱 자동 실행

---

## 📚 참고 자료

- **cron 패키지**: https://pub.dev/packages/cron
- **uuid 패키지**: https://pub.dev/packages/uuid (v3.0.7 사용)
- **Cron 표현식**: https://crontab.guru/
- **SharedPreferences**: https://pub.dev/packages/shared_preferences

---

**작성자**: Claude Code
**검토**: Phase 3.2.1 완료 후 작성
**다음 문서**: `m3-phase-3.2.2-progress.md` (Phase 3.2.2 완료 시)
