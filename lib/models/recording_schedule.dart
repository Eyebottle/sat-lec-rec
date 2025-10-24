// lib/models/recording_schedule.dart
// 녹화 스케줄 데이터 모델
//
// 목적: 예약 녹화 정보를 저장하고 관리 (Phase 3.2.1)
// - 요일, 시작 시간, 녹화 시간, Zoom 링크
// - JSON 직렬화/역직렬화 지원

import 'package:flutter/material.dart';

/// 녹화 예약 정보를 담는 데이터 클래스
class RecordingSchedule {
  /// 고유 ID (UUID)
  final String id;

  /// 스케줄 이름 (예: "토요일 오전 강의")
  final String name;

  /// 요일 (0 = 일요일, 1 = 월요일, ..., 6 = 토요일)
  final int dayOfWeek;

  /// 시작 시각 (24시간 형식)
  final TimeOfDay startTime;

  /// 녹화 시간 (분 단위)
  final int durationMinutes;

  /// Zoom 링크
  final String zoomLink;

  /// 활성화 여부
  final bool isEnabled;

  /// 생성일시
  final DateTime createdAt;

  /// 마지막 실행 일시 (nullable)
  final DateTime? lastExecutedAt;

  RecordingSchedule({
    required this.id,
    required this.name,
    required this.dayOfWeek,
    required this.startTime,
    required this.durationMinutes,
    required this.zoomLink,
    this.isEnabled = true,
    DateTime? createdAt,
    this.lastExecutedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 요일 이름 (한국어)
  String get dayOfWeekName {
    const days = ['일요일', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일'];
    return days[dayOfWeek % 7];
  }

  /// 시작 시각 문자열 (HH:MM)
  String get startTimeFormatted {
    final hour = startTime.hour.toString().padLeft(2, '0');
    final minute = startTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Cron 표현식 생성
  /// 형식: "분 시 * * 요일"
  /// 예: "0 10 * * 6" = 매주 토요일 10:00
  String get cronExpression {
    return '${startTime.minute} ${startTime.hour} * * $dayOfWeek';
  }

  /// 다음 실행 예정 시각 계산
  /// 현재 시각 기준으로 다음 예약 시각을 반환
  DateTime getNextExecutionTime() {
    final now = DateTime.now();

    // 오늘 날짜 기준으로 예약 시각 계산
    var nextExecution = DateTime(
      now.year,
      now.month,
      now.day,
      startTime.hour,
      startTime.minute,
    );

    // 현재 요일과 예약 요일 간 차이 계산
    final currentDayOfWeek = now.weekday % 7; // DateTime.weekday는 1=월요일
    var daysUntilNext = (dayOfWeek - currentDayOfWeek) % 7;

    // 같은 요일이지만 시간이 지났으면 다음 주로
    if (daysUntilNext == 0 && now.isAfter(nextExecution)) {
      daysUntilNext = 7;
    }

    nextExecution = nextExecution.add(Duration(days: daysUntilNext));
    return nextExecution;
  }

  /// JSON으로 직렬화
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

  /// JSON에서 역직렬화
  factory RecordingSchedule.fromJson(Map<String, dynamic> json) {
    return RecordingSchedule(
      id: json['id'] as String,
      name: json['name'] as String,
      dayOfWeek: json['dayOfWeek'] as int,
      startTime: TimeOfDay(
        hour: json['startTimeHour'] as int,
        minute: json['startTimeMinute'] as int,
      ),
      durationMinutes: json['durationMinutes'] as int,
      zoomLink: json['zoomLink'] as String,
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
    int? dayOfWeek,
    TimeOfDay? startTime,
    int? durationMinutes,
    String? zoomLink,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? lastExecutedAt,
  }) {
    return RecordingSchedule(
      id: id ?? this.id,
      name: name ?? this.name,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      zoomLink: zoomLink ?? this.zoomLink,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
    );
  }

  @override
  String toString() {
    return 'RecordingSchedule(id: $id, name: $name, day: $dayOfWeekName, '
        'time: $startTimeFormatted, duration: ${durationMinutes}min, enabled: $isEnabled)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecordingSchedule && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
