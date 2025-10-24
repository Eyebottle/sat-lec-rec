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
      appBar: AppBar(
        title: const Text('녹화 스케줄 관리'),
        actions: [
          // 다음 예약 정보 표시
          _buildNextScheduleInfo(),
        ],
      ),
      body: _buildScheduleList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddScheduleDialog,
        icon: const Icon(Icons.add),
        label: const Text('스케줄 추가'),
      ),
    );
  }

  /// 다음 예약 정보 위젯
  Widget _buildNextScheduleInfo() {
    final next = _scheduleService.getNextSchedule();

    if (next == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          '예약 없음',
          style: TextStyle(fontSize: 14),
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
          const Text(
            '다음 예약',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
          ),
          const SizedBox(height: 2),
          Text(
            schedule.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Text(
            remainingText,
            style: const TextStyle(fontSize: 12),
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
            Icon(
              Icons.calendar_month,
              size: 64,
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '등록된 스케줄이 없습니다',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
            ),
            const SizedBox(height: 8),
            const Text('하단 버튼으로 스케줄을 추가하세요'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: schedules.length,
      padding: const EdgeInsets.all(16.0),
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        return _buildScheduleCard(schedule);
      },
    );
  }

  /// 스케줄 카드 위젯
  Widget _buildScheduleCard(RecordingSchedule schedule) {
    final nextExecution = schedule.getNextExecutionTime();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          schedule.isEnabled ? Icons.alarm_on : Icons.alarm_off,
          color: schedule.isEnabled ? Colors.green : Colors.grey,
          size: 32,
        ),
        title: Text(
          schedule.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${schedule.dayOfWeekName} ${schedule.startTimeFormatted} (${schedule.durationMinutes}분)'),
            const SizedBox(height: 2),
            if (schedule.isEnabled)
              Text(
                '다음 실행: ${_formatDateTime(nextExecution)}',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 활성화/비활성화 스위치
            Switch(
              value: schedule.isEnabled,
              onChanged: (value) async {
                await _scheduleService.toggleSchedule(schedule.id);
                setState(() {});
              },
            ),
            // 편집 버튼
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditScheduleDialog(schedule),
            ),
            // 삭제 버튼
            IconButton(
              icon: const Icon(Icons.delete),
              color: Colors.red,
              onPressed: () => _confirmDeleteSchedule(schedule),
            ),
          ],
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
    int selectedDayOfWeek = existingSchedule?.dayOfWeek ?? 6; // 기본: 토요일
    TimeOfDay selectedTime = existingSchedule?.startTime ?? const TimeOfDay(hour: 10, minute: 0);
    int durationMinutes = existingSchedule?.durationMinutes ?? 120;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? '스케줄 편집' : '스케줄 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 스케줄 이름
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '스케줄 이름',
                    hintText: '예: 토요일 오전 강의',
                  ),
                ),
                const SizedBox(height: 16),

                // 요일 선택
                const Text('요일', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (int i = 0; i < 7; i++)
                      ChoiceChip(
                        label: Text(_getDayName(i)),
                        selected: selectedDayOfWeek == i,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() {
                              selectedDayOfWeek = i;
                            });
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // 시작 시각 선택
                const Text('시작 시각', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setDialogState(() {
                        selectedTime = time;
                      });
                    }
                  },
                  child: Text(
                    '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 16),

                // 녹화 시간
                const Text('녹화 시간 (분)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Slider(
                  value: durationMinutes.toDouble(),
                  min: 30,
                  max: 300,
                  divisions: 27,
                  label: '$durationMinutes분',
                  onChanged: (value) {
                    setDialogState(() {
                      durationMinutes = value.toInt();
                    });
                  },
                ),
                Text('$durationMinutes분 (${(durationMinutes / 60).toStringAsFixed(1)}시간)'),
                const SizedBox(height: 16),

                // Zoom 링크
                TextField(
                  controller: zoomLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Zoom 링크',
                    hintText: 'https://zoom.us/j/...',
                  ),
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
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

                // 스케줄 생성/업데이트
                final schedule = RecordingSchedule(
                  id: existingSchedule?.id ?? const Uuid().v4(),
                  name: nameController.text.trim(),
                  dayOfWeek: selectedDayOfWeek,
                  startTime: selectedTime,
                  durationMinutes: durationMinutes,
                  zoomLink: zoomLinkController.text.trim(),
                  isEnabled: existingSchedule?.isEnabled ?? true,
                  createdAt: existingSchedule?.createdAt,
                );

                try {
                  if (isEdit) {
                    await _scheduleService.updateSchedule(schedule);
                  } else {
                    await _scheduleService.addSchedule(schedule);
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEdit ? '스케줄 수정 완료' : '스케줄 추가 완료')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('오류 발생: $e')),
                    );
                  }
                }
              },
              child: Text(isEdit ? '수정' : '추가'),
            ),
          ],
        ),
      ),
    );
  }

  /// 스케줄 삭제 확인 다이얼로그
  void _confirmDeleteSchedule(RecordingSchedule schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('스케줄 삭제'),
        content: Text('"${schedule.name}" 스케줄을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _scheduleService.deleteSchedule(schedule.id);
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('스케줄 삭제 완료')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// 요일 이름 반환
  String _getDayName(int dayOfWeek) {
    const days = ['일', '월', '화', '수', '목', '금', '토'];
    return days[dayOfWeek % 7];
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
