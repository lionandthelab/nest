import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/nest_models.dart';
import '../../../state/nest_controller.dart';
import '../../nest_theme.dart';
import 'class_change_dialog.dart' show dayLabel;

/// 수업 회차 내용(course_lessons) 조회·입력 UI.
///
/// 시간표는 "요일×교시" 주간 반복 템플릿이라 회차 개념이 없다. 회차의 주인은
/// 과목 + 날짜이므로, 통합QT/주중예배처럼 한 과목이 여러 반·교시에 걸려 있어도
/// 진도는 날짜당 한 번만 입력하고 모든 시간표 셀이 같은 내용을 읽는다.
///
/// 회차 목록은 "학기 기간 안에서 그 과목이 있는 요일" 을 모두 펼쳐서 만든다.
/// 그래서 아직 아무것도 입력하지 않은 학기에서도 1회차·2회차… 자리가 먼저 보이고,
/// 관리자는 빈 칸을 눌러 채워 넣기만 하면 된다. 학기 종료일을 넘겨 미리 짜둔
/// 회차(예: 종료 11/30, 진도표 12/15까지)도 목록에서 사라지지 않게 함께 합친다.

/// 회차 목록의 한 줄. [lesson] 이 null 이면 아직 입력되지 않은 자리다.
class CourseLessonRow {
  const CourseLessonRow({
    required this.date,
    required this.lesson,
    required this.isInTerm,
  });

  final DateTime date;
  final CourseLesson? lesson;

  /// 선택된 학기 기간 안의 날짜인지. 밖이면 목록에서 따로 표시한다.
  final bool isInTerm;

  bool get isFilled => lesson != null && !lesson!.isBlank;
}

/// 안전 상한. 요일 5개 × 1년이면 260줄이라 실사용에서는 걸리지 않는다.
const int _maxGeneratedRows = 400;

/// 한 과목의 회차 목록을 만든다(날짜 순).
List<CourseLessonRow> buildCourseLessonRows(
  NestController controller,
  String courseId,
) {
  final term = controller.selectedTerm;
  final weekdays = controller.courseWeekdays(courseId);
  final saved = controller.lessonsForCourse(courseId);

  final termStart = term?.startDate;
  final termEnd = term?.endDate;

  final inTermDates = <DateTime>{};
  if (termStart != null && termEnd != null && weekdays.isNotEmpty) {
    var cursor = _dateOnly(termStart);
    final end = _dateOnly(termEnd);
    var guard = 0;
    while (!cursor.isAfter(end) && guard < _maxGeneratedRows) {
      if (weekdays.contains(_appDayOfWeek(cursor))) {
        inTermDates.add(cursor);
        guard++;
      }
      // 매 스텝 _dateOnly 로 되돌린다. DateTime.add 는 UTC 타임라인 기준이라
      // 서머타임이 있는 지역(웹은 해외에서도 열린다)에서는 하루를 더한 결과에
      // 01:00 같은 시각 성분이 남고, 그러면 시분초 0 인 저장 회차 키와 == 로
      // 매칭되지 않아 같은 날짜가 두 줄로 갈라진다.
      cursor = _dateOnly(cursor.add(const Duration(days: 1)));
    }
  }

  final byDate = <DateTime, CourseLesson>{};
  for (final lesson in saved) {
    byDate[_dateOnly(lesson.lessonDate)] = lesson;
  }

  final allDates = <DateTime>{...inTermDates, ...byDate.keys}.toList()..sort();

  // 학기 안/밖 판정은 학기 기간만 본다. inTermDates 는 "학기 안 + 수업 요일"이라
  // 그대로 쓰면 학기 중의 보강(수업 요일이 아닌 날)이 '학기 밖'으로 잘못 찍힌다.
  bool isInTerm(DateTime date) {
    if (termStart == null || termEnd == null) {
      return false;
    }
    return !date.isBefore(_dateOnly(termStart)) &&
        !date.isAfter(_dateOnly(termEnd));
  }

  return allDates
      .map(
        (date) => CourseLessonRow(
          date: date,
          lesson: byDate[date],
          isInTerm: isInTerm(date),
        ),
      )
      .toList();
}

