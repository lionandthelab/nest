import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../services/schedule_occurrence.dart';
import '../../services/schedule_overlap.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import 'nest_motion.dart';

class PersonalEventDraft {
  const PersonalEventDraft({
    required this.title,
    required this.notes,
    required this.startsAt,
    required this.endsAt,
    required this.conflictPolicy,
  });

  final String title;
  final String notes;
  final DateTime startsAt;
  final DateTime endsAt;
  final String conflictPolicy;
}

Future<void> showPersonalEventSheet({
  required BuildContext context,
  required NestController controller,
  required String childId,
  PersonalEvent? event,
  DateTime? initialStart,
  DateTime? initialEnd,
  List<ResolvedOccurrence> overlappingClasses = const [],
}) async {
  final draft = await showNestSheet<PersonalEventDraft>(
    context: context,
    builder: (sheetContext) => PersonalEventSheet(
      event: event,
      initialStart: initialStart,
      initialEnd: initialEnd,
      overlappingClasses: overlappingClasses,
      courseNameOf: controller.findCourseName,
    ),
  );
  if (draft == null || !context.mounted) return;

  try {
    if (event == null) {
      await controller.createPersonalEvent(
        childId: childId,
        title: draft.title,
        notes: draft.notes,
        startsAt: draft.startsAt,
        endsAt: draft.endsAt,
        conflictPolicy: draft.conflictPolicy,
      );
    } else {
      await controller.updatePersonalEvent(
        eventId: event.id,
        title: draft.title,
        notes: draft.notes,
        startsAt: draft.startsAt,
        endsAt: draft.endsAt,
        conflictPolicy: draft.conflictPolicy,
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(controller.statusMessage)),
    );
  }
}

class PersonalEventSheet extends StatefulWidget {
  const PersonalEventSheet({
    super.key,
    this.event,
    this.initialStart,
    this.initialEnd,
    this.overlappingClasses = const [],
    required this.courseNameOf,
  });

  final PersonalEvent? event;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final List<ResolvedOccurrence> overlappingClasses;
  final String Function(String courseId) courseNameOf;

  @override
  State<PersonalEventSheet> createState() => _PersonalEventSheetState();
}

class _PersonalEventSheetState extends State<PersonalEventSheet> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late DateTime _start;
  late DateTime _end;
  late String _policy;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final fallbackStart = widget.initialStart ??
        DateTime.now().add(const Duration(minutes: 30));
    final alignedStart = DateTime(
      fallbackStart.year,
      fallbackStart.month,
      fallbackStart.day,
      fallbackStart.hour,
      fallbackStart.minute,
    );
    _start = event?.startsAt ?? alignedStart;
    _end = event?.endsAt ??
        widget.initialEnd ??
        alignedStart.add(const Duration(hours: 1));
    _title = TextEditingController(text: event?.title ?? '');
    _notes = TextEditingController(text: event?.notes ?? '');
    _title.addListener(() => setState(() {}));
    _policy = event?.conflictPolicy ?? 'KEEP_BOTH';
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
      helpText: '날짜',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked == null || !mounted) return;
    setState(() {
      final duration = _end.difference(_start);
      _start = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _start.hour,
        _start.minute,
      );
      _end = _start.add(duration);
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      cancelText: '취소',
      confirmText: '확인',
      helpText: isStart ? '시작 시각' : '종료 시각',
    );
    if (picked == null || !mounted) return;
    setState(() {
      final next = DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      );
      if (isStart) {
        final duration = _end.difference(_start);
        _start = next;
        _end = _start.add(duration.isNegative ? const Duration(hours: 1) : duration);
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      } else {
        _end = next.isAfter(_start)
            ? next
            : _start.add(const Duration(minutes: 30));
      }
    });
  }

  void _submit() {
    if (_title.text.trim().isEmpty) return;
    Navigator.of(context).pop(
      PersonalEventDraft(
        title: _title.text,
        notes: _notes.text,
        startsAt: _start,
        endsAt: _end,
        conflictPolicy: _policy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.event != null;
    final live = PersonalEvent(
      id: widget.event?.id ?? '',
      homeschoolId: '',
      ownerUserId: '',
      childId: '',
      title: _title.text,
      startsAt: _start,
      endsAt: _end,
      conflictPolicy: _policy,
    );
    final overlaps = classesOverlappingPersonal(
      event: live,
      classes: widget.overlappingClasses,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit ? '개인 일정 수정' : '개인 일정 추가',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              autofocus: !isEdit,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '예: 피아노, 병원, 가족 약속',
                prefixIcon: Icon(Icons.event_available_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('날짜'),
              subtitle: Text(DateFormat('yyyy년 M월 d일 (E)', 'ko').format(_start)),
              onTap: _pickDate,
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('시작'),
                    subtitle: Text(DateFormat('a h:mm', 'ko').format(_start)),
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('종료'),
                    subtitle: Text(DateFormat('a h:mm', 'ko').format(_end)),
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            if (overlaps.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NestColors.roseMist.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '학기 수업과 ${overlaps.length}개가 겹칩니다',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...overlaps.map(
                      (row) => Text(
                        '· ${widget.courseNameOf(row.session.courseId)} '
                        '${DateFormat('M/d HH:mm').format(nestDateTimeOn(row.date, row.slot.startTime))}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'KEEP_BOTH',
                    label: Text('둘 다 보기'),
                  ),
                  ButtonSegment(
                    value: 'PRIORITIZE_PERSONAL',
                    label: Text('개인 우선'),
                  ),
                ],
                selected: {_policy},
                showSelectedIcon: false,
                onSelectionChanged: (values) =>
                    setState(() => _policy = values.first),
              ),
              const SizedBox(height: 6),
              Text(
                _policy == 'PRIORITIZE_PERSONAL'
                    ? '겹치는 수업 칸은 흐리게 두고, 이 일정을 먼저 보여 줍니다. 공식 결석 신고는 따로 해야 합니다.'
                    : '수업과 개인 일정을 한 칸에 같이 보여 줍니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.65),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _title.text.trim().isEmpty ? null : _submit,
                child: Text(isEdit ? '수정 저장' : '일정 추가'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
