import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/nest_models.dart';
import '../../../state/nest_controller.dart';
import '../../nest_theme.dart';
import 'room_normalizer.dart';

/// "빈 강의실 찾기" — pick a day + period and see which classrooms are free.
///
/// Mirrors the school timetable program's "수업 없는 교사" workflow, but for
/// rooms: select 요일 → select 교시 → the board splits every known room into
/// 빈 강의실 (free) and 사용 중 (occupied, with the class/course using it).
///
/// Read-only. The room universe is the union of registered classrooms and any
/// free-text session locations, deduped by [RoomNormalizer] (the same rule the
/// whole-school 장소 axis uses), so the two views stay consistent.
class EmptyRoomFinder extends StatefulWidget {
  const EmptyRoomFinder({super.key, required this.controller});

  final NestController controller;

  @override
  State<EmptyRoomFinder> createState() => _EmptyRoomFinderState();
}

class _EmptyRoomFinderState extends State<EmptyRoomFinder> {
  int? _selectedDay;
  String? _selectedSlotId;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    final slots = controller.timeSlots.toList()
      ..sort((a, b) {
        final day = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (day != 0) return day;
        return a.startTime.compareTo(b.startTime);
      });

    if (slots.isEmpty) {
      return _note(context, '시간 슬롯이 없습니다. 교시 설정을 먼저 진행하세요.');
    }

    final days = (slots.map((s) => s.dayOfWeek).toSet().toList())..sort();

    // Resolve the effective selection defensively (term switches can leave a
    // stale day/slot); fall back to the first available.
    final effectiveDay = days.contains(_selectedDay) ? _selectedDay! : days.first;
    final daySlots = slots.where((s) => s.dayOfWeek == effectiveDay).toList();
    final effectiveSlotId =
        daySlots.any((s) => s.id == _selectedSlotId)
            ? _selectedSlotId!
            : daySlots.first.id;
    final selectedSlot =
        daySlots.firstWhere((s) => s.id == effectiveSlotId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '요일과 교시를 선택하면 그 시간에 비어 있는 강의실을 보여줍니다.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 12),
        _fieldLabel(context, '요일'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: days
              .map(
                (day) => ChoiceChip(
                  label: Text('${_dayLabel(day)}요일'),
                  selected: day == effectiveDay,
                  onSelected: (_) => setState(() {
                    _selectedDay = day;
                    _selectedSlotId = null; // re-default the period for the day
                  }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        _fieldLabel(context, '교시'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: daySlots
              .map(
                (slot) => ChoiceChip(
                  label: Text(_slotLabel(slot)),
                  selected: slot.id == effectiveSlotId,
                  onSelected: (_) =>
                      setState(() => _selectedSlotId = slot.id),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        _buildResult(context, controller, selectedSlot),
      ],
    );
  }

  Widget _buildResult(
    BuildContext context,
    NestController controller,
    TimeSlot slot,
  ) {
    // Room universe: registered classrooms ∪ non-empty session locations,
    // deduped by canonical key, keeping the first display form encountered.
    final byCanonical = <String, String>{};
    for (final classroom in controller.classrooms) {
      final display = RoomNormalizer.normalize(classroom.name);
      if (display.isEmpty) continue;
      byCanonical.putIfAbsent(RoomNormalizer.canonical(display), () => display);
    }
    for (final session in controller.allTermSessions) {
      final display = RoomNormalizer.normalize(session.location ?? '');
      if (display.isEmpty) continue;
      byCanonical.putIfAbsent(RoomNormalizer.canonical(display), () => display);
    }

    if (byCanonical.isEmpty) {
      return _note(
        context,
        '등록된 강의실이 없습니다. 학기 설정에서 강의실을 먼저 등록하면 빈 강의실을 찾을 수 있습니다.',
      );
    }

    // Sessions occupying a named room at this slot, grouped by canonical room.
    final occupied = <String, List<ClassSession>>{};
    var unassignedCount = 0;
    for (final session in controller.allTermSessions) {
      if (session.timeSlotId != slot.id) continue;
      final canonical = RoomNormalizer.canonical(session.location ?? '');
      if (canonical.isEmpty) {
        unassignedCount++;
        continue;
      }
      occupied.putIfAbsent(canonical, () => <ClassSession>[]).add(session);
    }

    final emptyRooms = byCanonical.entries
        .where((e) => !occupied.containsKey(e.key))
        .map((e) => e.value)
        .toList()
      ..sort();
    final occupiedRooms = occupied.keys
        .map((key) => byCanonical[key] ?? key)
        .toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          '빈 강의실',
          emptyRooms.length,
          NestColors.mutedSage,
        ),
        const SizedBox(height: 8),
        if (emptyRooms.isEmpty)
          _note(context, '이 시간에는 비어 있는 강의실이 없습니다.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: emptyRooms
                .map((room) => _roomChip(context, room))
                .toList(),
          ),
        const SizedBox(height: 18),
        _sectionHeader(
          context,
          '사용 중',
          occupiedRooms.length,
          NestColors.clay,
        ),
        const SizedBox(height: 8),
        if (occupiedRooms.isEmpty)
          _note(context, '사용 중인 강의실이 없습니다.')
        else
          ...occupiedRooms.map((room) {
            final canonical = RoomNormalizer.canonical(room);
            final sessions = occupied[canonical] ?? const <ClassSession>[];
            return _occupiedRoomRow(context, controller, room, sessions);
          }),
        if (unassignedCount > 0) ...[
          const SizedBox(height: 12),
          _note(
            context,
            '장소가 지정되지 않은 수업 $unassignedCount개가 이 시간에 있습니다.',
          ),
        ],
      ],
    );
  }

  // ── Pieces ──

  Widget _fieldLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String title,
    int count,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.6),
              ),
        ),
      ],
    );
  }

  Widget _roomChip(BuildContext context, String room) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: NestColors.mutedSage.withValues(alpha: 0.18),
        border: Border.all(color: NestColors.mutedSage.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.meeting_room_outlined,
              size: 16, color: NestColors.mutedSage),
          const SizedBox(width: 6),
          Text(
            room,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _occupiedRoomRow(
    BuildContext context,
    NestController controller,
    String room,
    List<ClassSession> sessions,
  ) {
    final lines = sessions.map((s) {
      final course = controller.findCourseName(s.courseId);
      final className = controller.findClassGroupName(s.classGroupId);
      return className.isEmpty ? course : '$course · $className';
    }).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: NestColors.roseMist.withValues(alpha: 0.22),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.meeting_room, size: 16, color: NestColors.clay),
              const SizedBox(width: 6),
              Text(
                room,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Text(
                line,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.8),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _note(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: NestColors.creamyWhite,
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  String _slotLabel(TimeSlot slot) =>
      '${_hm(slot.startTime)}~${_hm(slot.endTime)}';

  String _hm(String value) {
    final parsed = DateFormat('HH:mm:ss').tryParse(value) ??
        DateFormat('HH:mm').tryParse(value);
    return parsed == null ? value : DateFormat('HH:mm').format(parsed);
  }

  String _dayLabel(int dayOfWeek) {
    const labels = <int, String>{
      0: '일', 1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토',
    };
    return labels[dayOfWeek] ?? '$dayOfWeek';
  }
}
