// lib/models/recording_schedule.dart
// 녹화 스케줄 데이터 모델
//
// 목적: 예약 녹화 정보를 저장하고 관리 (Phase 3.2.1)
// - 반복 예약 (요일 기반) 또는 1회성 예약 (특정 날짜) 지원
// - 시작 시간, 녹화 시간, Zoom 링크
// - JSON 직렬화/역직렬화 지원

import 'package:flutter/material.dart';

/// 스케줄 타입
enum ScheduleType {
  /// 매주 반복 (요일 기반)
  weekly,

  /// 1회성 예약 (특정 날짜)
  oneTime,
}

/// 녹화 예약 정보를 담는 데이터 클래스
class RecordingSchedule {
  /// 고유 ID (UUID)
  final String id;

  /// 스케줄 이름 (예: "토요일 오전 강의", "11월 15일 특강")
  final String name;

  /// 스케줄 타입 (weekly 또는 oneTime)
  final ScheduleType type;

  /// 요일 (0 = 일요일, 1 = 월요일, ..., 6 = 토요일)
  /// type이 weekly일 때만 사용
  final int? dayOfWeek;

  /// 특정 날짜 (type이 oneTime일 때만 사용)
  final DateTime? specificDate;

  /// 시작 시각 (24시간 형식)
  final TimeOfDay startTime;

  /// 녹화 시간 (분 단위)
  final int durationMinutes;

  /// Zoom 링크
  final String zoomLink;

  /// Zoom 회의 암호 (선택 사항)
  final String? password;

  /// 활성화 여부
  final bool isEnabled;

  /// 생성일시
  final DateTime createdAt;

  /// 마지막 실행 일시 (nullable)
  final DateTime? lastExecutedAt;

  RecordingSchedule({
    required this.id,
    required this.name,
    required this.type,
    this.dayOfWeek,
    this.specificDate,
    required this.startTime,
    required this.durationMinutes,
    required this.zoomLink,
    this.password,
    this.isEnabled = true,
    DateTime? createdAt,
    this.lastExecutedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        assert(
          (type == ScheduleType.weekly && dayOfWeek != null && dayOfWeek >= 0 && dayOfWeek <= 6) ||
          (type == ScheduleType.oneTime && specificDate != null),
          'weekly 타입은 dayOfWeek 필수, oneTime 타입은 specificDate 필수',
        );

  /// 스케줄 표시 이름 (요일 또는 날짜)
  String get scheduleDisplayName {
    if (type == ScheduleType.weekly) {
      const days = ['일요일', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일'];
      return '매주 ${days[dayOfWeek! % 7]}';
    } else {
      // oneTime
      final date = specificDate!;
      return '${date.year}년 ${date.month}월 ${date.day}일';
    }
  }

  /// 요일 이름 (한국어) - 하위 호환성을 위해 유지
  @Deprecated('scheduleDisplayName 사용 권장')
  String get dayOfWeekName {
    if (type == ScheduleType.weekly && dayOfWeek != null) {
      const days = ['일요일', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일'];
      return days[dayOfWeek! % 7];
    }
    return '특정 날짜';
  }

  /// 시작 시각 문자열 (HH:MM)
  String get startTimeFormatted {
    final hour = startTime.hour.toString().padLeft(2, '0');
    final minute = startTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Cron 표현식 생성
  /// - Weekly: "분 시 * * 요일" (예: "0 10 * * 6" = 매주 토요일 10:00)
  /// - OneTime: "분 시 일 월 *" (예: "0 10 15 11 *" = 11월 15일 10:00)
  String get cronExpression {
    if (type == ScheduleType.weekly) {
      return '${startTime.minute} ${startTime.hour} * * $dayOfWeek';
    } else {
      // oneTime
      final date = specificDate!;
      return '${startTime.minute} ${startTime.hour} ${date.day} ${date.month} *';
    }
  }

  /// 다음 실행 예정 시각 계산
  /// 현재 시각 기준으로 다음 예약 시각을 반환
  DateTime getNextExecutionTime() {
    final now = DateTime.now();

    if (type == ScheduleType.weekly) {
      // 매주 반복: 다음 요일 계산
      var nextExecution = DateTime(
        now.year,
        now.month,
        now.day,
        startTime.hour,
        startTime.minute,
      );

      // 현재 요일과 예약 요일 간 차이 계산
      final currentDayOfWeek = now.weekday % 7; // DateTime.weekday는 1=월요일
      var daysUntilNext = (dayOfWeek! - currentDayOfWeek) % 7;

      // 같은 요일이지만 시간이 지났으면 다음 주로
      if (daysUntilNext == 0 && now.isAfter(nextExecution)) {
        daysUntilNext = 7;
      }

      nextExecution = nextExecution.add(Duration(days: daysUntilNext));
      return nextExecution;
    } else {
      // 1회성: 특정 날짜/시간 반환
      return DateTime(
        specificDate!.year,
        specificDate!.month,
        specificDate!.day,
        startTime.hour,
        startTime.minute,
      );
    }
  }

  /// JSON으로 직렬화
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name, // 'weekly' 또는 'oneTime'
      'dayOfWeek': dayOfWeek,
      'specificDate': specificDate?.toIso8601String(),
      'startTimeHour': startTime.hour,
      'startTimeMinute': startTime.minute,
      'durationMinutes': durationMinutes,
      'zoomLink': zoomLink,
      'password': password,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
      'lastExecutedAt': lastExecutedAt?.toIso8601String(),
    };
  }

  /// JSON에서 역직렬화
  factory RecordingSchedule.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'weekly'; // 기본값: weekly (하위 호환)
    final type = ScheduleType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => ScheduleType.weekly,
    );

    return RecordingSchedule(
      id: json['id'] as String,
      name: json['name'] as String,
      type: type,
      dayOfWeek: json['dayOfWeek'] as int?,
      specificDate: json['specificDate'] != null
          ? DateTime.parse(json['specificDate'] as String)
          : null,
      startTime: TimeOfDay(
        hour: json['startTimeHour'] as int,
        minute: json['startTimeMinute'] as int,
      ),
      durationMinutes: json['durationMinutes'] as int,
      zoomLink: json['zoomLink'] as String,
      password: json['password'] as String?,
      isEnabled: json['isEnabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastExecutedAt: json['lastExecutedAt'] != null
          ? DateTime.parse(json['lastExecutedAt'] as String)
          : null,
    );
  }

  /// copyWith 메서드 (불변 객체 업데이트)
  RecordingSchedule copyWith({
    String? id,
    String? name,
    ScheduleType? type,
    int? dayOfWeek,
    DateTime? specificDate,
    TimeOfDay? startTime,
    int? durationMinutes,
    String? zoomLink,
    String? password,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? lastExecutedAt,
  }) {
    return RecordingSchedule(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      specificDate: specificDate ?? this.specificDate,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      zoomLink: zoomLink ?? this.zoomLink,
      password: password ?? this.password,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
    );
  }

  @override
  String toString() {
    return 'RecordingSchedule(id: $id, name: $name, type: ${type.name}, '
        'schedule: $scheduleDisplayName, time: $startTimeFormatted, '
        'duration: ${durationMinutes}min, enabled: $isEnabled)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecordingSchedule && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
