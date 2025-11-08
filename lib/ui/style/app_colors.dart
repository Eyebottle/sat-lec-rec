import 'package:flutter/material.dart';

/// sat-lec-rec 강의녹화 앱의 디자인 토큰 - 색상 팔레트
///
/// Material Design 3 기반의 일관된 색상 시스템을 제공합니다.
class AppColors {
  AppColors._();

  // ============================================================================
  // Primary Colors
  // ============================================================================

  /// 주요 브랜드 컬러 (Material Blue)
  static const Color primary = Color(0xFF2196F3);

  /// Primary 밝은 변형 (hover, pressed states)
  static const Color primaryLight = Color(0xFF64B5F6);

  /// Primary 어두운 변형 (active states)
  static const Color primaryDark = Color(0xFF1976D2);

  /// Primary 매우 연한 배경 (10% opacity)
  static const Color primaryContainer = Color(0x1A2196F3);

  /// Primary 연한 배경 (20% opacity)
  static const Color primaryContainerLight = Color(0x332196F3);

  // ============================================================================
  // Neutral Colors (무채색 스케일)
  // ============================================================================

  /// 가장 밝은 배경 (앱 전체 배경)
  static const Color neutral50 = Color(0xFFF6F7F8);

  /// 매우 연한 회색 (카드 테두리)
  static const Color neutral100 = Color(0xFFE7EFF3);

  /// 연한 회색 (비활성 요소)
  static const Color neutral200 = Color(0xFFCFD9E0);

  /// 중간 회색 (보조 텍스트)
  static const Color neutral300 = Color(0xFFB0BEC5);

  /// 진한 회색 (본문 텍스트)
  static const Color neutral500 = Color(0xFF54606A);

  /// 더 진한 회색 (부제목)
  static const Color neutral700 = Color(0xFF4A5860);

  /// 가장 진한 회색 (제목, 강조 텍스트)
  static const Color neutral900 = Color(0xFF101C22);

  // ============================================================================
  // Semantic Colors (의미론적 색상)
  // ============================================================================

  /// 성공, 정상 상태
  static const Color success = Color(0xFF2E7D32);

  /// 경고, 주의 필요
  static const Color warning = Color(0xFFFFA000);

  /// 오류, 위험
  static const Color error = Color(0xFFD32F2F);

  /// 정보, 안내
  static const Color info = Color(0xFF1976D2);

  // ============================================================================
  // Functional Colors (기능별 색상)
  // ============================================================================

  /// 녹화 진행 중 상태
  static const Color recordingActive = Color(0xFFD32F2F);

  /// 녹화 대기 중 상태
  static const Color recordingIdle = Color(0xFF757575);

  /// 시스템 트레이 아이콘 색상
  static const Color trayIcon = Color(0xFF2196F3);

  /// 볼륨 미터 - 낮은 레벨 (녹색)
  static const Color volumeLow = Color(0xFF4CAF50);

  /// 볼륨 미터 - 중간 레벨 (노란색)
  static const Color volumeMedium = Color(0xFFFFB300);

  /// 볼륨 미터 - 높은 레벨 (빨간색)
  static const Color volumeHigh = Color(0xFFE53935);

  // ============================================================================
  // Surface Colors (표면 색상)
  // ============================================================================

  /// 기본 배경색
  static const Color background = neutral50;

  /// 카드 표면색
  static const Color surface = Color(0xFFFFFFFF);

  /// 카드 테두리색
  static const Color surfaceBorder = neutral100;

  /// 호버 시 표면 오버레이
  static const Color surfaceHover = Color(0x0A000000);

  // ============================================================================
  // Text Colors (텍스트 색상)
  // ============================================================================

  /// 기본 텍스트 색상
  static const Color textPrimary = neutral900;

  /// 보조 텍스트 색상 (설명, 안내문)
  static const Color textSecondary = neutral500;

  /// 비활성 텍스트 색상
  static const Color textDisabled = neutral300;

  /// 반전 텍스트 (Primary 버튼 위 등)
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /// Primary 색상의 다양한 opacity 변형을 제공
  static Color primaryWithOpacity(double opacity) {
    return primary.withValues(alpha: opacity);
  }

  /// 진단 상태에 따른 색상 반환
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'ok':
      case 'normal':
        return success;
      case 'warning':
      case 'caution':
        return warning;
      case 'error':
      case 'danger':
      case 'failure':
        return error;
      case 'info':
      default:
        return info;
    }
  }

  /// 볼륨 레벨(0.0 ~ 1.0)에 따른 색상 반환
  static Color getVolumeColor(double level) {
    if (level < 0.4) return volumeLow;
    if (level < 0.7) return volumeMedium;
    return volumeHigh;
  }
}
