// lib/models/zoom_automation_state.dart
// 무엇을 하는 코드인지: Zoom 자동 진입 단계와 메시지를 UI/서비스에서 공유하기 위한 상태 모델을 정의한다

import 'package:flutter/foundation.dart';

/// Zoom 자동화 단계 열거형
/// - [idle]: 대기 중
/// - [launching]: Zoom 링크 실행 중
/// - [autoJoining]: UI Automation으로 참가 시도
/// - [waitingRoom]: 대기실 승인 대기
/// - [waitingHost]: 호스트 시작 대기
/// - [recordingReady]: 회의 입장 완료, 녹화 준비 상태
/// - [failed]: 오류로 중단된 상태
enum ZoomAutomationStage {
  idle,
  launching,
  autoJoining,
  waitingRoom,
  waitingHost,
  recordingReady,
  failed,
}

/// Zoom 자동화 상태 값 객체 (불변)
class ZoomAutomationState {
  /// 현재 단계
  final ZoomAutomationStage stage;

  /// 사용자에게 보여줄 메시지
  final String message;

  /// 오류 여부 (true면 경고 색상 사용)
  final bool isError;

  /// 마지막 갱신 시각
  final DateTime updatedAt;

  const ZoomAutomationState({
    required this.stage,
    required this.message,
    required this.isError,
    required this.updatedAt,
  });

  /// 기본 대기 상태
  factory ZoomAutomationState.idle() {
    return ZoomAutomationState(
      stage: ZoomAutomationStage.idle,
      message: '대기 중입니다. 자동 녹화 예약을 확인하세요.',
      isError: false,
      updatedAt: DateTime.now(),
    );
  }

  /// 복사본 생성 (일부 필드만 변경)
  ZoomAutomationState copyWith({
    ZoomAutomationStage? stage,
    String? message,
    bool? isError,
    DateTime? updatedAt,
  }) {
    return ZoomAutomationState(
      stage: stage ?? this.stage,
      message: message ?? this.message,
      isError: isError ?? this.isError,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 사람이 읽기 쉬운 단계 라벨
  String get readableStageLabel {
    switch (stage) {
      case ZoomAutomationStage.launching:
        return 'Zoom 실행 중';
      case ZoomAutomationStage.autoJoining:
        return '자동 참가 시도 중';
      case ZoomAutomationStage.waitingRoom:
        return '대기실 승인 대기';
      case ZoomAutomationStage.waitingHost:
        return '호스트 시작 대기';
      case ZoomAutomationStage.recordingReady:
        return '녹화 준비 완료';
      case ZoomAutomationStage.failed:
        return '실패';
      case ZoomAutomationStage.idle:
        return '대기 중';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ZoomAutomationState &&
        other.stage == stage &&
        other.message == message &&
        other.isError == isError &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(stage, message, isError, updatedAt);

  @override
  String toString() =>
      'ZoomAutomationState(stage: $stage, message: $message, isError: $isError, updatedAt: $updatedAt)';
}

/// 읽기 전용 ValueListenable alias (가독성 향상용)
typedef ZoomAutomationListenable = ValueListenable<ZoomAutomationState>;
