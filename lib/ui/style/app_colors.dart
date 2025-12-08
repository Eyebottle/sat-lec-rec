import 'package:flutter/material.dart';

/// sat-lec-rec 강의녹화 앱의 디자인 토큰 - 색상 팔레트 (Premium Dark Theme)
///
/// HomeScreen("Entrance")의 디자인 언어와 일치하는 다크 테마 시스템입니다.
class AppColors {
  AppColors._();

  // ============================================================================
  // Primary Colors (Indigo to Violet Gradient theme) - Kept mostly same
  // ============================================================================

  /// 주요 브랜드 컬러 (Indigo 500)
  static const Color primary = Color(0xFF6366F1);

  /// Primary 밝은 변형 (hover, pressed states)
  static const Color primaryLight = Color(0xFF818CF8);

  /// Primary 어두운 변형 (active states)
  static const Color primaryDark = Color(0xFF4338CA);

  /// Primary 매우 연한 배경 (10% opacity) - Light Mode
  static const Color primaryContainer = Color(0xFFEEF2FF); // Indigo 50

  /// Primary 연한 배경 (20% opacity)
  static const Color primaryContainerLight = Color(0xFFE0E7FF); // Indigo 100

  /// 브랜드 보조 컬러 (Violet 500)
  static const Color secondary = Color(0xFF8B5CF6);

  // ============================================================================
  // Neutral Colors (Premium Slate Scale for Light Mode)
  // ============================================================================

  /// 가장 밝은 색 (White)
  static const Color neutral50 = Color(0xFFF8FAFC); // Slate 50

  /// 밝은 회색 (배경 등)
  static const Color neutral100 = Color(0xFFF1F5F9); // Slate 100

  /// 문구/보조 텍스트 배경
  static const Color neutral200 = Color(0xFFE2E8F0); // Slate 200
  static const Color neutral300 = Color(0xFFCBD5E1); // Slate 300
  static const Color neutral400 = Color(0xFF94A3B8); // Slate 400

  /// 중간 회색 (비활성 아이콘 등)
  static const Color neutral500 = Color(0xFF64748B); // Slate 500

  /// 중간-어두운 회색 (보조 텍스트)
  static const Color neutral600 = Color(0xFF475569); // Slate 600

  /// 어두운 회색 (메인 텍스트)
  static const Color neutral700 = Color(0xFF334155); // Slate 700

  /// 더 어두운 회색 (강조 텍스트)
  static const Color neutral800 = Color(0xFF1E293B); // Slate 800

  /// 가장 어두운 회색 (Black alternative)
  static const Color neutral900 = Color(0xFF0F172A); // Slate 900

  // ============================================================================
  // Semantic Colors (의미론적 색상)
  // ============================================================================

  /// 성공, 정상 상태 (Emerald 500)
  static const Color success = Color(0xFF10B981);

  /// 경고, 주의 필요 (Amber 500)
  static const Color warning = Color(0xFFF59E0B);

  /// 오류, 위험 (Red 500)
  static const Color error = Color(0xFFEF4444);

  /// 정보, 안내 (Sky 500)
  static const Color info = Color(0xFF0EA5E9);

  // ============================================================================
  // Functional Colors (기능별 색상)
  // ============================================================================

  /// 녹화 진행 중 상태
  static const Color recordingActive = Color(0xFFEF4444);

  /// 녹화 대기 중 상태
  static const Color recordingIdle = Color(0xFF94A3B8);

  /// 시스템 트레이 아이콘 색상
  static const Color trayIcon = primary;

  /// 볼륨 미터 - 낮은 레벨
  static const Color volumeLow = success;

  /// 볼륨 미터 - 중간 레벨
  static const Color volumeMedium = warning;

  /// 볼륨 미터 - 높은 레벨
  static const Color volumeHigh = error;

  // ============================================================================
  // Surface Colors (표면 색상 - Light Mode)
  // ============================================================================

  /// 기본 배경색 (Slate 50 - Very Light Grey)
  static const Color background = neutral50;

  /// 카드 표면색 (White)
  static const Color surface = Colors.white;

  /// 카드 테두리색 (Slate 200)
  static const Color surfaceBorder = neutral200;

  /// 호버 시 표면 오버레이 (Black with very low opacity)
  static const Color surfaceHover = Color(0x0A000000);

  // ============================================================================
  // Text Colors (텍스트 색상 - Light Mode)
  // ============================================================================

  /// 기본 텍스트 색상 (Slate 900 - Dark)
  static const Color textPrimary = neutral900;

  /// 보조 텍스트 색상 (Slate 600)
  static const Color textSecondary = neutral600;

  /// 비활성 텍스트 색상 (Slate 400)
  static const Color textDisabled = neutral400;

  /// 반전 텍스트 (Primary 버튼 위 - White)
  static const Color textOnPrimary = Colors.white;

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
