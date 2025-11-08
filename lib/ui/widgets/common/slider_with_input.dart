// 무엇을 하는 코드인지: Slider와 TextField를 결합한 하이브리드 입력 위젯
//
// Slider로 빠른 조정, TextField로 정확한 값 입력이 가능합니다.
// 양방향 동기화로 어느 쪽을 변경해도 자동으로 반영됩니다.
//
// 입력: value (현재 값), min/max (범위), onChanged (변경 콜백)
// 출력: 사용자가 선택한 숫자 값
// 예외: min/max 범위 벗어난 값 입력 시 자동 클램핑

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Slider와 TextField를 결합한 하이브리드 숫자 입력 위젯
///
/// Slider로 빠르게 조정하거나 TextField에 직접 입력 가능합니다.
///
/// 입력:
/// - [value]: 현재 값
/// - [min]: 최소값
/// - [max]: 최대값
/// - [divisions]: Slider의 구간 수 (선택)
/// - [label]: 값 레이블 (Slider 위에 표시)
/// - [suffix]: TextField 뒤에 붙을 단위 (예: "fps", "초")
/// - [onChanged]: 값 변경 시 호출되는 콜백
///
/// 출력: 사용자가 선택한 숫자 값
///
/// 예외: 범위 벗어난 값은 자동으로 min/max로 클램핑
class SliderWithInput extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final String? suffix;
  final ValueChanged<double> onChanged;
  final bool allowDecimals;

  const SliderWithInput({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.label,
    this.suffix,
    required this.onChanged,
    this.allowDecimals = false,
  });

  @override
  State<SliderWithInput> createState() => _SliderWithInputState();
}

class _SliderWithInputState extends State<SliderWithInput> {
  late TextEditingController _controller;
  bool _isEditingText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.allowDecimals
          ? widget.value.toString()
          : widget.value.toInt().toString(),
    );
  }

  @override
  void didUpdateWidget(SliderWithInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 외부에서 값이 변경되었을 때만 TextField 업데이트
    if (!_isEditingText && widget.value != oldWidget.value) {
      _controller.text = widget.allowDecimals
          ? widget.value.toString()
          : widget.value.toInt().toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSliderChanged(double value) {
    final roundedValue = widget.allowDecimals
        ? value
        : value.roundToDouble();

    _controller.text = widget.allowDecimals
        ? roundedValue.toString()
        : roundedValue.toInt().toString();

    widget.onChanged(roundedValue);
  }

  void _onTextChanged(String text) {
    if (text.isEmpty) return;

    final parsedValue = widget.allowDecimals
        ? double.tryParse(text)
        : int.tryParse(text)?.toDouble();

    if (parsedValue != null) {
      // 범위 내 값만 허용 (클램핑)
      final clampedValue = parsedValue.clamp(widget.min, widget.max);

      if (parsedValue != clampedValue) {
        // 범위 벗어나면 자동 클램핑하고 TextField 업데이트
        _controller.text = widget.allowDecimals
            ? clampedValue.toString()
            : clampedValue.toInt().toString();
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }

      widget.onChanged(clampedValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Slider 영역
        Expanded(
          child: Slider(
            value: widget.value,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: widget.label ?? widget.value.toInt().toString(),
            onChanged: _onSliderChanged,
          ),
        ),

        const SizedBox(width: 16),

        // TextField 영역
        SizedBox(
          width: widget.suffix != null ? 100 : 80,
          child: TextField(
            controller: _controller,
            keyboardType: widget.allowDecimals
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            inputFormatters: [
              if (!widget.allowDecimals)
                FilteringTextInputFormatter.digitsOnly,
              if (widget.allowDecimals)
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              suffix: widget.suffix != null
                  ? Text(
                      widget.suffix!,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    )
                  : null,
            ),
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.right,
            onChanged: (text) {
              _isEditingText = true;
              _onTextChanged(text);
            },
            onEditingComplete: () {
              _isEditingText = false;
              // 편집 완료 시 값 정리
              if (_controller.text.isEmpty) {
                _controller.text = widget.value.toInt().toString();
              }
            },
          ),
        ),
      ],
    );
  }
}
