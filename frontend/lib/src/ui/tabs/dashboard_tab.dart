import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../services/course_schedule_quick_adder.dart';
import '../../state/nest_controller.dart';
import '../models/homeschool_start_tips.dart';
import '../nest_theme.dart';
import '../widgets/homeschool_tips_card.dart';
import '../widgets/nest_3d_icon.dart';
import '../widgets/nest_motion.dart';

/// 소속 홈스쿨이 없는 사용자를 위한 토스 스타일 단계별 인라인 온보딩 화면.
///
/// 불필요한 모달 팝업과 다단계 클릭을 없애고, 한 카드 안에서 애니메이션으로
/// 즉시 펼쳐지며(0ms 로컬 전환) 1초 만에 바로 열거나 템플릿·문장으로
/// 시간표(09:00~18:00, 50분/10분)까지 한 번에 세팅할 수 있다.
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late final TextEditingController _homeschoolController;
  late final TextEditingController _termController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _classController;
  late final TextEditingController _sentenceController;
  late final TextEditingController _childNameController;

  /// 0: 1단계(이름 확인 및 1초 시작), 1: 2단계(수업 템플릿·문장 및 첫 아이 선택)
  int _step = 0;
  bool _showAdvancedSettings = false;
  bool _useCustomSentence = false;
  String _selectedTemplateId = kCourseScheduleTemplates.first.id;

  bool _submitting = false;
  int _progressPhase = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final nickname = widget.controller.user?.userMetadata?['full_name'];
    _homeschoolController = TextEditingController(
      text: HomeschoolStartDefaults.nameFromProfile(
        realName: widget.controller.myRealName,
        nickname: nickname is String ? nickname : '',
      ),
    );
    _termController = TextEditingController(
      text: HomeschoolStartDefaults.termName(now),
    );
    _startDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(now),
    );
    _endDateController = TextEditingController(
      text: DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(now.year, now.month + 6, now.day)),
    );
    _classController = TextEditingController(
      text: HomeschoolStartDefaults.defaultClassName,
    );
    _sentenceController = TextEditingController(
      text: kCourseScheduleExampleSentences.first.sentence,
    );
    _childNameController = TextEditingController();
  }

  @override
  void dispose() {
    _homeschoolController.dispose();
    _termController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _classController.dispose();
    _sentenceController.dispose();
    _childNameController.dispose();
    super.dispose();
  }

  CourseScheduleTemplate get _selectedTemplate {
    return kCourseScheduleTemplates.firstWhere(
      (t) => t.id == _selectedTemplateId,
      orElse: () => kCourseScheduleTemplates.first,
    );
  }

  List<String> get _nameSuggestions {
    final nickname = widget.controller.user?.userMetadata?['full_name'];
    final defaultName = HomeschoolStartDefaults.nameFromProfile(
      realName: widget.controller.myRealName,
      nickname: nickname is String ? nickname : '',
    );
    final set = <String>{
      defaultName,
      '우리집 홈스쿨',
      '조이 홈스쿨',
      '숲속 홈스쿨',
    };
    return set.toList();
  }

  void _goToStep2() {
    if (_homeschoolController.text.trim().isEmpty) {
      _homeschoolController.text = '우리집 홈스쿨';
    }
    NestHaptics.tap();
    setState(() {
      _errorMessage = null;
      _step = 1;
    });
  }

  Future<void> _pickDate(TextEditingController target) async {
    if (_submitting) return;
    final parsed = DateTime.tryParse(target.text.trim());
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() {
      target.text = DateFormat('yyyy-MM-dd').format(picked);
    });
  }

  Future<void> _startHomeschoolInline({bool quickDefault = false}) async {
    if (_submitting || widget.controller.isBusy) return;

    final homeschoolName = _homeschoolController.text.trim().isEmpty
        ? '우리집 홈스쿨'
        : _homeschoolController.text.trim();
    final termName = _termController.text.trim().isEmpty
        ? HomeschoolStartDefaults.termName(DateTime.now())
        : _termController.text.trim();
    final className = _classController.text.trim().isEmpty
        ? HomeschoolStartDefaults.defaultClassName
        : _classController.text.trim();
    final startDate = _startDateController.text.trim();
    final endDate = _endDateController.text.trim();
    final childName = _childNameController.text.trim();

    late final List<CourseTemplateItem> coursesToEnsure;
    late final List<TemplateSlotPlacement> placements;
    if (!quickDefault && _useCustomSentence) {
      final parsed = parseCourseScheduleSentence(_sentenceController.text);
      coursesToEnsure = parsed.courses;
      placements = parsed.placements;
    } else {
      final template = _selectedTemplate;
      coursesToEnsure = template.courses;
      placements = template.placements;
    }

    final coursesCsv = coursesToEnsure.isNotEmpty
        ? coursesToEnsure.map((c) => c.name).join(', ')
        : HomeschoolStartDefaults.defaultCourses;

    NestHaptics.tap();
    setState(() {
      _submitting = true;
      _progressPhase = 0;
      _errorMessage = null;
    });

    try {
      // 1단계: 홈스쿨 + 학기 + 반 + 기본 과목 + 평일 09:00~18:00(50분/10분) 슬롯 일괄 생성
      await widget.controller.bootstrapFrame(
        homeschoolName: homeschoolName,
        termName: termName,
        startDate: startDate,
        endDate: endDate,
        className: className,
        coursesCsv: coursesCsv,
      );

      if (mounted) {
        setState(() => _progressPhase = 1);
      }

      // 2단계: 선택한 템플릿/문장의 주간 시간표 배치 (단일 배치 INSERT)
      if (placements.isNotEmpty) {
        try {
          await widget.controller.applyCourseAndScheduleQuickAdd(
            coursesToEnsure: coursesToEnsure,
            placements: placements,
            placeOnTimetable: true,
          );
        } catch (_) {}
      }

      // 3단계: 첫 아이 이름이 입력된 경우 가정·보호자·아이·반 자동 배정
      if (childName.isNotEmpty) {
        if (mounted) {
          setState(() => _progressPhase = 2);
        }
        await widget.controller.registerFirstChildOnboarding(
          childName: childName,
        );
      }

      if (mounted) {
        setState(() => _progressPhase = 3);
      }
      NestHaptics.success();
      unawaited(widget.controller.loadDriveIntegration());
    } catch (_) {
      if (!mounted) return;
      final msg = widget.controller.statusMessage.trim();
      setState(() {
        _submitting = false;
        _errorMessage = msg.isEmpty ? '우리집 홈스쿨을 만들지 못했어요.' : msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (controller.pendingInvites.isNotEmpty) ...[
          NestAppear(
            index: 0,
            child: PendingInvitesCard(controller: controller),
          ),
          const SizedBox(height: 16),
        ],
        NestAppear(
          index: 1,
          child: _buildTossProgressiveOnboardingCard(theme, controller),
        ),
        const SizedBox(height: 16),
        const NestAppear(index: 2, child: HomeschoolTipsCard()),
        const SizedBox(height: 16),
        NestAppear(index: 3, child: _buildJoinExistingCard(theme, controller)),
      ],
    );
  }

  // ── Toss-Style Progressive Unfolding Onboarding Card ──

  Widget _buildTossProgressiveOnboardingCard(
    ThemeData theme,
    NestController controller,
  ) {
    final targetProgress = _submitting ? 1.0 : (_step == 0 ? 0.5 : 0.92);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: NestColors.dustyRose.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 애니메이션 진행 바
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.25, end: targetProgress),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: NestColors.roseMist.withValues(alpha: 0.45),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    NestColors.dustyRose,
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _submitting
                    ? _buildSubmittingChecklist(theme)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStepHeader(theme, controller),
                          const SizedBox(height: 18),
                          if (_errorMessage != null) ...[
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.red.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              final slide = Tween<Offset>(
                                begin: const Offset(0, 0.04),
                                end: Offset.zero,
                              ).animate(animation);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: slide,
                                  child: child,
                                ),
                              );
                            },
                            child: _step == 0
                                ? _buildStep1NameContent(theme)
                                : _buildStep2ScheduleContent(theme),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader(ThemeData theme, NestController controller) {
    final stepBadgeText = _step == 0
        ? 'STEP 1 / 2 · 1초 만에 시작'
        : 'STEP 2 / 2 · 수업·시간표 자동 세팅';
    final titleText = _step == 0
        ? '우리집 홈스쿨 이름을 정해 볼까요?'
        : '어떤 수업으로 시간표를 채울까요?';
    final subtitleText = _step == 0
        ? '평일 9시~18시(50분 수업·10분 휴식) 기본 시간표와 학기·반이 자동으로 준비돼요.'
        : '템플릿이나 예시 문장을 누르면 과목 생성부터 시간표 배치까지 한 번에 끝나요.';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: NestColors.roseMist.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  stepBadgeText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: NestColors.deepWood,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  titleText,
                  key: ValueKey<String>(titleText),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: NestColors.deepWood,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  subtitleText,
                  key: ValueKey<String>(subtitleText),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _step == 0
            ? const Nest3dIcon.logo(size: 52, floating: true)
            : const Nest3dIcon.calendar(size: 52, floating: true),
      ],
    );
  }

  Widget _buildStep1NameContent(ThemeData theme) {
    final suggestions = _nameSuggestions;

    return Column(
      key: const ValueKey<String>('onboarding-step-1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _homeschoolController,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _goToStep2(),
          onChanged: (_) => setState(() {}),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            labelText: '우리집 홈스쿨 이름',
            hintText: '예: 민지네 집',
            prefixIcon: const Icon(Icons.home_rounded),
            suffixIcon: _homeschoolController.text.isNotEmpty
                ? IconButton(
                    onPressed: () =>
                        setState(() => _homeschoolController.clear()),
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: '지우기',
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in suggestions)
              ActionChip(
                avatar: Icon(
                  _homeschoolController.text.trim() == name
                      ? Icons.check_circle_rounded
                      : Icons.auto_awesome_outlined,
                  size: 16,
                  color: _homeschoolController.text.trim() == name
                      ? NestColors.deepWood
                      : NestColors.clay,
                ),
                backgroundColor: _homeschoolController.text.trim() == name
                    ? NestColors.roseMist
                    : NestColors.creamyWhite,
                side: BorderSide(
                  color: _homeschoolController.text.trim() == name
                      ? NestColors.dustyRose
                      : NestColors.roseMist,
                ),
                label: Text(
                  name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: _homeschoolController.text.trim() == name
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  NestHaptics.tap();
                  setState(() {
                    _homeschoolController.text = name;
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 18),
        NestPressable(
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _goToStep2,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('다음 · 수업 템플릿 고르기'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _startHomeschoolInline(quickDefault: true),
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('기본 시간표(9시~18시)로 1초 만에 바로 열기'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: BorderSide(color: NestColors.roseMist),
              backgroundColor: NestColors.creamyWhite,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2ScheduleContent(ThemeData theme) {
    final template = _selectedTemplate;
    final parsedCustom = parseCourseScheduleSentence(_sentenceController.text);
    final previewCoursesCount = _useCustomSentence
        ? parsedCustom.courses.length
        : template.courses.length;
    final previewPlacementsCount = _useCustomSentence
        ? parsedCustom.placements.length
        : template.placements.length;

    return Column(
      key: const ValueKey<String>('onboarding-step-2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1단계 완료 요약 배지 (클릭 시 0ms로 1단계 펼침)
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            NestHaptics.tap();
            setState(() => _step = 0);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: NestColors.mutedSage.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: NestColors.mutedSage.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: NestColors.deepWood,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '홈스쿨 이름: ${_homeschoolController.text.trim()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: NestColors.deepWood,
                    ),
                  ),
                ),
                Text(
                  '이름 바꾸기',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: NestColors.clay,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 모드 선택 탭 칩 (추천 템플릿 vs 문장 직접 입력)
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                selected: !_useCustomSentence,
                label: const SizedBox(
                  width: double.infinity,
                  child: Text('✨ 추천 템플릿 고르기', textAlign: TextAlign.center),
                ),
                onSelected: (_) {
                  NestHaptics.tap();
                  setState(() => _useCustomSentence = false);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                selected: _useCustomSentence,
                label: const SizedBox(
                  width: double.infinity,
                  child: Text('✍️ 한 줄 문장으로 입력', textAlign: TextAlign.center),
                ),
                onSelected: (_) {
                  NestHaptics.tap();
                  setState(() => _useCustomSentence = true);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: !_useCustomSentence
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in kCourseScheduleTemplates)
                          ChoiceChip(
                            selected: _selectedTemplateId == item.id,
                            label: Text('${item.title} (${item.badge})'),
                            onSelected: (_) {
                              NestHaptics.tap();
                              setState(() => _selectedTemplateId = item.id);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                                color: NestColors.dustyRose,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${template.title} · 과목 ${template.courses.length}개 · 주 ${template.placements.length}교시 자동 배치',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            template.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: NestColors.deepWood.withValues(
                                alpha: 0.72,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final c in template.courses)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: NestColors.roseMist.withValues(
                                      alpha: 0.55,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    c.name,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _sentenceController,
                      maxLines: 2,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: '과목 또는 시간표 문장 입력',
                        hintText:
                            '예: 월수금 9시 국어, 10시 수학, 화목 10시 영어, 오후 2시 미술',
                        helperText:
                            '예시 문장을 눌러 바로 채우거나 자유롭게 수정해 보세요.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final ex in kCourseScheduleExampleSentences)
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(
                              Icons.auto_awesome_outlined,
                              size: 14,
                            ),
                            label: Text('예시: ${ex.label}'),
                            onPressed: () {
                              NestHaptics.tap();
                              setState(() {
                                _sentenceController.text = ex.sentence;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: NestColors.roseMist.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        previewCoursesCount == 0
                            ? '문장을 입력하면 생성될 과목과 시간표 수가 여기에 바로 표시됩니다.'
                            : '✨ 과목 $previewCoursesCount개 생성 · 주간 시간표 $previewPlacementsCount교시 자동 배치 예정',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: NestColors.deepWood,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 14),

        // 첫 아이 이름 입력 (선택)
        TextField(
          controller: _childNameController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _startHomeschoolInline(),
          decoration: const InputDecoration(
            labelText: '첫 아이 이름 (선택)',
            hintText: '예: 하준 (적어 두면 가정과 우리 반에 바로 배정돼요)',
            prefixIcon: Icon(Icons.child_care_rounded),
          ),
        ),
        const SizedBox(height: 12),

        // 접이식 학기·반·슬롯 기본 설정 요약
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            NestHaptics.tap();
            setState(() => _showAdvancedSettings = !_showAdvancedSettings);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: NestColors.deepWood.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '기본 설정: ${_termController.text} · ${_classController.text} · 평일 09:00~18:00 (50분/10분)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  _showAdvancedSettings
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: NestColors.deepWood.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: !_showAdvancedSettings
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _termController,
                              decoration: const InputDecoration(
                                labelText: '첫 학기 이름',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _classController,
                              decoration: const InputDecoration(
                                labelText: '기본 반 이름',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _startDateController,
                              readOnly: true,
                              onTap: () => _pickDate(_startDateController),
                              decoration: const InputDecoration(
                                labelText: '시작일',
                                suffixIcon: Icon(Icons.event_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _endDateController,
                              readOnly: true,
                              onTap: () => _pickDate(_endDateController),
                              decoration: const InputDecoration(
                                labelText: '종료일',
                                suffixIcon: Icon(Icons.event_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 18),

        NestPressable(
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _startHomeschoolInline(quickDefault: false),
              icon: const Icon(Icons.rocket_launch_rounded),
              label: const Text('우리집 홈스쿨 시작하기'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmittingChecklist(ThemeData theme) {
    final childName = _childNameController.text.trim();
    final steps = <String>[
      '홈스쿨 공간과 학기·반 생성',
      '평일 09:00~18:00 (50분/10분) 시간슬롯·시간표 자동 배치',
      if (childName.isNotEmpty) '$childName 어린이 가정 연결 및 반 배정',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Nest3dIcon.star(size: 48, floating: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '우리집 홈스쿨을 빠르게 세팅하고 있어요 ✨',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '완료되면 바로 홈 화면으로 이동합니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: _progressPhase > i
                      ? NestColors.mutedSage.withValues(alpha: 0.18)
                      : (_progressPhase == i
                            ? NestColors.roseMist.withValues(alpha: 0.45)
                            : NestColors.creamyWhite),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _progressPhase > i
                        ? NestColors.mutedSage
                        : NestColors.roseMist,
                  ),
                ),
                child: Row(
                  children: [
                    if (_progressPhase > i)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: NestColors.deepWood,
                      )
                    else if (_progressPhase == i)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    else
                      Icon(
                        Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: NestColors.deepWood.withValues(alpha: 0.35),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: _progressPhase >= i
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJoinExistingCard(ThemeData theme, NestController controller) {
    return Card(
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          leading: Icon(Icons.group_add_outlined, color: NestColors.clay),
          title: Text(
            '이미 홈스쿨이 있나요?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '참여 코드, 검색, 초대로 다른 홈스쿨에 합류할 수 있어요.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.72),
            ),
          ),
          children: [
            JoinByCodeCard(controller: controller, framed: false),
            const SizedBox(height: 12),
            HomeschoolSearchJoinCard(controller: controller, framed: false),
          ],
        ),
      ),
    );
  }
}

/// 이름으로 홈스쿨을 찾아 가입을 요청하는 카드.
class HomeschoolSearchJoinCard extends StatefulWidget {
  const HomeschoolSearchJoinCard({
    super.key,
    required this.controller,
    this.framed = true,
  });

  final NestController controller;
  final bool framed;

  @override
  State<HomeschoolSearchJoinCard> createState() =>
      _HomeschoolSearchJoinCardState();
}

class _HomeschoolSearchJoinCardState extends State<HomeschoolSearchJoinCard> {
  final _joinSearchController = TextEditingController();
  final _joinRequestNoteController = TextEditingController();
  bool _joinSearching = false;
  List<HomeschoolDirectoryEntry> _joinSearchResults = const [];
  String? _joinSearchMessage;
  final Set<String> _joinRequestingIds = <String>{};

  @override
  void dispose() {
    _joinSearchController.dispose();
    _joinRequestNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.travel_explore, color: NestColors.dustyRose),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '홈스쿨 검색 및 가입 요청',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '이름으로 홈스쿨을 검색한 뒤 가입 요청을 보낼 수 있습니다.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _joinSearchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchHomeschools(),
                  decoration: InputDecoration(
                    labelText: '홈스쿨 이름 검색',
                    hintText: '예: 우리 마을 홈스쿨',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: _joinSearching ? null : _searchHomeschools,
                      icon: const Icon(Icons.arrow_forward),
                      tooltip: '검색',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: _joinSearching ? null : _searchHomeschools,
                icon: const Icon(Icons.search),
                label: const Text('검색'),
              ),
            ],
          ),
          if (_joinSearchMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _joinSearchMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_joinSearching)
            const Center(child: CircularProgressIndicator())
          else if (_joinSearchResults.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NestColors.roseMist),
                color: NestColors.creamyWhite,
              ),
              child: Text(
                '검색어를 입력하고 홈스쿨을 찾아보세요.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            ..._joinSearchResults.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OnboardingJoinResultTile(
                  entry: entry,
                  isRequesting: _joinRequestingIds.contains(entry.id),
                  onRequest: () => _promptJoinRequest(entry),
                ),
              ),
            ),
        ],
      ),
    );
    if (!widget.framed) return body;
    return Card(child: body);
  }

  Future<void> _searchHomeschools() async {
    final query = _joinSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _joinSearchResults = const [];
        _joinSearchMessage = '검색어를 입력해주세요.';
      });
      return;
    }

    setState(() {
      _joinSearching = true;
      _joinSearchMessage = null;
    });

    try {
      final rows = await widget.controller.searchHomeschoolDirectory(
        query: query,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _joinSearchResults = rows;
        _joinSearchMessage = rows.isEmpty
            ? '검색 결과가 없습니다. 다른 키워드로 시도해보세요.'
            : null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _joinSearchMessage = widget.controller.statusMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _joinSearching = false;
        });
      }
    }
  }

  Future<void> _promptJoinRequest(HomeschoolDirectoryEntry entry) async {
    _joinRequestNoteController.clear();
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${entry.name} 가입 요청',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '관리자에게 전달할 메시지를 남길 수 있습니다. (선택)',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _joinRequestNoteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '요청 메시지',
                hintText: '예: 아이 2명이 함께 참여하려고 합니다.',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(_joinRequestNoteController.text),
                  child: const Text('가입 요청 보내기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (note == null) {
      return;
    }

    await _requestJoin(entry, note);
  }

  Future<void> _requestJoin(HomeschoolDirectoryEntry entry, String note) async {
    setState(() => _joinRequestingIds.add(entry.id));
    try {
      await widget.controller.requestJoinHomeschool(
        homeschoolId: entry.id,
        requestNote: note,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _joinSearchResults = _joinSearchResults
            .map(
              (row) => row.id == entry.id
                  ? row.copyWith(hasPendingRequest: true)
                  : row,
            )
            .toList();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.controller.statusMessage)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.controller.statusMessage)));
    } finally {
      if (mounted) {
        setState(() => _joinRequestingIds.remove(entry.id));
      }
    }
  }
}

/// 온보딩: 참여 코드로 홈스쿨에 합류하기 (가장 간편한 경로).
/// 코드 입력 → 홈스쿨 확인 → 역할(학부모/선생님) 선택 → 요청. 승인은 관리자가.
/// 참여 코드로 홈스쿨에 합류를 요청하는 온보딩 카드.
/// 코드 확인 → 역할(학부모/선생님/학생) 선택 → 요청 흐름을 담는다.
class JoinByCodeCard extends StatefulWidget {
  const JoinByCodeCard({
    super.key,
    required this.controller,
    this.framed = true,
  });

  final NestController controller;
  final bool framed;

  @override
  State<JoinByCodeCard> createState() => _JoinByCodeCardState();
}

class _JoinByCodeCardState extends State<JoinByCodeCard> {
  final _codeController = TextEditingController();
  final _noteController = TextEditingController();
  String? _resolvedName;
  bool _resolving = false;
  String _role = 'PARENT';
  bool _submitting = false;
  String? _submittedName;

  @override
  void dispose() {
    _codeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _msg(Object e) => e is StateError ? e.message : e.toString();
  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _resolve() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _resolving = true;
      _resolvedName = null;
    });
    try {
      final r = await widget.controller.resolveJoinCode(code);
      if (!mounted) return;
      setState(() => _resolvedName = r?.name);
      if (r == null) _snack('참여 코드에 해당하는 홈스쿨이 없어요. 코드를 확인해 주세요.');
    } catch (e) {
      _snack(_msg(e));
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final name = await widget.controller.joinWithCode(
        code: _codeController.text.trim(),
        role: _role,
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _submittedName = name);
    } catch (e) {
      _snack(_msg(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_submittedName != null) {
      final success = Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: NestColors.mutedSage,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_submittedName 합류를 요청했어요!',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _role == 'STUDENT'
                  ? '관리 선생님이 승인하면서 학생 정보와 이 계정을 연결해 드립니다.\n'
                        '승인 후 앱을 새로고침하면 내 시간표가 나타납니다.'
                  : '관리자가 승인하면 바로 이용할 수 있어요. 조금만 기다려 주세요.\n'
                        '승인 후 앱을 새로고침하면 홈스쿨이 나타납니다.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
      if (!widget.framed) return success;
      return Card(
        color: NestColors.mutedSage.withValues(alpha: 0.12),
        child: success,
      );
    }

    final form = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key_outlined, color: NestColors.clay),
              const SizedBox(width: 8),
              Expanded(
                child: Text('참여 코드로 합류하기', style: theme.textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '학교(홈스쿨)에서 받은 코드를 입력하세요.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: '참여 코드',
                    hintText: '예: 44UDMV',
                    prefixIcon: Icon(Icons.tag),
                  ),
                  onSubmitted: (_) => _resolve(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _resolving ? null : _resolve,
                child: _resolving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('확인'),
              ),
            ],
          ),
          if (_resolvedName != null) ...[
            const Divider(height: 26),
            Text(
              '“$_resolvedName” 에 합류할까요?',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text('나는 …', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('학부모'),
                  selected: _role == 'PARENT',
                  onSelected: (_) => setState(() => _role = 'PARENT'),
                ),
                ChoiceChip(
                  label: const Text('선생님'),
                  selected: _role == 'TEACHER',
                  onSelected: (_) => setState(() => _role = 'TEACHER'),
                ),
                ChoiceChip(
                  label: const Text('학생'),
                  selected: _role == 'STUDENT',
                  onSelected: (_) => setState(() => _role = 'STUDENT'),
                ),
              ],
            ),
            if (_role == 'STUDENT') ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NestColors.roseMist.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '승인되면 관리 선생님이 학생 정보와 계정을 연결해 드립니다.\n'
                  '아래에 본인 이름을 적어 주면 더 빨리 확인할 수 있어요.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: '관리자에게 한마디 (선택)',
                hintText: _role == 'STUDENT'
                    ? '관리자가 알아볼 수 있게 (예: 3학년 김예서)'
                    : '관리자가 알아볼 수 있게 (예: 홍길동 아빠 · 자녀 예서)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.send_outlined, size: 18),
                label: Text(_submitting ? '요청 중...' : '합류 요청 보내기'),
              ),
            ),
          ],
        ],
      ),
    );
    if (!widget.framed) return form;
    return Card(child: form);
  }
}

