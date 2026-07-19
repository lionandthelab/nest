import 'package:flutter/material.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';

/// 관리자용 상단 고정 학기 네비게이터 바.
///
/// - 학기를 오늘 날짜 기준으로 지난/현재/예정으로 분류해 배지로 보여준다.
/// - 칩을 탭하거나 좌우 화살표로 학기를 옮겨다닐 수 있고, 선택한 학기 기준으로
///   모든 탭(학기 설정/시간표/자습)이 전환된다.
/// - `+ 예정 학기`로 다음 학기를 미리 만들고, 편집 아이콘으로 이름/기간/상태를
///   수정하거나 삭제한다.
/// - 지난 학기는 기본적으로 읽기 전용이며, 잠금 해제 버튼으로 편집을 허용한다.
class TermNavigatorBar extends StatelessWidget {
  const TermNavigatorBar({super.key, required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // 시간순(시작일 오름차순) 정렬 — 화살표 이동과 타임라인 표시 기준.
        final ordered = controller.terms.toList()
          ..sort(compareTermsByStartDate);

        final selectedId = controller.selectedTermId;
        final selectedIndex = ordered.indexWhere((t) => t.id == selectedId);
        final selected = selectedIndex >= 0 ? ordered[selectedIndex] : null;
        final busy = controller.isBusy;

        final canPrev = !busy && selectedIndex > 0;
        final canNext = !busy && selectedIndex >= 0 && selectedIndex < ordered.length - 1;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: NestColors.roseMist.withValues(alpha: 0.45),
            border: Border(
              bottom: BorderSide(color: NestColors.roseMist),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 좁은 폭(모바일)에서는 오버플로 방지를 위해 '학기' 라벨을 숨기고
              // 잠금 해제 컨트롤을 아이콘 전용으로 축약한다.
              final compact = constraints.maxWidth < 520;
              return Row(
                children: [
                  if (!compact) ...[
                    Icon(Icons.calendar_month_outlined,
                        size: 18, color: NestColors.clay),
                    const SizedBox(width: 6),
                    Text(
                      '학기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: NestColors.deepWood,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  _RoundIconButton(
                    icon: Icons.chevron_left,
                    tooltip: '이전 학기',
                    onPressed: canPrev
                        ? () =>
                            controller.changeTerm(ordered[selectedIndex - 1].id)
                        : null,
                  ),
              Expanded(
                child: ordered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '학기가 없습니다. 예정 학기를 추가하세요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: NestColors.deepWood.withValues(alpha: 0.6),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final term in ordered)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: _TermChip(
                                  term: term,
                                  phase: controller.phaseOf(term),
                                  selected: term.id == selectedId,
                                  onTap: busy || term.id == selectedId
                                      ? null
                                      : () => controller.changeTerm(term.id),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              _RoundIconButton(
                icon: Icons.chevron_right,
                tooltip: '다음 학기',
                onPressed: canNext
                    ? () => controller.changeTerm(ordered[selectedIndex + 1].id)
                    : null,
              ),
              const SizedBox(width: 4),
                  if (selected != null) ...[
                    _buildReadOnlyControl(context, selected, compact),
                    _RoundIconButton(
                      icon: Icons.edit_outlined,
                      tooltip: '학기 정보 수정',
                      onPressed: busy
                          ? null
                          : () => showTermEditorDialog(context, controller,
                              term: selected),
                    ),
                  ],
                  const SizedBox(width: 2),
                  _AddTermButton(
                    onPressed: busy
                        ? null
                        : () => showTermEditorDialog(context, controller),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// 지난 학기(보관 아님)일 때만 편집 잠금 해제/잠금 토글을 노출한다.
  /// [compact]이면 라벨 없이 아이콘 버튼으로 축약(좁은 폭 오버플로 방지).
  Widget _buildReadOnlyControl(
      BuildContext context, Term selected, bool compact) {
    if (controller.phaseOf(selected) != TermPhase.past) {
      return const SizedBox.shrink();
    }
    if (selected.isArchived) {
      // 보관 학기는 하드 잠금 — 해제 불가.
      return Tooltip(
        message: '보관된 학기는 편집할 수 없습니다',
        child: Icon(Icons.lock_outline, size: 18, color: NestColors.clay),
      );
    }
    final unlocked = controller.isPastTermEditingUnlocked;
    final color = unlocked ? NestColors.mutedSage : NestColors.clay;
    final onPressed =
        controller.isBusy ? null : controller.togglePastTermEditing;
    final icon = unlocked ? Icons.lock_open : Icons.lock_outline;
    if (compact) {
      return _RoundIconButton(
        icon: icon,
        tooltip: unlocked ? '지난 학기 편집 중 (다시 잠그기)' : '지난 학기 편집 잠금 해제',
        onPressed: onPressed,
        color: color,
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(unlocked ? '편집 중' : '편집 잠금 해제',
          style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

String termPhaseLabel(TermPhase phase) {
  return switch (phase) {
    TermPhase.past => '지난',
    TermPhase.current => '현재',
    TermPhase.upcoming => '예정',
  };
}

/// 학기 시간 단계별 배지 색. TermNavigatorBar(관리자)와
/// TermSelectChip(학부모/교사)이 같은 색 규칙을 공유한다.
Color termPhaseColor(TermPhase phase) {
  return switch (phase) {
    TermPhase.past => NestColors.clay,
    TermPhase.current => NestColors.mutedSage,
    TermPhase.upcoming => NestColors.dustyRose,
  };
}

class _TermChip extends StatelessWidget {
  const _TermChip({
    required this.term,
    required this.phase,
    required this.selected,
    required this.onTap,
  });

  final Term term;
  final TermPhase phase;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final phaseColor = termPhaseColor(phase);
    final bg = selected ? NestColors.deepWood : Colors.white;
    final fg = selected ? Colors.white : NestColors.deepWood;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? NestColors.deepWood : NestColors.roseMist,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: phaseColor.withValues(alpha: selected ? 0.9 : 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  termPhaseLabel(phase),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : phaseColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                term.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: fg,
                ),
              ),
              if (term.isArchived) ...[
                const SizedBox(width: 4),
                Icon(Icons.inventory_2_outlined,
                    size: 12, color: fg.withValues(alpha: 0.7)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      color: color ?? NestColors.deepWood,
    );
  }
}

class _AddTermButton extends StatelessWidget {
  const _AddTermButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 16),
      label: const Text('예정 학기', style: TextStyle(fontSize: 12)),
      style: FilledButton.styleFrom(
        backgroundColor: NestColors.dustyRose.withValues(alpha: 0.22),
        foregroundColor: NestColors.deepWood,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// 학기 생성/수정 다이얼로그. [term]이 null이면 생성 모드.
Future<void> showTermEditorDialog(
  BuildContext context,
  NestController controller, {
  Term? term,
}) async {
  final isCreate = term == null;

  // 생성 모드 기본값: 마지막 학기 종료 다음날부터 약 한 학기(140일).
  DateTime defaultStart() {
    final ends = controller.terms
        .map((t) => t.endDate)
        .whereType<DateTime>()
        .toList()
      ..sort();
    final base = ends.isNotEmpty ? ends.last.add(const Duration(days: 1)) : DateTime.now();
    return DateTime(base.year, base.month, base.day);
  }

  final initialStart = term?.startDate ?? defaultStart();
  final initialEnd =
      term?.endDate ?? initialStart.add(const Duration(days: 140));

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _TermEditorDialog(
      controller: controller,
      term: term,
      isCreate: isCreate,
      initialName: term?.name ?? _suggestNextTermName(controller),
      initialStart: initialStart,
      initialEnd: initialEnd,
    ),
  );
}

/// 마지막 학기 이름의 끝 숫자를 1 올려 다음 학기 이름을 제안한다.
/// (예: "2026-1" → "2026-2", "2학기" → "3학기"). 실패하면 빈 문자열.
String _suggestNextTermName(NestController controller) {
  // 시작일이 있는 학기만으로 최신 학기를 정한다(null 날짜는 비교 불가라 제외).
  final dated = controller.terms
      .where((t) => t.startDate != null)
      .toList()
    ..sort((a, b) => a.startDate!.compareTo(b.startDate!));
  final last = dated.lastOrNull ?? controller.terms.lastOrNull;
  if (last == null) return '';
  final match = RegExp(r'^(.*?)(\d+)(\D*)$').firstMatch(last.name);
  if (match == null) return '';
  final prefix = match.group(1) ?? '';
  final number = int.tryParse(match.group(2) ?? '');
  final suffix = match.group(3) ?? '';
  if (number == null) return '';
  return '$prefix${number + 1}$suffix';
}

class _TermEditorDialog extends StatefulWidget {
  const _TermEditorDialog({
    required this.controller,
    required this.term,
    required this.isCreate,
    required this.initialName,
    required this.initialStart,
    required this.initialEnd,
  });

  final NestController controller;
  final Term? term;
  final bool isCreate;
  final String initialName;
  final DateTime initialStart;
  final DateTime initialEnd;

  @override
  State<_TermEditorDialog> createState() => _TermEditorDialogState();
}

class _TermEditorDialogState extends State<_TermEditorDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);
  late DateTime _start = widget.initialStart;
  late DateTime _end = widget.initialEnd;
  late String _status = widget.term?.status ?? 'DRAFT';
  bool _saving = false;

  static const _statuses = ['DRAFT', 'ACTIVE', 'ARCHIVED'];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _statusLabel(String status) {
    return switch (status) {
      'DRAFT' => '초안 (DRAFT)',
      'ACTIVE' => '운영 중 (ACTIVE)',
      'ARCHIVED' => '보관 (ARCHIVED · 편집·삭제 잠금)',
      _ => status,
    };
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
          if (_end.isBefore(_start)) {
            _end = _start.add(const Duration(days: 1));
          }
        } else {
          _end = picked;
        }
      });
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message =
        error is StateError ? error.message : '작업에 실패했습니다: $error';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError(StateError('학기 이름을 입력하세요.'));
      return;
    }
    if (_end.isBefore(_start)) {
      _showError(StateError('종료일은 시작일보다 빠를 수 없습니다.'));
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.isCreate) {
        await widget.controller
            .createTerm(name: name, startDate: _start, endDate: _end);
      } else {
        await widget.controller.updateTerm(
          termId: widget.term!.id,
          name: name,
          startDate: _start,
          endDate: _end,
          status: _status,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _saving = false);
      // DB unique(homeschool_id, name) 위반 등도 여기서 안내.
      _showError(error is StateError
          ? error
          : StateError('저장에 실패했습니다. 이름이 중복되지 않았는지 확인하세요.'));
    }
  }

  Future<void> _confirmDelete() async {
    final term = widget.term!;
    final isSelected = widget.controller.selectedTermId == term.id;
    final classCount =
        isSelected ? widget.controller.classGroups.length : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('학기 삭제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('‘${term.name}’ 학기를 삭제할까요?'),
            const SizedBox(height: 10),
            Text(
              '이 학기의 반${classCount != null ? ' $classCount개' : ''}·수업 시간표·'
              '자습 계획·교실이 모두 함께 삭제됩니다. 되돌릴 수 없습니다.',
              style: TextStyle(
                fontSize: 13,
                color: NestColors.clay,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await widget.controller.deleteTerm(termId: term.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _saving = false);
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final term = widget.term;
    // 보관 학기는 이름·기간을 잠근다(보관 해제만 허용). 삭제도 불가.
    final archivedLock = !widget.isCreate && (term?.isArchived ?? false);
    final canDelete = !widget.isCreate &&
        term != null &&
        !term.isArchived &&
        widget.controller.terms.length > 1;

    return AlertDialog(
      title: Text(widget.isCreate ? '예정 학기 추가' : '학기 정보 수정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (archivedLock)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '보관된 학기입니다. 이름·기간은 잠겨 있어요. 상태를 바꿔 보관을 해제하면 수정할 수 있습니다.',
                  style: TextStyle(fontSize: 12, color: NestColors.clay),
                ),
              ),
            TextField(
              controller: _nameController,
              autofocus: widget.isCreate,
              readOnly: archivedLock,
              decoration: const InputDecoration(
                labelText: '학기 이름',
                hintText: '예: 2026-2학기',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: '시작일',
                    value: _fmtDate(_start),
                    onTap: _saving || archivedLock ? null : () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DateField(
                    label: '종료일',
                    value: _fmtDate(_end),
                    onTap:
                        _saving || archivedLock ? null : () => _pickDate(false),
                  ),
                ),
              ],
            ),
            if (!widget.isCreate) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _statuses.contains(_status) ? _status : 'DRAFT',
                decoration: const InputDecoration(labelText: '상태'),
                items: [
                  for (final s in _statuses)
                    DropdownMenuItem(value: s, child: Text(_statusLabel(s))),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _status = value);
                      },
              ),
              if (_status == 'ARCHIVED')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '보관 학기는 편집·삭제가 잠깁니다(DB 트리거로 보호).',
                    style: TextStyle(fontSize: 12, color: NestColors.clay),
                  ),
                ),
            ],
            if (canDelete) ...[
              const Divider(height: 28),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _confirmDelete,
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: Colors.red.shade600),
                  label: Text('이 학기 삭제',
                      style: TextStyle(color: Colors.red.shade600)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.isCreate ? '만들기' : '저장'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.date_range, size: 18),
        ),
        child: Text(value),
      ),
    );
  }
}