/// 시간표 셀이 가리키는 "다가오는 회차 날짜". 셀 상세에서 어느 회차를 먼저
/// 보여줄지 정하는 기준이다. [slot] 요일의 오늘 이후 첫 날짜를 학기 범위 안에서
/// 고르고, 요일 정보가 없으면 null(= 그냥 다음 회차)로 둔다.
DateTime? courseLessonReferenceDate(NestController controller, TimeSlot? slot) {
  if (slot == null) {
    return null;
  }
  return _nextCourseOccurrence(
    weekdays: {slot.dayOfWeek},
    termStart: controller.selectedTerm?.startDate,
    termEnd: controller.selectedTerm?.endDate,
  );
}

// ---------------------------------------------------------------------------
// 공개 API
// ---------------------------------------------------------------------------

/// 한 과목의 회차 내용 시트.
///
/// 편집 권한이 없으면([NestController.canManageCourseLessons] false) 읽기 전용
/// 진도표로 열린다 — 학생·학부모도 같은 시트로 전체 진도를 볼 수 있다.
Future<void> showCourseLessonSheet({
  required BuildContext context,
  required NestController controller,
  required String courseId,
}) async {
  if (courseId.trim().isEmpty) {
    _showMessage(context, '과목 정보를 찾을 수 없습니다.');
    return;
  }

  // 회차 시트는 학기 맥락 없이도 열린다(학기 설정 → 과목 관리). 그 과목의 회차를
  // 날짜 창 없이 통째로 읽어, 창 밖 회차가 안 보이면서 같은 날짜로 등록하면
  // unique 위반이 나는 상태를 막는다. 실패해도 시트는 그대로 연다.
  unawaited(controller.loadCourseLessonsForCourse(courseId));

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return AnimatedBuilder(
        animation: controller,
        builder: (innerContext, _) {
          final canManage = controller.canManageCourseLessons;
          final rows = buildCourseLessonRows(controller, courseId);
          final filled = rows.where((row) => row.isFilled).length;
          final theme = Theme.of(innerContext);

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_stories_outlined, color: NestColors.clay),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '수업 회차 내용',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _courseHeadline(controller, courseId),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  // 읽기 전용에서는 빈 회차 줄을 감추므로(아래 타일 참고)
                  // "전체 N회차 중" 이라고 말하면 화면과 숫자가 어긋난다.
                  canManage
                      ? (rows.isEmpty
                            ? '아직 회차가 없습니다.'
                            : '전체 ${rows.length}회차 중 $filled회차 입력됨')
                      : (filled == 0 ? '아직 등록된 수업 내용이 없습니다.' : '$filled회차'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: NestColors.clay,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (canManage) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: controller.isBusy
                          ? null
                          : () => showCourseLessonEditor(
                              context: innerContext,
                              controller: controller,
                              courseId: courseId,
                            ),
                      icon: const Icon(Icons.add),
                      label: const Text('다른 날짜로 회차 추가'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '학기 기간 밖(보강·연장 진도) 날짜도 등록할 수 있습니다.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // 읽기 전용에서는 내용이 없는 회차 자리를 감추므로, 자리는 있어도
                // 채워진 것이 하나도 없으면 목록 대신 안내 문구를 보여준다.
                if (rows.isEmpty || (!canManage && filled == 0))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      canManage
                          ? '이 과목이 아직 시간표에 없어 회차 날짜를 만들 수 없습니다. '
                                '위의 "다른 날짜로 회차 추가"로 직접 등록하세요.'
                          : '아직 등록된 수업 내용이 없습니다. 선생님이 입력하면 여기에 보입니다.',
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                else
                  // 화면 높이의 고정 비율(0.55H)로 잡으면 위쪽 고정 헤더와 합이
                  // 화면을 넘겨 가로모드 폰·낮은 브라우저 창에서 오버플로가 난다.
                  // Flexible 은 헤더가 쓰고 남은 만큼만 가져가므로 어떤 높이에서도
                  // 넘치지 않고, 내용이 짧으면 그만큼만 차지한다.
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (var i = 0; i < rows.length; i++)
                            _CourseLessonRowTile(
                              controller: controller,
                              courseId: courseId,
                              row: rows[i],
                              index: i + 1,
                              canManage: canManage,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// 회차 등록/수정 다이얼로그. 저장했으면 true.
///
/// [existing] 이 있으면 수정, 없으면 [initialDate] 날짜로 새로 등록한다.
Future<bool> showCourseLessonEditor({
  required BuildContext context,
  required NestController controller,
  required String courseId,
  CourseLesson? existing,
  DateTime? initialDate,
}) async {
  if (!controller.canManageCourseLessons) {
    _showMessage(context, '수업 회차 내용은 담당 교사 또는 관리자/스태프만 입력할 수 있습니다.');
    return false;
  }

  final term = controller.selectedTerm;
  final weekdays = controller.courseWeekdays(courseId);
  var lessonDate = _dateOnly(
    existing?.lessonDate ??
        initialDate ??
        _defaultNewLessonDate(controller, courseId, weekdays: weekdays, term: term),
  );
  var isConfirmed = existing?.isConfirmed ?? false;

  final titleController = TextEditingController(text: existing?.title ?? '');
  final subtitleController = TextEditingController(
    text: existing?.subtitle ?? '',
  );
  final presenterController = TextEditingController(
    text: existing?.presenter ?? '',
  );
  final contentController = TextEditingController(
    text: existing?.content ?? '',
  );

  var saved = false;
  try {
    saved =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            var isSaving = false;

            return StatefulBuilder(
              builder: (localContext, setLocalState) {
                final theme = Theme.of(localContext);

                Future<void> pickDate() async {
                  final picked = await _pickLessonDate(
                    context: localContext,
                    initialDate: lessonDate,
                    termStart: term?.startDate,
                    termEnd: term?.endDate,
                  );
                  if (picked == null) {
                    return;
                  }
                  setLocalState(() => lessonDate = picked);
                }

                Future<void> save() async {
                  final title = titleController.text.trim();
                  final subtitle = subtitleController.text.trim();
                  final presenter = presenterController.text.trim();
                  final content = contentController.text.trim();

                  if (title.isEmpty &&
                      subtitle.isEmpty &&
                      presenter.isEmpty &&
                      content.isEmpty) {
                    _showMessage(localContext, '제목·담당·내용 중 하나는 입력하세요.');
                    return;
                  }

                  // 같은 과목·같은 날짜는 DB 유니크 제약에 걸린다. 여기서 먼저
                  // 잡아 "이미 있는 회차를 눌러 수정하라"고 안내한다(제약 위반을
                  // 그대로 두면 영어 SQL 원문이 한국어 화면에 뜬다).
                  final clash = controller.courseLessonOn(
                    courseId: courseId,
                    date: lessonDate,
                  );
                  if (clash != null && clash.id != existing?.id) {
                    _showMessage(
                      localContext,
                      '${_dateLabel(lessonDate)} 회차는 이미 있습니다. 목록에서 그 회차를 눌러 수정하세요.',
                    );
                    return;
                  }

                  setLocalState(() => isSaving = true);
                  try {
                    if (existing == null) {
                      await controller.createCourseLesson(
                        courseId: courseId,
                        lessonDate: lessonDate,
                        title: title,
                        subtitle: subtitle,
                        presenter: presenter,
                        content: content,
                        isConfirmed: isConfirmed,
                      );
                    } else {
                      await controller.updateCourseLesson(
                        id: existing.id,
                        lessonDate: lessonDate,
                        title: title,
                        subtitle: subtitle,
                        presenter: presenter,
                        content: content,
                        isConfirmed: isConfirmed,
                      );
                    }
                    if (!localContext.mounted) {
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  } catch (error) {
                    if (!localContext.mounted) {
                      return;
                    }
                    setLocalState(() => isSaving = false);
                    _showMessage(
                      localContext,
                      error is StateError
                          ? error.message
                          : controller.statusMessage,
                      isFailure: true,
                    );
                  }
                }

                Future<void> remove() async {
                  final target = existing;
                  if (target == null) {
                    return;
                  }
                  final confirmed = await showDialog<bool>(
                    context: localContext,
                    builder: (confirmContext) => AlertDialog(
                      title: const Text('회차 내용 삭제'),
                      content: Text(
                        '${_dateLabel(target.lessonDate)} 회차 내용을 삭제합니다.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(confirmContext).pop(false),
                          child: const Text('취소'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(confirmContext).pop(true),
                          child: const Text('삭제'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !localContext.mounted) {
                    return;
                  }
                  setLocalState(() => isSaving = true);
                  try {
                    await controller.deleteCourseLesson(id: target.id);
                    if (!localContext.mounted) {
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  } catch (error) {
                    if (!localContext.mounted) {
                      return;
                    }
                    setLocalState(() => isSaving = false);
                    _showMessage(
                      localContext,
                      error is StateError
                          ? error.message
                          : controller.statusMessage,
                      isFailure: true,
                    );
                  }
                }

                return AlertDialog(
                  title: Text(existing == null ? '회차 내용 등록' : '회차 내용 수정'),
                  content: SizedBox(
                    width: 460,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _courseHeadline(controller, courseId),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: NestColors.deepWood.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: isSaving ? null : pickDate,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: NestColors.roseMist),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.event_outlined,
                                    size: 20,
                                    color: NestColors.clay,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '수업 날짜',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: NestColors.deepWood
                                                    .withValues(alpha: 0.6),
                                              ),
                                        ),
                                        Text(
                                          _dateLabel(lessonDate),
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.edit_calendar_outlined,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: titleController,
                            enabled: !isSaving,
                            decoration: const InputDecoration(
                              labelText: '제목',
                              hintText: '예: 창세기 36장',
                              prefixIcon: Icon(Icons.menu_book_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: subtitleController,
                            enabled: !isSaving,
                            decoration: const InputDecoration(
                              labelText: '부제',
                              hintText: '예: 에서의 자손',
                              prefixIcon: Icon(Icons.short_text),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: presenterController,
                            enabled: !isSaving,
                            decoration: const InputDecoration(
                              labelText: '담당',
                              hintText: '예: 리아 (선생님·학부모·학생 이름)',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: contentController,
                            enabled: !isSaving,
                            minLines: 2,
                            maxLines: 6,
                            decoration: const InputDecoration(
                              labelText: '상세 내용 / 준비물',
                              hintText: '학생·학부모에게 함께 보여줄 안내를 적어주세요.',
                              prefixIcon: Icon(Icons.edit_note),
                            ),
                          ),
                          const SizedBox(height: 4),
                          CheckboxListTile(
                            value: isConfirmed,
                            onChanged: isSaving
                                ? null
                                : (value) => setLocalState(
                                    () => isConfirmed = value ?? false,
                                  ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('담당·내용 확정'),
                            subtitle: const Text('확정된 회차에는 체크 표시가 붙습니다.'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    if (existing != null)
                      TextButton(
                        onPressed: isSaving ? null : remove,
                        child: Text(
                          '삭제',
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: isSaving
                          ? null
                          : () => Navigator.of(dialogContext).pop(false),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: isSaving ? null : save,
                      child: Text(existing == null ? '등록' : '수정'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
  } finally {
    titleController.dispose();
    subtitleController.dispose();
    presenterController.dispose();
    contentController.dispose();
  }

  if (saved && context.mounted) {
    _showMessage(context, controller.statusMessage);
  }
  return saved;
}

/// 시간표 셀 상세에 끼워 넣는 "수업 내용" 요약 블록.
///
/// 다가오는 회차(없으면 마지막 회차)를 한 줄로 보여주고, 전체 진도표 시트로
/// 들어가는 버튼을 제공한다. 편집 권한이 없으면 버튼 문구만 읽기 전용으로 바뀐다.
class CourseLessonSummary extends StatelessWidget {
  const CourseLessonSummary({
    super.key,
    required this.controller,
    required this.courseId,
    this.referenceDate,
  });

  final NestController controller;
  final String courseId;

  /// 이 날짜의 회차를 우선 보여준다. null 이면 오늘 이후 가장 가까운 회차.
  final DateTime? referenceDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canManage = controller.canManageCourseLessons;
    final saved = controller.lessonsForCourse(courseId);

    final refDate = referenceDate;
    final exact = refDate == null
        ? null
        : controller.courseLessonOn(courseId: courseId, date: refDate);
    final lesson =
        exact ??
        controller.upcomingCourseLesson(courseId: courseId, from: refDate) ??
        (saved.isEmpty ? null : saved.last);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_stories_outlined, size: 20, color: NestColors.clay),
            const SizedBox(width: 10),
            Text(
              '수업 내용',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (saved.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                '${saved.length}회차',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: NestColors.clay,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (lesson == null)
          Text(
            canManage ? '아직 입력된 회차 내용이 없습니다.' : '아직 등록된 수업 내용이 없습니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.7),
            ),
          )
        else
          _LessonLine(
            lesson: lesson,
            // 실제 날짜 관계로 라벨을 정한다. exact != null 만 보면, 모든 회차가
            // 기준일보다 과거라 saved.last 로 떨어진 경우까지 '(다음 회차)' 가 붙어
            // 두 달 전 진도를 다음 수업이라고 안내하게 된다.
            relation: _lessonRelation(lesson, refDate ?? DateTime.now()),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => showCourseLessonSheet(
              context: context,
              controller: controller,
              courseId: courseId,
            ),
            icon: Icon(
              canManage
                  ? Icons.edit_calendar_outlined
                  : Icons.list_alt_outlined,
            ),
            label: Text(canManage ? '회차별 내용 입력' : '전체 진도표 보기'),
          ),
        ),
      ],
    );
  }
}

/// 요약 블록에 보여줄 회차가 기준일과 어떤 관계인지.
enum _LessonRelation {
  /// 기준일 바로 그 날의 회차 — 덧붙일 말이 없다.
  exact,

  /// 기준일 이후의 회차.
  upcoming,

  /// 기준일보다 과거의 회차(그 뒤로 등록된 회차가 없을 때).
  past,
}

_LessonRelation _lessonRelation(CourseLesson lesson, DateTime reference) {
  final pivot = _dateOnly(reference);
  if (lesson.isOn(pivot)) {
    return _LessonRelation.exact;
  }
  return lesson.lessonDate.isBefore(pivot)
      ? _LessonRelation.past
      : _LessonRelation.upcoming;
}

/// 회차 한 건을 "9월 15일(화) · 창세기 36장 · 에서의 자손 / 담당 리아" 로 보여준다.
class _LessonLine extends StatelessWidget {
  const _LessonLine({required this.lesson, required this.relation});

  final CourseLesson lesson;

  /// 기준일 대비 이 회차의 위치. 그 날짜면 아무 말도 덧붙이지 않는다.
  final _LessonRelation relation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = lesson.headline;
    final presenter = lesson.presenter.trim();
    final content = lesson.content.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _dateLabel(lesson.lessonDate),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (relation != _LessonRelation.exact) ...[
              const SizedBox(width: 6),
              Text(
                relation == _LessonRelation.upcoming ? '(다음 회차)' : '(지난 회차)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.6),
                ),
              ),
            ],
            if (lesson.isConfirmed) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle, size: 14, color: NestColors.mutedSage),
            ],
          ],
        ),
        if (headline.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(headline, style: theme.textTheme.bodyMedium),
        ],
        if (presenter.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '담당 $presenter',
            style: theme.textTheme.bodySmall?.copyWith(color: NestColors.clay),
          ),
        ],
        if (content.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            content,
            style: theme.textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.72),
            ),
          ),
        ],
      ],
    );
  }
}

/// 회차 목록의 한 줄 타일.
class _CourseLessonRowTile extends StatelessWidget {
  const _CourseLessonRowTile({
    required this.controller,
    required this.courseId,
    required this.row,
    required this.index,
    required this.canManage,
  });

  final NestController controller;
  final String courseId;
  final CourseLessonRow row;
  final int index;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lesson = row.lesson;
    final headline = lesson?.headline ?? '';
    final presenter = lesson?.presenter.trim() ?? '';
    final content = lesson?.content.trim() ?? '';
    final isToday = _isSameDate(row.date, DateTime.now());

    // 읽기 전용에서는 아직 내용이 없는 자리를 감춘다(학생·학부모에게 빈 줄만
    // 늘어놓지 않기 위함). 편집 권한이 있을 때는 채워 넣을 자리로 보여준다.
    if (!canManage && !row.isFilled) {
      return const SizedBox.shrink();
    }

    final tile = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isToday ? NestColors.roseMist.withValues(alpha: 0.35) : null,
        border: Border.all(
          color: row.isFilled
              ? NestColors.roseMist
              : NestColors.roseMist.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$index회',
              style: theme.textTheme.bodySmall?.copyWith(
                color: NestColors.clay,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _dateLabel(row.date),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (lesson?.isConfirmed == true) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.check_circle,
                        size: 15,
                        color: NestColors.mutedSage,
                      ),
                    ],
                    if (!row.isInTerm) ...[
                      const SizedBox(width: 6),
                      _pill(context, '학기 밖'),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (headline.isNotEmpty)
                  Text(headline, style: theme.textTheme.bodyMedium)
                else
                  Text(
                    '내용 없음',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.5),
                    ),
                  ),
                if (presenter.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '담당 $presenter',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NestColors.clay,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    content,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canManage)
            Icon(
              row.isFilled ? Icons.edit_outlined : Icons.add_circle_outline,
              size: 18,
              color: NestColors.deepWood.withValues(alpha: 0.55),
            ),
        ],
      ),
    );

    if (!canManage) {
      return tile;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: controller.isBusy
          ? null
          : () => showCourseLessonEditor(
              context: context,
              controller: controller,
              courseId: courseId,
              existing: lesson,
              initialDate: row.date,
            ),
      child: tile,
    );
  }
}

// ---------------------------------------------------------------------------
// private
// ---------------------------------------------------------------------------

Widget _pill(BuildContext context, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: NestColors.clay.withValues(alpha: 0.12),
      border: Border.all(color: NestColors.clay.withValues(alpha: 0.45)),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: NestColors.clay,
        fontWeight: FontWeight.w700,
        fontSize: 10,
      ),
    ),
  );
}

