import 'package:flutter/widgets.dart';

/// 중앙에서 재사용하는 간격 상수.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// 자주 사용하는 패딩 프리셋.
class AppPadding {
  static const EdgeInsets screen = EdgeInsets.all(AppSpacing.md);
  static const EdgeInsets card = EdgeInsets.all(AppSpacing.md);
  static const EdgeInsets dialog = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );
}
