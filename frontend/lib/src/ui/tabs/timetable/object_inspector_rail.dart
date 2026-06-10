import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/nest_models.dart';
import '../../../state/nest_controller.dart';
import '../../nest_theme.dart';

enum _InspectKind { classGroup, teacher, family }

/// A STRICTLY READ-ONLY relationship inspector ("오브젝트 한눈에 관리").
///
/// Lets the admin pick a 반 / 선생 / 가정 and view its relationships
/// (enrolled students, placed sessions, assigned teachers, guardians, etc.).
/// Reads [NestController] collections + helpers only; never mutates.
class ObjectInspectorRail extends StatefulWidget {
  const ObjectInspectorRail({
    super.key,
    required this.controller,
    this.initialClassGroupId,
  });

  final NestController controller;
  final String? initialClassGroupId;

  @override
  State<ObjectInspectorRail> createState() => _ObjectInspectorRailState();
}

class _ObjectInspectorRailState extends State<ObjectInspectorRail> {
  _InspectKind _kind = _InspectKind.classGroup;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialClassGroupId ??
        widget.controller.selectedClassGroupId;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final options = _optionsForKind(controller, _kind);

    // Keep the selection valid if collections changed underneath us.
    final currentValue =
        options.any((o) => o.id == _selectedId) ? _selectedId : null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.travel_explore_outlined,
                        size: 20, color: NestColors.dustyRose),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '오브젝트 한눈에 관리',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SegmentedButton<_InspectKind>(
                  segments: const [
                    ButtonSegment(
                      value: _InspectKind.classGroup,
                      label: Text('반'),
                      icon: Icon(Icons.groups_2_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: _InspectKind.teacher,
                      label: Text('선생'),
                      icon: Icon(Icons.person_outline, size: 16),
                    ),
                    ButtonSegment(
                      value: _InspectKind.family,
                      label: Text('가정'),
                      icon: Icon(Icons.family_restroom, size: 16),
                    ),
                  ],
                  selected: {_kind},
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  onSelectionChanged: (values) {
                    if (values.isEmpty) return;
                    setState(() {
                      _kind = values.first;
                      // Reset to first option of the new kind.
                      final next = _optionsForKind(controller, _kind);
                      _selectedId = next.isEmpty ? null : next.first.id;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _buildEntityDropdown(options, currentValue),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: currentValue == null
                  ? _emptyHint(context)
                  : _buildBody(controller, currentValue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntityDropdown(
    List<_InspectOption> options,
    String? currentValue,
  ) {
    return DropdownButtonFormField<String?>(
      initialValue: currentValue,
      isExpanded: true,
      isDense: true,
      decoration: InputDecoration(
        labelText: _kindLabel(_kind),
        isDense: true,
      ),
      items: [
        if (options.isEmpty)
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('항목 없음'),
          )
        else
          ...options.map(
            (o) => DropdownMenuItem<String?>(
              value: o.id,
              child: Text(o.label, overflow: TextOverflow.ellipsis),
            ),
          ),
      ],
      onChanged: options.isEmpty
          ? null
          : (value) => setState(() => _selectedId = value),
    );
  }

  List<_InspectOption> _optionsForKind(
    NestController controller,
    _InspectKind kind,
  ) {
    switch (kind) {
      case _InspectKind.classGroup:
        final groups = controller.classGroups.toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return groups.map((g) => _InspectOption(g.id, g.name)).toList();
      case _InspectKind.teacher:
        final teachers = controller.teacherProfiles.toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        return teachers
            .map((t) => _InspectOption(t.id, t.displayName))
            .toList();
      case _InspectKind.family:
        final families = controller.families.toList()
          ..sort((a, b) => a.familyName.compareTo(b.familyName));
        return families
            .map((f) => _InspectOption(f.id, f.familyName))
            .toList();
    }
  }

  Widget _buildBody(NestController controller, String id) {
    switch (_kind) {
      case _InspectKind.classGroup:
        return _buildClassBody(controller, id);
      case _InspectKind.teacher:
        return _buildTeacherBody(controller, id);
      case _InspectKind.family:
        return _buildFamilyBody(controller, id);
    }
  }

  // ---------------------------------------------------------------------------
  // 반 (class)
  // ---------------------------------------------------------------------------

  Widget _buildClassBody(NestController controller, String classGroupId) {
    final sessions = controller.allTermSessions
        .where((s) => s.classGroupId == classGroupId)
        .toList()
      ..sort((a, b) => _slotSortKey(controller, a.timeSlotId)
          .compareTo(_slotSortKey(controller, b.timeSlotId)));

    // 등록 학생 grouped by 가정.
    final students = controller.childrenForClassGroup(classGroupId);
    final byFamily = <String, List<ChildProfile>>{};
    for (final child in students) {
      byFamily.putIfAbsent(child.familyId, () => []).add(child);
    }

    // 배정 교사 요약: distinct teachers across the class's sessions + counts.
    final teacherCounts = <String, int>{};
    final sessionIds = sessions.map((s) => s.id).toSet();
    for (final row in controller.allTermSessionTeacherAssignments) {
      if (!sessionIds.contains(row.classSessionId)) continue;
      teacherCounts.update(
        row.teacherProfileId,
        (v) => v + 1,
        ifAbsent: () => 1,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, '개요'),
        _kvRow(context, '수업', '${sessions.length}개'),
        _kvRow(context, '등록 학생', '${students.length}명'),
        const SizedBox(height: 12),
        _sectionTitle(context, '등록 학생 (가정별)'),
        if (byFamily.isEmpty)
          _mutedText(context, '등록된 학생이 없습니다.')
        else
          ...byFamily.entries.map((entry) {
            final familyName = _familyName(controller, entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    familyName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: NestColors.clay,
                    ),
                  ),
                  Text(
                    entry.value.map((c) => c.name).join(', '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 12),
        _sectionTitle(context, '배치된 세션'),
        if (sessions.isEmpty)
          _mutedText(context, '배치된 세션이 없습니다.')
        else
          ...sessions.map((s) => _sessionTile(controller, s)),
        const SizedBox(height: 12),
        _sectionTitle(context, '배정 교사'),
        if (teacherCounts.isEmpty)
          _mutedText(context, '배정된 교사가 없습니다.')
        else
          ...(teacherCounts.entries.toList()
                ..sort((a, b) => controller
                    .findTeacherName(a.key)
                    .compareTo(controller.findTeacherName(b.key))))
              .map(
                (entry) => _kvRow(
                  context,
                  controller.findTeacherName(entry.key),
                  '${entry.value}개 수업',
                ),
              ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 선생 (teacher)
  // ---------------------------------------------------------------------------

  Widget _buildTeacherBody(NestController controller, String teacherId) {
    final sessionIds = controller.allTermSessionTeacherAssignments
        .where((row) => row.teacherProfileId == teacherId)
        .map((row) => row.classSessionId)
        .toSet();
    final sessions = controller.allTermSessions
        .where((s) => sessionIds.contains(s.id))
        .toList()
      ..sort((a, b) => _slotSortKey(controller, a.timeSlotId)
          .compareTo(_slotSortKey(controller, b.timeSlotId)));

    final blocks = controller.memberUnavailabilityBlocks
        .where((b) => b.ownerKind == 'TEACHER_PROFILE' && b.ownerId == teacherId)
        .toList()
      ..sort((a, b) {
        final day = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (day != 0) return day;
        return a.startTime.compareTo(b.startTime);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, '개요'),
        _kvRow(context, '주간 수업', '${sessions.length}개'),
        _kvRow(context, '불가 시간', '${blocks.length}개'),
        const SizedBox(height: 12),
        _sectionTitle(context, '담당 세션'),
        if (sessions.isEmpty)
          _mutedText(context, '담당 세션이 없습니다.')
        else
          ...sessions.map((s) {
            final collides = _teacherSessionCollides(controller, teacherId, s);
            return _sessionTile(controller, s, showClass: true, warn: collides);
          }),
        const SizedBox(height: 12),
        _sectionTitle(context, '불가 시간'),
        if (blocks.isEmpty)
          _mutedText(context, '등록된 불가 시간이 없습니다.')
        else
          ...blocks.map(
            (b) => _kvRow(
              context,
              '${_dayLabel(b.dayOfWeek)}요일',
              '${_shortTime(b.startTime)}-${_shortTime(b.endTime)}',
            ),
          ),
      ],
    );
  }

  /// True when [session] shares its slot with another of the teacher's
  /// sessions that has a DIFFERENT course.
  bool _teacherSessionCollides(
    NestController controller,
    String teacherId,
    ClassSession session,
  ) {
    final teacherSessionIds = controller.allTermSessionTeacherAssignments
        .where((row) => row.teacherProfileId == teacherId)
        .map((row) => row.classSessionId)
        .toSet();
    for (final other in controller.allTermSessions) {
      if (other.id == session.id) continue;
      if (!teacherSessionIds.contains(other.id)) continue;
      if (other.timeSlotId != session.timeSlotId) continue;
      if (other.courseId != session.courseId) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // 가정 (family)
  // ---------------------------------------------------------------------------

  Widget _buildFamilyBody(NestController controller, String familyId) {
    final guardianIds =
        controller.familyGuardianUserIdsByFamily[familyId] ?? const [];
    final childrenRows = controller.childrenForFamily(familyId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, '보호자'),
        if (guardianIds.isEmpty)
          _mutedText(context, '등록된 보호자가 없습니다.')
        else
          ...guardianIds.map(
            (userId) => _bulletText(
              context,
              controller.findMemberDisplayName(userId),
            ),
          ),
        const SizedBox(height: 12),
        _sectionTitle(context, '자녀'),
        if (childrenRows.isEmpty)
          _mutedText(context, '등록된 자녀가 없습니다.')
        else
          ...childrenRows.map((child) {
            final classes = controller.classGroupsForChild(child.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    classes.isEmpty
                        ? '반 배정 없음'
                        : '반 배정: ${classes.map((c) => c.name).join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Shared rendering helpers
  // ---------------------------------------------------------------------------

  Widget _sessionTile(
    NestController controller,
    ClassSession session, {
    bool showClass = false,
    bool warn = false,
  }) {
    final courseName = controller.findCourseName(session.courseId);
    final slotLabel = _slotLabel(controller, session.timeSlotId);
    final room = (session.location ?? '').trim();
    final teacherNames = controller.allTermSessionTeacherAssignments
        .where((row) => row.classSessionId == session.id)
        .map((row) => controller.findTeacherName(row.teacherProfileId))
        .toList();

    final detailParts = <String>[slotLabel];
    if (teacherNames.isNotEmpty) detailParts.add(teacherNames.join(', '));
    if (room.isNotEmpty) detailParts.add('📍$room');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: warn ? Colors.red.shade50 : NestColors.creamyWhite,
        border: Border.all(
          color: warn ? Colors.red.shade400 : NestColors.roseMist,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (warn) ...[
                Text(
                  '⚠',
                  style: TextStyle(color: Colors.red.shade400),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  showClass
                      ? '${controller.findClassGroupName(session.classGroupId)} · $courseName'
                      : courseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            detailParts.join(' · '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: NestColors.deepWood,
        ),
      ),
    );
  }

  Widget _kvRow(BuildContext context, String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              key,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletText(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        '· $text',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _mutedText(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: NestColors.deepWood.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _emptyHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '항목을 선택하면 상세 정보가 표시됩니다.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: NestColors.deepWood.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  String _familyName(NestController controller, String familyId) {
    return controller.families
            .where((f) => f.id == familyId)
            .map((f) => f.familyName)
            .firstOrNull ??
        '미상 가정';
  }

  String _slotLabel(NestController controller, String slotId) {
    final slot = controller.findTimeSlot(slotId);
    if (slot == null) return slotId;
    return '${_dayLabel(slot.dayOfWeek)} ${_shortTime(slot.startTime)}-${_shortTime(slot.endTime)}';
  }

  /// Sortable key so sessions list in day/time order.
  String _slotSortKey(NestController controller, String slotId) {
    final slot = controller.findTimeSlot(slotId);
    if (slot == null) return slotId;
    return '${slot.dayOfWeek}${slot.startTime}';
  }

  String _kindLabel(_InspectKind kind) {
    switch (kind) {
      case _InspectKind.classGroup:
        return '반 선택';
      case _InspectKind.teacher:
        return '선생 선택';
      case _InspectKind.family:
        return '가정 선택';
    }
  }
}

class _InspectOption {
  const _InspectOption(this.id, this.label);

  final String id;
  final String label;
}

String _dayLabel(int dayOfWeek) {
  const labels = <int, String>{
    0: '일',
    1: '월',
    2: '화',
    3: '수',
    4: '목',
    5: '금',
    6: '토',
  };
  return labels[dayOfWeek] ?? '$dayOfWeek';
}

String _shortTime(String value) {
  final parsed = DateFormat('HH:mm:ss').tryParse(value);
  if (parsed == null) {
    final fallback = DateFormat('HH:mm').tryParse(value);
    return fallback == null ? value : DateFormat('HH:mm').format(fallback);
  }
  return DateFormat('HH:mm').format(parsed);
}