/// "통합QT · 2026 가을 · 화요일" 한 줄 요약.
String _courseHeadline(NestController controller, String courseId) {
  final weekdays = controller.courseWeekdays(courseId).toList()..sort();
  final parts = <String>[
    controller.findCourseName(courseId),
    if (controller.selectedTerm != null) controller.selectedTerm!.name,
    if (weekdays.isNotEmpty) '${weekdays.map(dayLabel).join('·')}요일',
  ];
  return parts.where((part) => part.trim().isNotEmpty).join(' · ');
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// 앱 규약(0=일)으로 변환한 요일. Dart 는 1=월 … 7=일 이라 % 7 하면 맞아떨어진다.
int _appDayOfWeek(DateTime date) => date.weekday % 7;

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 새 회차를 등록할 때 기본으로 제시할 날짜.
///
/// "그 과목의 다음 수업일"을 그대로 쓰면, 진도표를 미리 채워둔 과목에서는 그 날짜에
/// 이미 회차가 있는 것이 정상이라 열자마자 중복 경고를 보게 된다. 그래서 아직
/// 비어 있는 첫 자리를 먼저 고르고, 전부 차 있을 때만 다음 수업일로 떨어진다.
DateTime _defaultNewLessonDate(
  NestController controller,
  String courseId, {
  required Set<int> weekdays,
  required Term? term,
}) {
  final today = _dateOnly(DateTime.now());
  final rows = buildCourseLessonRows(controller, courseId);

  final empty = rows.where((row) => row.lesson == null).toList();
  final upcomingEmpty = empty
      .where((row) => !row.date.isBefore(today))
      .firstOrNull;
  final fallbackEmpty = upcomingEmpty ?? empty.firstOrNull;
  if (fallbackEmpty != null) {
    return fallbackEmpty.date;
  }

  return _nextCourseOccurrence(
    weekdays: weekdays,
    termStart: term?.startDate,
    termEnd: term?.endDate,
  );
}

/// 그 과목의 수업 요일 중 다가오는 날짜(오늘 포함). 학기 범위 안으로 잘라낸다.
///
/// 학기가 이미 끝났으면 종료일을 그대로 주지 않고 **학기 안 마지막 수업일**을 준다.
/// 종료일이 그 과목의 수업 요일이 아닐 수 있는데, 그러면 그 날짜의 회차는 존재할 수
/// 없어 "그 날의 회차" 표시가 영영 안 나오고, 같은 목적의 학부모 화면 헬퍼
/// (`parent_timetable_tab.dart` 의 datesForWeekday(...).last)와도 기준일이 갈린다.
DateTime _nextCourseOccurrence({
  required Set<int> weekdays,
  DateTime? termStart,
  DateTime? termEnd,
}) {
  var cursor = _dateOnly(DateTime.now());
  if (termStart != null) {
    final start = _dateOnly(termStart);
    if (cursor.isBefore(start)) {
      cursor = start;
    }
  }
  if (weekdays.isNotEmpty) {
    for (var i = 0; i < 7; i++) {
      if (weekdays.contains(_appDayOfWeek(cursor))) {
        break;
      }
      cursor = _dateOnly(cursor.add(const Duration(days: 1)));
    }
  }
  if (termEnd != null) {
    final end = _dateOnly(termEnd);
    if (cursor.isAfter(end)) {
      return _lastOccurrenceOnOrBefore(end, weekdays);
    }
  }
  return cursor;
}

/// [end] 이하에서 [weekdays] 에 해당하는 마지막 날짜. 못 찾으면 [end].
DateTime _lastOccurrenceOnOrBefore(DateTime end, Set<int> weekdays) {
  if (weekdays.isEmpty) {
    return end;
  }
  var cursor = _dateOnly(end);
  for (var i = 0; i < 7; i++) {
    if (weekdays.contains(_appDayOfWeek(cursor))) {
      return cursor;
    }
    cursor = _dateOnly(cursor.subtract(const Duration(days: 1)));
  }
  return _dateOnly(end);
}

/// 회차 날짜 선택. 학기 밖 날짜(보강·연장 진도)도 고를 수 있게 범위를 넓게 잡는다.
///
/// ⚠️ 선택 가능 범위는 컨트롤러가 다시 읽어오는 날짜 창
/// ([NestController.courseLessonWindowLeadDays] / [courseLessonWindowTrailDays])
/// 안에 있어야 한다. 고를 수는 있는데 refetch 에 안 잡히는 날짜가 있으면, 저장 직후
/// 그 회차가 목록에서 사라지고 같은 날짜로 다시 등록하면 유니크 위반이 난다.
Future<DateTime?> _pickLessonDate({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? termStart,
  DateTime? termEnd,
}) async {
  const lead = Duration(days: NestController.courseLessonWindowLeadDays);
  const trail = Duration(days: NestController.courseLessonWindowTrailDays);
  final initial = _dateOnly(initialDate);
  var first = _dateOnly(
    termStart ?? initial.subtract(const Duration(days: 365)),
  ).subtract(lead);
  var last = _dateOnly(
    termEnd ?? initial.add(const Duration(days: 365)),
  ).add(trail);
  if (initial.isBefore(first)) {
    first = initial;
  }
  if (initial.isAfter(last)) {
    last = initial;
  }

  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    helpText: '수업 날짜 선택',
    cancelText: '취소',
    confirmText: '확인',
  );
}

String _dateLabel(DateTime date) {
  return '${DateFormat('M월 d일').format(date)}'
      '(${dayLabel(_appDayOfWeek(date))})';
}

void _showMessage(BuildContext context, String text, {bool isFailure = false}) {
  if (!context.mounted || text.trim().isEmpty) {
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: isFailure ? Theme.of(context).colorScheme.error : null,
    ),
  );
}
