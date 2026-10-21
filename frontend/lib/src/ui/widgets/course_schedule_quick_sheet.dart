import 'package:flutter/material.dart';

import '../../services/course_schedule_quick_adder.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import 'nest_3d_icon.dart';
import 'nest_sheet.dart';

/// 카드 조립 없이 다양한 템플릿이나 자연어 문장(예시 문장 포함)으로
/// 과목과 주간 시간표를 한 번에 추가하는 시트.
Future<bool?> showCourseScheduleQuickSheet({
  required BuildContext context,
  required NestController controller,
  int initialMode = 0, // 0: 템플릿, 1: 문장 입력
  bool defaultPlaceOnTimetable = true,
}) {
  return showNestSheet<bool>(
    context: context,
    builder: (ctx) => _CourseScheduleQuickSheetContent(
      controller: controller,
      initialMode: initialMode,
      defaultPlaceOnTimetable: defaultPlaceOnTimetable,
    ),
  );
}

class _CourseScheduleQuickSheetContent extends StatefulWidget {
  const _CourseScheduleQuickSheetContent({
    required this.controller,
    required this.initialMode,
    required this.defaultPlaceOnTimetable,
  });

  final NestController controller;
  final int initialMode;
  final bool defaultPlaceOnTimetable;

  @override
  State<_CourseScheduleQuickSheetContent> createState() =>
      _CourseScheduleQuickSheetContentState();
}

