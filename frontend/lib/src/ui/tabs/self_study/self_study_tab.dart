import 'package:flutter/material.dart';

import '../../../models/nest_models.dart';
import '../../../services/self_study_planner.dart';
import '../../../state/nest_controller.dart';
import '../../nest_theme.dart';
import '../../widgets/nest_empty_state.dart';
import '../../widgets/search_select_field.dart';
import 'self_study_sheet.dart';
import 'supervision_schedule_view.dart';

/// 공과(수업외 자습) 시간표 — 관리자용.
///
/// 수업 시간표의 공강을 자동 계산해 반별 자습 슬롯을 배치하고, 방/감독 지정과
/// 명단(반 전체 자동 포함, 개별 제외)을 편집한 뒤 출석부로 내보낸다.
class SelfStudyTab extends StatefulWidget {
  const SelfStudyTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<SelfStudyTab> createState() => _SelfStudyTabState();
}

class _SelfStudyTabState extends State<SelfStudyTab> {
  static const _dayOrder = [1, 2, 3, 4, 5, 6, 0]; // 월~일

  NestController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.isAdminLike) {
          return const NestEmptyState(
            icon: Icons.lock_outline,
            title: '관리자 전용 기능입니다',
            subtitle: '자습 시간표는 관리자/스태프만 편집할 수 있습니다.',
          );
        }
        if (controller.selectedTerm == null) {
          return const NestEmptyState(
            icon: Icons.event_note_outlined,
            title: '학기를 먼저 선택하세요',
            subtitle: '자습 시간표는 학기의 수업 시간표를 기준으로 만들어집니다.',
          );
        }

        final plan = controller.selectedSelfStudyPlan;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPlanBar(context),
            const SizedBox(height: 12),
            if (plan == null)
              NestEmptyState(
                icon: Icons.menu_book_outlined,
                title: '자습 계획이 없습니다',
                subtitle: '오전 등 지정한 시간대의 공강을 자습으로 채우는 계획을 만들어 보세요.',
                actionLabel: '자습 계획 만들기',
                onAction: () => _openPlanDialog(),
              )
            else ...[
              _buildConfigCard(context, plan),
              const SizedBox(height: 12),
              _buildSupervisorSection(context),
              ..._buildSlotSections(context, plan),
            ],
          ],
        );
      },
    );
  }

  // ── 계획 선택 바 ──
  Widget _buildPlanBar(BuildContext context) {
    final plans = controller.selfStudyPlans;
    return _card(
      child: Row(
        children: [
          const Icon(Icons.menu_book_outlined, color: NestColors.deepWood),
          const SizedBox(width: 10),
          Expanded(
            child: plans.isEmpty
                ? Text(
                    '자습 계획',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: controller.selectedSelfStudyPlan?.id,
                      items: [
                        for (final p in plans)
                          DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                      onChanged: (id) => controller.selectSelfStudyPlan(id),
                    ),
                  ),
          ),
          if (controller.selectedSelfStudyPlan != null) ...[
            IconButton(
              tooltip: '계획 삭제',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _confirmDeletePlan(controller.selectedSelfStudyPlan!),
            ),
          ],
          FilledButton.tonalIcon(
            onPressed: () => _openPlanDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('새 계획'),
          ),
        ],
      ),
    );
  }

  // ── 설정 요약 + 액션 ──
  Widget _buildConfigCard(BuildContext context, SelfStudyPlan plan) {
    final days = (plan.days.toList()
      ..sort((a, b) => (a == 0 ? 7 : a).compareTo(b == 0 ? 7 : b)));
    final daysLabel =
        days.map((d) => weekdayLabel(d)).join('·');
    final windowLabel =
        '${humanTimeLabel(minutesFromTime(plan.windowStart))}~'
        '${humanTimeLabel(minutesFromTime(plan.windowEnd))}';
    final periodLabel = (plan.periodStart != null && plan.periodEnd != null)
        ? '${_fmtDate(plan.periodStart!)} ~ ${_fmtDate(plan.periodEnd!)}'
        : '학기 기간';
    final slotCount = controller.selectedPlanSelfStudySlots.length;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(Icons.calendar_today_outlined, '요일 $daysLabel'),
              _pill(Icons.schedule_outlined, '시간대 $windowLabel'),
              _pill(Icons.date_range_outlined, periodLabel),
              _pill(Icons.timelapse_outlined, '최소 공강 ${plan.minGapMinutes}분'),
              _pill(Icons.grid_view_outlined, '자습 슬롯 $slotCount개'),
            ],
          ),
          if (plan.note.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              plan.note,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.7),
                  ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openPlanDialog(plan: plan),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('설정 수정'),
              ),
              FilledButton.icon(
                onPressed: _confirmRegenerate,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(slotCount == 0 ? '자동 배치' : '다시 배치'),
              ),
              OutlinedButton.icon(
                onPressed: slotCount == 0 ? null : _openSheet,
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('출석부'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 감독표 바로가기 ──
  Widget _buildSupervisorSection(BuildContext context) {
    final ids = controller.supervisorTeacherIdsInSelectedPlan;
    if (ids.isEmpty) return const SizedBox.shrink();
    final sorted = ids.toList()
      ..sort((a, b) =>
          controller.findTeacherName(a).compareTo(controller.findTeacherName(b)));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_ind_outlined,
                    size: 18, color: NestColors.clay),
                const SizedBox(width: 8),
                Text(
                  '감독표',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '교사를 누르면 그 교사의 감독 날짜·시간·장소가 나옵니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in sorted)
                  ActionChip(
                    avatar: const Icon(Icons.person_outline, size: 16),
                    label: Text(controller.findTeacherName(id)),
                    onPressed: () =>
                        showSupervisionSchedulePage(context, controller, id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 요일별 슬롯 섹션 ──
  List<Widget> _buildSlotSections(BuildContext context, SelfStudyPlan plan) {
    final slots = controller.selectedPlanSelfStudySlots;
    if (slots.isEmpty) {
      return [
        _card(
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: NestColors.clay),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '아직 배치된 자습 슬롯이 없습니다. 위의 "자동 배치"를 누르면 '
                  '수업 시간표의 공강을 계산해 반별 자습을 만들어 줍니다.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    final byDay = <int, List<SelfStudySlot>>{};
    for (final s in slots) {
      byDay.putIfAbsent(s.dayOfWeek, () => []).add(s);
    }

    final sections = <Widget>[];
    for (final day in _dayOrder) {
      final daySlots = byDay[day];
      if (daySlots == null || daySlots.isEmpty) continue;
      daySlots.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      sections.add(Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6, left: 4),
        child: Text(
          '${weekdayLabel(day)}요일',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ));
      for (final slot in daySlots) {
        sections.add(_buildSlotCard(context, slot));
        sections.add(const SizedBox(height: 8));
      }
    }
    return sections;
  }

  Widget _buildSlotCard(BuildContext context, SelfStudySlot slot) {
    final groupName = controller.findClassGroupName(slot.classGroupId);
    final roster = controller.rosterForSelfStudySlot(slot);
    final excludedCount =
        controller.excludedChildIdsForSelfStudySlot(slot.id).length;
    final supervisorName = slot.supervisorTeacherId == null
        ? null
        : controller.teacherProfiles
            .where((t) => t.id == slot.supervisorTeacherId)
            .map((t) => t.displayName)
            .firstOrNull;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: NestColors.mutedSage.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  gradeLabelForGroupName(groupName),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: NestColors.deepWood,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                groupName,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                rangeLabel(
                  minutesFromTime(slot.startTime),
                  minutesFromTime(slot.endTime),
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: NestColors.clay,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SelectFieldCard(
                  label: '자습 장소',
                  hintText: '방 지정',
                  icon: Icons.meeting_room_outlined,
                  enabled: true,
                  value: slot.room.trim().isEmpty ? null : slot.room,
                  onTap: () => _openRoomEditor(slot),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectFieldCard(
                  label: '감독',
                  hintText: '감독 지정',
                  icon: Icons.person_outline,
                  enabled: true,
                  value: supervisorName,
                  onTap: () => _openSupervisorPicker(slot),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRoster(context, slot, roster, excludedCount),
        ],
      ),
    );
  }

  Widget _buildRoster(
    BuildContext context,
    SelfStudySlot slot,
    List<ChildProfile> roster,
    int excludedCount,
  ) {
    final allMembers = controller.childrenForClassGroup(slot.classGroupId);
    final excluded = controller.excludedChildIdsForSelfStudySlot(slot.id);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(
          '자습 명단 ${roster.length}명'
          '${excludedCount > 0 ? ' · 제외 $excludedCount명' : ''}',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: allMembers.isEmpty
            ? const Text('이 반에 배정된 아동이 없습니다.',
                style: TextStyle(fontSize: 12))
            : null,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final child in allMembers)
                FilterChip(
                  label: Text(child.name),
                  selected: !excluded.contains(child.id),
                  showCheckmark: false,
                  selectedColor: NestColors.mutedSage.withValues(alpha: 0.28),
                  onSelected: (included) => _toggleExclusion(
                    slot,
                    child.id,
                    excluded: !included,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 액션 핸들러 ──
  Future<void> _toggleExclusion(
    SelfStudySlot slot,
    String childId, {
    required bool excluded,
  }) async {
    try {
      await controller.setSelfStudyExclusion(
        slotId: slot.id,
        childId: childId,
        excluded: excluded,
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _confirmRegenerate() async {
    final hasSlots = controller.selectedPlanSelfStudySlots.isNotEmpty;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('자습 자동 배치'),
        content: Text(
          hasSlots
              ? '수업 시간표의 공강을 다시 계산해 자습 슬롯을 새로 만듭니다.\n'
                  '방/감독/제외 명단은 시간이 같은 슬롯에 한해 최대한 유지됩니다.'
              : '수업 시간표의 공강을 계산해 반별 자습 슬롯을 만듭니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('배치'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await controller.regenerateSelfStudySlots();
    } catch (e) {
      _showError(e);
    }
  }

  void _openSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SelfStudySheetPage(controller: controller),
      ),
    );
  }

  Future<void> _openRoomEditor(SelfStudySlot slot) async {
    final controller0 = TextEditingController(text: slot.room);
    final rooms = controller.classrooms.map((c) => c.name).toList()..sort();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('자습 장소'),
          content: StatefulBuilder(
            builder: (ctx, setInner) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller0,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '방 이름',
                    hintText: '예: 중예배실, 304호',
                  ),
                ),
                if (rooms.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('등록된 강의실', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final r in rooms)
                        ActionChip(
                          label: Text(r),
                          onPressed: () =>
                              setInner(() => controller0.text = r),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller0.text),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
    controller0.dispose();
    if (result == null) return;
    try {
      await controller.updateSelfStudySlotDetails(
        slotId: slot.id,
        room: result,
        supervisorTeacherId: slot.supervisorTeacherId,
        label: slot.label,
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _openSupervisorPicker(SelfStudySlot slot) async {
    // "지정 안 함"은 빈 문자열 sentinel 로 두어, 취소(null 반환)와 구분한다.
    final options = <SelectSheetOption<String>>[
      const SelectSheetOption<String>(value: '', title: '지정 안 함'),
      for (final t in controller.teacherProfiles)
        SelectSheetOption<String>(
          value: t.id,
          title: t.displayName,
          subtitle: t.teacherType,
        ),
    ];
    final picked = await showSelectSheet<String>(
      context: context,
      title: '감독 선택',
      helpText: '이 자습 시간을 감독할 교사를 선택하세요.',
      options: options,
      currentValue: slot.supervisorTeacherId ?? '',
    );
    if (picked == null) return; // 취소
    final newId = picked.isEmpty ? null : picked;
    if (newId == slot.supervisorTeacherId) return;
    try {
      await controller.updateSelfStudySlotDetails(
        slotId: slot.id,
        room: slot.room,
        supervisorTeacherId: newId,
        label: slot.label,
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _confirmDeletePlan(SelfStudyPlan plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('자습 계획 삭제'),
        content: Text('"${plan.name}" 계획과 그 안의 모든 자습 슬롯을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NestColors.clay),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await controller.deleteSelfStudyPlan(plan.id);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _openPlanDialog({SelfStudyPlan? plan}) async {
    final nameController =
        TextEditingController(text: plan?.name ?? '공과 자습');
    final noteController = TextEditingController(text: plan?.note ?? '');
    final days = <int>{...(plan?.days ?? const [1, 2, 3, 4, 5])};
    var start = _timeOf(plan?.windowStart ?? '09:00', fallback: 9);
    var end = _timeOf(plan?.windowEnd ?? '12:00', fallback: 12);
    DateTime? periodStart = plan?.periodStart;
    DateTime? periodEnd = plan?.periodEnd;
    var minGap = plan?.minGapMinutes ?? 60;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setInner) {
            Widget dayChip(int day) => FilterChip(
                  label: Text(weekdayLabel(day)),
                  selected: days.contains(day),
                  onSelected: (v) => setInner(() {
                    if (v) {
                      days.add(day);
                    } else {
                      days.remove(day);
                    }
                  }),
                );

            Future<void> pickTime(bool isStart) async {
              final picked = await showTimePicker(
                context: ctx,
                initialTime: isStart ? start : end,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
              if (picked != null) {
                setInner(() {
                  if (isStart) {
                    start = picked;
                  } else {
                    end = picked;
                  }
                });
              }
            }

            Future<void> pickDate(bool isStart) async {
              final now = DateTime.now();
              final initial = (isStart ? periodStart : periodEnd) ?? now;
              final picked = await showDatePicker(
                context: ctx,
                initialDate: initial,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 2),
              );
              if (picked != null) {
                setInner(() {
                  if (isStart) {
                    periodStart = picked;
                  } else {
                    periodEnd = picked;
                  }
                });
              }
            }

            return AlertDialog(
              title: Text(plan == null ? '새 자습 계획' : '자습 계획 수정'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '계획 이름'),
                    ),
                    const SizedBox(height: 14),
                    const Text('채울 요일', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [for (final d in _dayOrder) dayChip(d)],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _dialogField(
                            '시작',
                            _fmtTime(start),
                            Icons.schedule,
                            () => pickTime(true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dialogField(
                            '종료',
                            _fmtTime(end),
                            Icons.schedule,
                            () => pickTime(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _dialogField(
                            '기간 시작',
                            periodStart == null ? '학기 기준' : _fmtDate(periodStart!),
                            Icons.date_range,
                            () => pickDate(true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dialogField(
                            '기간 종료',
                            periodEnd == null ? '학기 기준' : _fmtDate(periodEnd!),
                            Icons.date_range,
                            () => pickDate(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('최소 공강(이보다 짧은 빈 시간은 자습으로 만들지 않음)',
                        style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final g in [30, 60, 90, 120])
                          ChoiceChip(
                            label: Text('$g분'),
                            selected: minGap == g,
                            onSelected: (_) => setInner(() => minGap = g),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: '메모(선택)'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );

    final name = nameController.text;
    final note = noteController.text;
    nameController.dispose();
    noteController.dispose();
    if (saved != true) return;

    if (end.hour * 60 + end.minute <= start.hour * 60 + start.minute) {
      _showError(StateError('종료 시간이 시작 시간보다 늦어야 합니다.'));
      return;
    }

    try {
      final dayList = days.toList()..sort();
      if (plan == null) {
        await controller.createSelfStudyPlan(
          name: name,
          days: dayList,
          windowStart: _fmtTime(start),
          windowEnd: _fmtTime(end),
          periodStart: periodStart,
          periodEnd: periodEnd,
          minGapMinutes: minGap,
          note: note,
        );
      } else {
        await controller.updateSelfStudyPlan(
          planId: plan.id,
          name: name,
          days: dayList,
          windowStart: _fmtTime(start),
          windowEnd: _fmtTime(end),
          periodStart: periodStart,
          periodEnd: periodEnd,
          minGapMinutes: minGap,
          note: note,
        );
      }
    } catch (e) {
      _showError(e);
    }
  }

  // ── 작은 조각들 ──
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: child,
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: NestColors.creamyWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: NestColors.deepWood),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _dialogField(
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: NestColors.roseMist),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: NestColors.deepWood),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              NestColors.deepWood.withValues(alpha: 0.6))),
                  Text(value,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(Object e) {
    if (!mounted) return;
    final message = e is StateError ? e.message : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  TimeOfDay _timeOf(String value, {required int fallback}) {
    final min = minutesFromTime(value);
    if (min <= 0 && !value.startsWith('00')) {
      return TimeOfDay(hour: fallback, minute: 0);
    }
    return TimeOfDay(hour: min ~/ 60, minute: min % 60);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime d) => '${d.month}/${d.day}';
}
