// 무엇을 하는 코드인지: 다음 예약 강의까지 남은 시간을 실시간으로 표시하는 타이머
//
// 목표 시간까지의 남은 시간을 계산하여 "X시간 Y분 Z초 후" 형식으로 표시합니다.
// 1초마다 자동으로 업데이트되며, 타이머 종료 시 콜백을 호출합니다.
//
// 입력: targetTime (목표 DateTime), onComplete (완료 콜백)
// 출력: 남은 시간 텍스트 위젯
// 예외: targetTime이 과거인 경우 "곧 시작" 표시

import 'dart:async';
import 'package:flutter/material.dart';

/// 목표 시간까지의 카운트다운 타이머 위젯
///
/// 1초마다 업데이트되며, 시간:분:초 형식으로 표시합니다.
///
/// 입력:
/// - [targetTime]: 목표 DateTime (예: 녹화 시작 시간)
/// - [onComplete]: 타이머 종료 시 호출되는 콜백 (선택)
/// - [style]: 텍스트 스타일 (선택)
///
/// 출력: "X시간 Y분 Z초 후" 형식의 텍스트
///
/// 예외:
/// - targetTime이 과거면 "곧 시작" 표시
/// - 타이머 종료 시 자동으로 정리됨
class CountdownTimer extends StatefulWidget {
  final DateTime targetTime;
  final VoidCallback? onComplete;
  final TextStyle? style;
  final bool showSeconds;

  const CountdownTimer({
    super.key,
    required this.targetTime,
    this.onComplete,
    this.style,
    this.showSeconds = true,
  });

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _startTimer();
  }

  @override
  void didUpdateWidget(CountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetTime != oldWidget.targetTime) {
      _updateRemaining();
      _timer?.cancel();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateRemaining();
        });

        // 타이머 종료 시 콜백 호출
        if (_remaining.inSeconds <= 0) {
          timer.cancel();
          widget.onComplete?.call();
        }
      }
    });
  }

  void _updateRemaining() {
    final now = DateTime.now();
    final difference = widget.targetTime.difference(now);
    _remaining = difference.isNegative ? Duration.zero : difference;
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds <= 0) {
      return '곧 시작';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    // 1시간 이상 남았을 때
    if (hours > 0) {
      if (widget.showSeconds) {
        return '$hours시간 ${minutes}분 ${seconds}초 후';
      } else {
        return '$hours시간 ${minutes}분 후';
      }
    }

    // 1시간 미만일 때
    if (minutes > 0) {
      if (widget.showSeconds) {
        return '${minutes}분 ${seconds}초 후';
      } else {
        return '${minutes}분 후';
      }
    }

    // 1분 미만일 때
    return '${seconds}초 후';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatDuration(_remaining),
      style: widget.style ??
          const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    );
  }
}

/// 간단한 Countdown 타이머 (초 단위 카운트다운)
///
/// Duration을 받아서 0까지 카운트다운합니다.
/// 주로 짧은 대기 시간 표시에 사용합니다 (예: 10초 카운트다운).
class SimpleCountdown extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onComplete;
  final TextStyle? style;

  const SimpleCountdown({
    super.key,
    required this.duration,
    this.onComplete,
    this.style,
  });

  @override
  State<SimpleCountdown> createState() => _SimpleCountdownState();
}

class _SimpleCountdownState extends State<SimpleCountdown> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remaining -= const Duration(seconds: 1);
        });

        if (_remaining.inSeconds <= 0) {
          timer.cancel();
          widget.onComplete?.call();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _remaining.inSeconds.clamp(0, widget.duration.inSeconds);
    return Text(
      '$seconds초',
      style: widget.style ??
          const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
  }
}
