// lib/ui/screens/schedule_screen.dart
// 녹화 스케줄 관리 화면
//
// 목적: 예약 녹화 스케줄 CRUD UI 제공 (Phase 3.2.1)
// - 스케줄 목록 표시
// - 스케줄 추가/편집/삭제
// - 활성화/비활성화 토글
// - 다음 예약 시각 표시

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/recording_schedule.dart';
import '../../services/schedule_service.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_button.dart';
import '../style/app_colors.dart';
import '../style/app_typography.dart';

/// 스케줄 관리 화면
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ScheduleService _scheduleService = ScheduleService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          '녹화 스케줄 관리',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          // 다음 예약 정보 표시
          _buildNextScheduleInfo(),
        ],
      ),
      body: _buildScheduleList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddScheduleDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('스케줄 추가'),
      ),
    );
  }

  /// 다음 예약 정보 위젯
  Widget _buildNextScheduleInfo() {
    final next = _scheduleService.getNextSchedule();

    if (next == null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          '예약 없음',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      );
    }

    final schedule = next.schedule;
    final nextExecution = next.nextExecution;
    final remaining = nextExecution.difference(DateTime.now());

    String remainingText;
    if (remaining.inDays > 0) {
      remainingText = '${remaining.inDays}일 ${remaining.inHours % 24}시간';
    } else if (remaining.inHours > 0) {
      remainingText = '${remaining.inHours}시간 ${remaining.inMinutes % 60}분';
    } else {
      remainingText = '${remaining.inMinutes}분';
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '다음 예약',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          
          Text(
            schedule.name,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          Text(
            remainingText,
            style: const TextStyle(fontSize: 12, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  /// 스케줄 목록 위젯
  Widget _buildScheduleList() {
    final schedules = _scheduleService.schedules;

    if (schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 48,
                color: AppColors.neutral400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '등록된 스케줄이 없습니다',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '우측 하단 버튼을 눌러 새 스케줄을 추가하세요.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textDisabled),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: schedules.length,
      padding: const EdgeInsets.all(24.0),
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        return _buildScheduleCard(schedule);
      },
    );
  }

  /// 스케줄 카드 위젯
  Widget _buildScheduleCard(RecordingSchedule schedule) {
    final nextExecution = schedule.getNextExecutionTime();
    final isActive = schedule.isEnabled;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard.level1(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showEditScheduleDialog(schedule),
          child: Column(
            children: [
              // Header: Status, Name, Switch
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.neutral200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isActive ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
                        color: isActive ? AppColors.primary : AppColors.neutral500,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            schedule.name,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isActive ? AppColors.textPrimary : AppColors.textDisabled,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            // 1회성/반복 표시 추가
                            '${schedule.typeName} · ${schedule.scheduleDisplayName} ${schedule.startTimeFormatted}',
                            style: AppTypography.bodySmall.copyWith(
                              color: isActive ? AppColors.textSecondary : AppColors.textDisabled,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isActive,
                      activeColor: AppColors.primary,
                      activeTrackColor: AppColors.primaryContainer,
                      inactiveThumbColor: AppColors.neutral400,
                      inactiveTrackColor: AppColors.neutral200,
                      onChanged: (value) async {
                        await _scheduleService.toggleSchedule(schedule.id);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: AppColors.neutral200),

              // Footer: Next Execution, Duration, Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 14,
                      color: AppColors.neutral500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${schedule.durationMinutes}분 녹화',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.neutral600),
                    ),
                    const SizedBox(width: 12),
                    if (isActive) ...[
                      Container(width: 1, height: 12, color: AppColors.neutral300),
                      const SizedBox(width: 12),
                      Text(
                        '다음: ${_formatDateTime(nextExecution)}',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const Spacer(),
                    
                    // Delete Action
                    InkWell(
                      onTap: () => _confirmDeleteSchedule(schedule),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 스케줄 추가 다이얼로그
  void _showAddScheduleDialog() {
    _showScheduleDialog(null);
  }

  /// 스케줄 편집 다이얼로그
  void _showEditScheduleDialog(RecordingSchedule schedule) {
    _showScheduleDialog(schedule);
  }

  /// 스케줄 추가/편집 다이얼로그
  void _showScheduleDialog(RecordingSchedule? existingSchedule) {
    final isEdit = existingSchedule != null;

    // 폼 컨트롤러
    final nameController = TextEditingController(text: existingSchedule?.name ?? '');
    final zoomLinkController = TextEditingController(text: existingSchedule?.zoomLink ?? '');

    // 상태 변수
    ScheduleType selectedType = existingSchedule?.type ?? ScheduleType.weekly;
    int selectedDayOfWeek = existingSchedule?.dayOfWeek ?? 6; // 기본: 토요일
    DateTime? selectedDate = existingSchedule?.specificDate;
    TimeOfDay selectedTime = existingSchedule?.startTime ?? const TimeOfDay(hour: 10, minute: 0);
    int durationMinutes = existingSchedule?.durationMinutes ?? 120;

    // 1회성 기본 날짜 설정 (내일)
    if (selectedType == ScheduleType.oneTime && selectedDate == null) {
      selectedDate = DateTime.now().add(const Duration(days: 1));
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 550,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? '스케줄 편집' : '새 스케줄 추가',
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: AppColors.textSecondary,
                      splashRadius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. 기본 정보
                        _buildSectionLabel('기본 정보'),
                        TextField(
                          controller: nameController,
                          style: TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: '스케줄 이름 (예: 토요일 오전 강의)',
                            labelStyle: TextStyle(color: AppColors.textSecondary),
                            prefixIcon: Icon(Icons.label_outline, color: AppColors.neutral500),
                            filled: true,
                            fillColor: AppColors.neutral50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.neutral200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: zoomLinkController,
                          keyboardType: TextInputType.url,
                          style: TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Zoom 링크',
                            hintText: 'https://zoom.us/j/xxxxx?pwd=yyyyy',
                            helperText: '암호(pwd)가 포함된 전체 링크를 권장합니다.',
                            labelStyle: TextStyle(color: AppColors.textSecondary),
                            hintStyle: TextStyle(color: AppColors.textDisabled),
                            helperStyle: TextStyle(color: AppColors.textSecondary),
                            prefixIcon: Icon(Icons.link, color: AppColors.neutral500),
                            filled: true,
                            fillColor: AppColors.neutral50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.neutral200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // 2. 예약 방식 & 시간
                        _buildSectionLabel('시간 설정'),
                        
                        // Type Selector
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.neutral100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              _buildTypeOption(
                                title: '매주 반복',
                                isSelected: selectedType == ScheduleType.weekly,
                                onTap: () => setDialogState(() => selectedType = ScheduleType.weekly),
                              ),
                              _buildTypeOption(
                                title: '1회성 예약',
                                isSelected: selectedType == ScheduleType.oneTime,
                                onTap: () => setDialogState(() {
                                  selectedType = ScheduleType.oneTime;
                                  selectedDate ??= DateTime.now().add(const Duration(days: 1));
                                }),
                              ),
                            ],
                          ),
                        ),

                        if (selectedType == ScheduleType.weekly) ...[
                          Text('반복 요일', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          _buildDaySelector(
                            selectedDay: selectedDayOfWeek,
                            onChanged: (day) => setDialogState(() => selectedDayOfWeek = day),
                          ),
                        ] else ...[
                           Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('예약 날짜', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: selectedDate!,
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime.now().add(const Duration(days: 365)),
                                        );
                                        if (picked != null) {
                                          setDialogState(() => selectedDate = picked);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: AppColors.neutral300),
                                          borderRadius: BorderRadius.circular(12),
                                          color: AppColors.surface,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${selectedDate?.year}년 ${selectedDate?.month}월 ${selectedDate?.day}일',
                                              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            ),
                                            Icon(Icons.calendar_month, size: 18, color: AppColors.neutral500),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        const SizedBox(height: 20),

                        // 시작 시간
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('시작 시각', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: selectedTime,
                                    initialEntryMode: TimePickerEntryMode.input,
                                  );
                                  if (time != null) {
                                    setDialogState(() => selectedTime = time);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.neutral300),
                                    borderRadius: BorderRadius.circular(12),
                                    color: AppColors.surface,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.access_time, size: 18, color: AppColors.neutral500),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 32),

                        // 3. 녹화 시간 설정
                        _buildSectionLabel('녹화 시간'),
                        const SizedBox(height: 8),
                        _buildDurationSelector(
                          minutes: durationMinutes,
                          onChanged: (val) => setDialogState(() => durationMinutes = val),
                        ),

                        // 준비 시간 안내
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.info, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '녹화는 예약 시간 2~3분 전부터 준비를 시작합니다.\n'
                                  '실제 녹화 파일은 준비 완료 후 시작됩니다.',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.info,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.neutral600,
                      ),
                      child: const Text('취소'),
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      onPressed: () async {
                        // 유효성 검사
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('스케줄 이름을 입력하세요')),
                          );
                          return;
                        }

                        if (zoomLinkController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Zoom 링크를 입력하세요')),
                          );
                          return;
                        }

                         if (selectedType == ScheduleType.oneTime && selectedDate == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('날짜를 선택하세요')),
                          );
                          return;
                        }

                        // 스케줄 생성/업데이트
                        final schedule = RecordingSchedule(
                          id: existingSchedule?.id ?? const Uuid().v4(),
                          name: nameController.text.trim(),
                          type: selectedType,
                          dayOfWeek: selectedType == ScheduleType.weekly ? selectedDayOfWeek : null,
                          specificDate: selectedType == ScheduleType.oneTime ? selectedDate : null,
                          startTime: selectedTime,
                          durationMinutes: durationMinutes,
                          zoomLink: zoomLinkController.text.trim(),
                          isEnabled: existingSchedule?.isEnabled ?? true,
                          createdAt: existingSchedule?.createdAt,
                          lastExecutedAt: existingSchedule?.lastExecutedAt,
                        );

                        try {
                          if (isEdit) {
                            await _scheduleService.updateSchedule(schedule);
                          } else {
                            await _scheduleService.addSchedule(schedule);
                          }

                          if (context.mounted) {
                            Navigator.pop(context);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isEdit ? '스케줄 수정 완료' : '스케줄 추가 완료'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('오류 발생: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                      child: Text(isEdit ? '수정 저장' : '추가하기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 섹션 라벨
  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: AppTypography.titleSmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 예약 타입 옵션 버튼
  Widget _buildTypeOption({required String title, required bool isSelected, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  /// 요일 선택 위젯
  Widget _buildDaySelector({required int selectedDay, required Function(int) onChanged}) {
    const days = ['일', '월', '화', '수', '목', '금', '토'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final isSelected = selectedDay == index;
        final isSunday = index == 0;
        final isSaturday = index == 6;

        Color textColor = AppColors.textSecondary;
        if (isSunday) textColor = AppColors.error;
        if (isSaturday) textColor = AppColors.primary;
        if (isSelected) textColor = Colors.white;

        Color borderColor = AppColors.neutral300;
        if (isSelected) {
            borderColor = isSunday ? AppColors.error : (isSaturday ? AppColors.primary : AppColors.neutral800);
        }

        Color bgColor = Colors.transparent;
        if (isSelected) {
            bgColor = isSunday ? AppColors.error : (isSaturday ? AppColors.primary : AppColors.neutral800);
        }

        return InkWell(
          onTap: () => onChanged(index),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              days[index],
              style: TextStyle(
                color: textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 녹화 시간 선택 위젯
  Widget _buildDurationSelector({required int minutes, required Function(int) onChanged}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDurationChip(15, '15분', minutes, onChanged),
            _buildDurationChip(30, '30분', minutes, onChanged),
            _buildDurationChip(60, '1시간', minutes, onChanged),
            _buildDurationChip(90, '1.5시', minutes, onChanged),
            _buildDurationChip(120, '2시간', minutes, onChanged),
            _buildDurationChip(180, '3시간', minutes, onChanged),
          ],
        ),
        const SizedBox(height: 16),
        Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
             Text('${minutes}분', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
             Text(
               '약 ${(minutes / 60).toStringAsFixed(1)}시간',
               style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
             ),
           ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.neutral200,
            thumbColor: AppColors.primary,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            valueIndicatorColor: AppColors.primary,
          ),
          child: Slider(
            value: minutes.toDouble(),
            min: 15,
            max: 300,
            divisions: 57,
            label: '$minutes분',
            onChanged: (value) => onChanged(value.toInt()),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationChip(int value, String label, int current, Function(int) onChanged) {
    final isSelected = value == current;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neutral800 : AppColors.neutral100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.neutral800 : AppColors.neutral300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 스케줄 삭제 확인 다이얼로그
  void _confirmDeleteSchedule(RecordingSchedule schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('스케줄 삭제'),
        content: Text('"${schedule.name}" 스케줄을 정말 삭제하시겠습니까?', style: const TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          AppButton(
            onPressed: () async {
              await _scheduleService.deleteSchedule(schedule.id);
              if (context.mounted) {
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('스케줄 삭제 완료')),
                );
              }
            },
            backgroundColor: AppColors.error,
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// DateTime을 읽기 쉬운 형식으로 변환
  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);

    if (diff.inDays == 0 && dt.day == now.day) {
      return '오늘 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1 || (diff.inDays == 0 && dt.day == now.day + 1)) {
      return '내일 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}