class _CourseScheduleQuickSheetContentState
    extends State<_CourseScheduleQuickSheetContent> {
  late int _mode; // 0: 템플릿으로 추가, 1: 문장으로 추가
  late String _selectedTemplateId;
  late Set<String> _selectedTemplateCourseNames;
  late bool _placeOnTimetable;
  final _sentenceController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _placeOnTimetable = widget.defaultPlaceOnTimetable;
    final firstTemplate = kCourseScheduleTemplates.first;
    _selectedTemplateId = firstTemplate.id;
    _selectedTemplateCourseNames = firstTemplate.courses
        .map((c) => c.name)
        .toSet();
  }

  @override
  void dispose() {
    _sentenceController.dispose();
    super.dispose();
  }

  CourseScheduleTemplate get _currentTemplate {
    return kCourseScheduleTemplates.firstWhere(
      (t) => t.id == _selectedTemplateId,
      orElse: () => kCourseScheduleTemplates.first,
    );
  }

  void _selectTemplate(CourseScheduleTemplate template) {
    setState(() {
      _selectedTemplateId = template.id;
      _selectedTemplateCourseNames = template.courses
          .map((c) => c.name)
          .toSet();
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _applyCurrentSelection() async {
    if (_isSaving) return;

    List<CourseTemplateItem> coursesToEnsure;
    List<TemplateSlotPlacement> placements;

    if (_mode == 0) {
      final tpl = _currentTemplate;
      coursesToEnsure = tpl.courses
          .where((c) => _selectedTemplateCourseNames.contains(c.name))
          .toList();
      placements = tpl.placements
          .where((p) => _selectedTemplateCourseNames.contains(p.courseName))
          .toList();
      if (coursesToEnsure.isEmpty) {
        _showSnack('추가할 과목을 하나 이상 선택해 주세요.');
        return;
      }
    } else {
      final parsed = parseCourseScheduleSentence(_sentenceController.text);
      if (parsed.isEmpty) {
        _showSnack('아래 예시 문장을 참고해 추가할 수업 문장을 입력해 주세요.');
        return;
      }
      coursesToEnsure = parsed.courses;
      placements = parsed.placements;
    }

    setState(() => _isSaving = true);
    try {
      await widget.controller.applyCourseAndScheduleQuickAdd(
        coursesToEnsure: coursesToEnsure,
        placements: placements,
        placeOnTimetable: _placeOnTimetable && placements.isNotEmpty,
      );
      if (!mounted) return;
      _showSnack(widget.controller.statusMessage);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack(
        e is StateError ? e.message : widget.controller.statusMessage,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsedSentence = parseCourseScheduleSentence(_sentenceController.text);

    return NestSheet(
      title: '템플릿·문장으로 수업 한 번에 추가',
      actions: [
        OutlinedButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('닫기'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _applyCurrentSelection,
          icon: const Icon(Icons.auto_awesome_outlined, size: 18),
          label: Text(
            _mode == 0
                ? (_placeOnTimetable ? '템플릿 과목·시간표 적용' : '템플릿 과목 추가')
                : (_placeOnTimetable && parsedSentence.hasPlacements
                      ? '문장대로 과목·시간표 반영'
                      : '문장대로 과목 추가'),
          ),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Nest3dIcon.studyBooks(size: 38, floating: true),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '수업 카드를 하나씩 만들 필요 없어요! 맞춤 템플릿을 고르거나 한 줄 문장으로 과목과 시간표(9시~18시)를 한 번에 채우세요.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.78),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  icon: Icon(Icons.auto_stories_outlined, size: 18),
                  label: Text('다양한 템플릿 선택'),
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: Icon(Icons.edit_note_outlined, size: 18),
                  label: Text('문장으로 입력 (예시 제공)'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _isSaving
                  ? null
                  : (vals) => setState(() => _mode = vals.first),
            ),
          ),
          const SizedBox(height: 14),
          if (_mode == 0)
            _buildTemplateMode(theme)
          else
            _buildSentenceMode(theme, parsedSentence),
        ],
      ),
    );
  }

  Widget _buildTemplateMode(ThemeData theme) {
    final tpl = _currentTemplate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '우리 아이 연령·스타일에 맞는 템플릿을 고르세요',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in kCourseScheduleTemplates)
              ChoiceChip(
                label: Text('${item.title} (${item.badge})'),
                selected: item.id == _selectedTemplateId,
                onSelected: _isSaving ? null : (_) => _selectTemplate(item),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: NestColors.creamyWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NestColors.roseMist),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tpl.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: NestColors.roseMist.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tpl.badge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                tpl.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '포함 과목 (눌러서 빼거나 더할 수 있어요)',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final course in tpl.courses)
                    FilterChip(
                      label: Text(
                        '${course.name} (${course.defaultDurationMin}분)',
                      ),
                      selected: _selectedTemplateCourseNames.contains(
                        course.name,
                      ),
                      onSelected: _isSaving
                          ? null
                          : (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedTemplateCourseNames.add(course.name);
                                } else {
                                  _selectedTemplateCourseNames.remove(
                                    course.name,
                                  );
                                }
                              });
                            },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: _placeOnTimetable,
                onChanged: _isSaving
                    ? null
                    : (v) => setState(() => _placeOnTimetable = v ?? true),
                title: Text(
                  '주간 추천 시간표(${tpl.placements.where((p) => _selectedTemplateCourseNames.contains(p.courseName)).length}교시)도 시간표에 바로 채우기',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSentenceMode(
    ThemeData theme,
    ParsedCourseScheduleResult parsed,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '문장으로 편하게 적어 주세요',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '요일과 시간(또는 교시)을 함께 적으면 과목 생성과 시간표 배치가 한 번에 끝납니다.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: NestColors.deepWood.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _sentenceController,
          enabled: !_isSaving,
          maxLines: 3,
          minLines: 2,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: '수업·시간표 문장 입력',
            hintText:
                '예: 월수금 9시 국어, 10시 수학, 화목 10시 영어, 오후 2시 미술 추가해줘',
            suffixIcon: _sentenceController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '지우기',
                    onPressed: () => setState(() => _sentenceController.clear()),
                    icon: const Icon(Icons.clear, size: 18),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '예시 문장 (누르면 입력창에 바로 채워져요)',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: NestColors.clay,
          ),
        ),
        const SizedBox(height: 6),
        ...kCourseScheduleExampleSentences.map(
          (example) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _isSaving
                  ? null
                  : () {
                      setState(() {
                        _sentenceController.text = example.sentence;
                      });
                    },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: NestColors.creamyWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: NestColors.roseMist),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: NestColors.roseMist.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        example.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '"${example.sentence}"',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.touch_app_outlined,
                      size: 16,
                      color: NestColors.clay,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (!parsed.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NestColors.mutedSage.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: NestColors.mutedSage.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '인식된 과목 (${parsed.courses.length}개)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in parsed.courses)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('${c.name} (${c.defaultDurationMin}분)'),
                      ),
                  ],
                ),
                if (parsed.hasPlacements) ...[
                  const SizedBox(height: 8),
                  Text(
                    '인식된 시간표 배치 (${parsed.placements.length}교시)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in parsed.placements)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            '${p.dayLabel} ${p.startTime} · ${p.courseName}',
                          ),
                        ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _placeOnTimetable,
                    onChanged: _isSaving
                        ? null
                        : (v) => setState(() => _placeOnTimetable = v ?? true),
                    title: const Text('인식된 요일·시간에 수업을 바로 배치하기'),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// 시간표 탭이나 과목 관리 화면 상단에 놓이는 빠른 추가 안내 배너.
class CourseScheduleQuickBanner extends StatelessWidget {
  const CourseScheduleQuickBanner({
    super.key,
    required this.controller,
    this.onApplied,
  });

  final NestController controller;
  final VoidCallback? onApplied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NestColors.creamyWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Nest3dIcon.studyBooks(size: 34, floating: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '템플릿·문장으로 수업 한 번에 추가',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '카드를 일일이 만들지 않고 추천 템플릿이나 한 줄 문장으로 과목·시간표를 채워보세요.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: controller.isBusy
                    ? null
                    : () async {
                        final applied = await showCourseScheduleQuickSheet(
                          context: context,
                          controller: controller,
                          initialMode: 0,
                        );
                        if (applied == true) {
                          onApplied?.call();
                        }
                      },
                icon: const Icon(Icons.auto_stories_outlined, size: 18),
                label: const Text('다양한 템플릿 고르기'),
              ),
              FilledButton.icon(
                onPressed: controller.isBusy
                    ? null
                    : () async {
                        final applied = await showCourseScheduleQuickSheet(
                          context: context,
                          controller: controller,
                          initialMode: 1,
                        );
                        if (applied == true) {
                          onApplied?.call();
                        }
                      },
                icon: const Icon(Icons.edit_note_outlined, size: 18),
                label: const Text('문장으로 수업 추가'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