class PendingInvitesCard extends StatelessWidget {
  const PendingInvitesCard({super.key, required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending =
        controller.pendingInvites.where((invite) => invite.canAccept).toList()
          ..sort((a, b) {
            final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return right.compareTo(left);
          });

    if (pending.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NestColors.creamyWhite,
            NestColors.roseMist.withValues(alpha: 0.55),
          ],
        ),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: NestColors.dustyRose.withValues(alpha: 0.22),
                foregroundColor: NestColors.deepWood,
                child: const Icon(Icons.mail_rounded, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('대기 중 초대', style: theme.textTheme.titleLarge),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.confirmation_num_outlined, size: 16),
                label: Text('${pending.length}건'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '홈스쿨 관리자에게 받은 초대를 수락하면 바로 멤버십이 활성화됩니다.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 14),
          ...pending.map(
            (invite) => _InviteItem(controller: controller, invite: invite),
          ),
        ],
      ),
    );
  }
}

class _InviteMetaChip extends StatelessWidget {
  const _InviteMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.72),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: NestColors.deepWood),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: NestColors.deepWood,
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteItem extends StatelessWidget {
  const _InviteItem({required this.controller, required this.invite});

  final NestController controller;
  final HomeschoolInvite invite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created = invite.createdAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd HH:mm').format(invite.createdAt!);
    final expires = invite.expiresAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd').format(invite.expiresAt!);
    final schoolName = invite.homeschoolName == 'Unknown Homeschool'
        ? '홈스쿨 이름 확인 중'
        : invite.homeschoolName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, NestColors.creamyWhite],
          ),
          border: Border.all(color: NestColors.roseMist),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.card_membership_rounded,
                  color: NestColors.dustyRose,
                ),
                const SizedBox(width: 8),
                Text(
                  '홈스쿨 초대장',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: NestColors.deepWood,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              schoolName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: NestColors.deepWood,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InviteMetaChip(icon: Icons.badge_outlined, label: invite.role),
                _InviteMetaChip(
                  icon: Icons.event_available_outlined,
                  label: '만료 $expires',
                ),
                _InviteMetaChip(
                  icon: Icons.schedule_outlined,
                  label: '발송 $created',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              height: 1,
              color: NestColors.roseMist,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: controller.isBusy
                    ? null
                    : () async {
                        try {
                          await controller.acceptPendingInvite(
                            invite.inviteToken,
                          );
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(controller.statusMessage)),
                          );
                        } catch (_) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(controller.statusMessage)),
                          );
                        }
                      },
                icon: const Icon(Icons.mark_email_read_outlined),
                label: const Text('이 초대 수락하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingJoinResultTile extends StatelessWidget {
  const _OnboardingJoinResultTile({
    required this.entry,
    required this.isRequesting,
    required this.onRequest,
  });

  final HomeschoolDirectoryEntry entry;
  final bool isRequesting;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final memberLabel = '활성 구성원 ${entry.activeMemberCount}명';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: NestColors.roseMist,
            foregroundColor: NestColors.deepWood,
            child: const Icon(Icons.school_outlined, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$memberLabel · ${entry.timezone}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          if (entry.hasPendingRequest)
            Chip(
              label: const Text('요청 대기중'),
              avatar: const Icon(Icons.hourglass_top, size: 16),
              visualDensity: VisualDensity.compact,
            )
          else
            FilledButton.tonal(
              onPressed: isRequesting ? null : onRequest,
              child: isRequesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('가입 요청'),
            ),
        ],
      ),
    );
  }
}
