import 'package:flutter/material.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import 'term_navigator_bar.dart';

/// 학부모/교사 뷰 헤더용 학기 선택 칩.
///
/// 현재 선택된 학기 이름과 시간 단계(지난/현재/예정) 배지를 보여주고,
/// 탭하면 바텀시트에서 다른 학기를 고를 수 있다. 관리자용
/// [TermNavigatorBar]의 경량 대응물 — 학기 생성/수정 없이 조회 전환만 한다.
class TermSelectChip extends StatelessWidget {
  const TermSelectChip({
    super.key,
    required this.controller,
    required this.onSelectTerm,
  });

  final NestController controller;
  final Future<void> Function(String? termId) onSelectTerm;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedTerm;
    final phase = selected == null ? null : controller.phaseOf(selected);
    final label = selected?.name ?? '학기 선택';
    final canOpen = !controller.isBusy && controller.terms.isNotEmpty;

    return Tooltip(
      message: '학기 선택',
      // RawChip이라야 탭 잉크가 칩 위에 그려지고, 비활성(로딩 중/학기 없음)
      // 상태도 표준 비활성 스타일로 구분된다.
      child: RawChip(
        onPressed: canOpen ? () => _openPicker(context) : null,
        isEnabled: canOpen,
        avatar: Icon(
          Icons.calendar_month_outlined,
          size: 14,
          color: phase != null ? termPhaseColor(phase) : NestColors.clay,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (phase != null) ...[
              const SizedBox(width: 5),
              // 좁은 폭(모바일 헤더 분배)에서는 배지를 축소해 오버플로를 막는다.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: termPhaseColor(phase).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      termPhaseLabel(phase),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: termPhaseColor(phase),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    // 시간순(시작일 오름차순) — 관리자 학기 바와 같은 순서.
    final ordered = controller.terms.toList()..sort(compareTermsByStartDate);
    final selectedId = controller.selectedTermId;

    final pickedId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '학기 선택',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: NestColors.deepWood,
                    ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final term in ordered)
                    _TermPickTile(
                      term: term,
                      phase: controller.phaseOf(term),
                      selected: term.id == selectedId,
                      onTap: () => Navigator.of(sheetContext).pop(term.id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (pickedId != null && pickedId != selectedId) {
      await onSelectTerm(pickedId);
    }
  }
}

class _TermPickTile extends StatelessWidget {
  const _TermPickTile({
    required this.term,
    required this.phase,
    required this.selected,
    required this.onTap,
  });

  final Term term;
  final TermPhase phase;
  final bool selected;
  final VoidCallback onTap;

  String _fmtDate(DateTime? value) {
    if (value == null) return '';
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final range = [_fmtDate(term.startDate), _fmtDate(term.endDate)]
        .where((s) => s.isNotEmpty)
        .join(' ~ ');

    return ListTile(
      onTap: onTap,
      leading: Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? NestColors.mutedSage : NestColors.clay,
        size: 20,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              term.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: NestColors.deepWood,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: termPhaseColor(phase).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              termPhaseLabel(phase),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: termPhaseColor(phase),
              ),
            ),
          ),
        ],
      ),
      subtitle: range.isEmpty
          ? null
          : Text(range, style: const TextStyle(fontSize: 12)),
      dense: true,
    );
  }
}
