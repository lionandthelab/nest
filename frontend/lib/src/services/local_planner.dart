import '../models/nest_models.dart';

GeneratedProposalDraft buildLocalProposalDraft({
  required String prompt,
  required String classGroupId,
  required List<Course> courses,
  required List<TimeSlot> timeSlots,
  required List<ClassSession> existingSessions,
}) {
  final occupiedSlotIds = existingSessions
      .map((session) => session.timeSlotId)
      .toSet();

  final freeSlots =
      timeSlots
          .where((slot) => !occupiedSlotIds.contains(slot.id))
          .toList(growable: false)
        ..sort((a, b) {
          final day = a.dayOfWeek.compareTo(b.dayOfWeek);
          if (day != 0) {
            return day;
          }
          return a.startTime.compareTo(b.startTime);
        });

  final selectedCourses = pickCoursesByPrompt(prompt: prompt, courses: courses);
  final sessionCount = [
    freeSlots.length,
    selectedCourses.length,
    4,
  ].reduce(_minInt);

  final sessions = List.generate(sessionCount, (index) {
    final slot = freeSlots[index];
    final course = selectedCourses[index % selectedCourses.length];

    return GeneratedSessionDraft(
      classGroupId: classGroupId,
      courseId: course.id,
      timeSlotId: slot.id,
      teacherMainId: null,
      teacherAssistantIds: const [],
      hardConflicts: const [],
      softWarnings: const [],
    );
  });

  final hardConflicts = freeSlots.isEmpty
      ? const [
          {
            'code': 'NO_FREE_SLOT',
            'message': '비어 있는 시간 슬롯이 없어 생성안을 만들 수 없습니다.',
          },
        ]
      : const [];

  return GeneratedProposalDraft(
    source: 'local-fallback',
    sessions: sessions,
    hardConflicts: hardConflicts,
    softWarnings: const [],
  );
}

List<Course> pickCoursesByPrompt({
  required String prompt,
  required List<Course> courses,
}) {
  if (courses.isEmpty) {
    return const [];
  }

  final lowerPrompt = prompt.toLowerCase();
  final selected = <Course>[];

  final mappings = <({List<String> words, String include})>[
    (words: ['국어', '문해', '읽기', 'language'], include: '국어'),
    (words: ['수학', 'math'], include: '수학'),
    (words: ['과학', '자연', 'science'], include: '자연'),
    (words: ['미술', 'art'], include: '미술'),
  ];

  for (final mapping in mappings) {
    final foundByKeyword = mapping.words.any(lowerPrompt.contains);
    if (!foundByKeyword) {
      continue;
    }

    final course = courses
        .where((item) => item.name.contains(mapping.include))
        .firstOrNull;
    if (course != null && !selected.any((item) => item.id == course.id)) {
      selected.add(course);
    }
  }

  if (selected.isEmpty) {
    return courses.take(4).toList(growable: false);
  }

  return selected;
}

int _minInt(int a, int b) => a < b ? a : b;

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

List<ScheduleOptionDraft> buildWizardScheduleOptions({
  required String prompt,
  required String classGroupId,
  required List<Course> courses,
  required List<TimeSlot> timeSlots,
  required List<ClassSession> existingSessions,
  required List<TeacherProfile> teacherProfiles,
  required Set<int> preferredDays,
  required int sessionsPerDay,
  Set<String> blockedSlotIds = const {},
  Map<String, Set<String>> teacherBlockedSlotIdsByTeacher = const {},
  Map<String, int> courseWeightsById = const {},
  Set<String> preferredTeacherIds = const {},
  String teacherStrategy = 'BALANCED',
  bool preferOnlySelectedTeachers = false,
  int optionCount = 3,
  bool keepExistingSessions = true,
}) {
  final activeDays = preferredDays.isEmpty
      ? const <int>{1, 2, 3, 4, 5}
      : preferredDays;
  final safeSessionsPerDay = sessionsPerDay <= 0 ? 2 : sessionsPerDay;
  final safeOptionCount = optionCount <= 0 ? 1 : optionCount;

  final availableCourses = pickCoursesByPrompt(
    prompt: prompt,
    courses: courses,
  );
  final fallbackCourses = availableCourses.isEmpty ? courses : availableCourses;
  final normalizedCourseWeights = _normalizeCourseWeights(
    courses: fallbackCourses,
    courseWeightsById: courseWeightsById,
    prompt: prompt,
  );
  final weightedCoursePool = _buildWeightedCoursePool(
    courses: fallbackCourses,
    normalizedWeights: normalizedCourseWeights,
  );

  final grouped = <int, List<TimeSlot>>{};
  for (final slot in timeSlots) {
    if (!activeDays.contains(slot.dayOfWeek)) {
      continue;
    }
    grouped.putIfAbsent(slot.dayOfWeek, () => <TimeSlot>[]);
    grouped[slot.dayOfWeek]!.add(slot);
  }
  for (final rows in grouped.values) {
    rows.sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  final occupiedSlotIds = existingSessions
      .map((session) => session.timeSlotId)
      .toSet();

  if (fallbackCourses.isEmpty || grouped.isEmpty) {
    final message = fallbackCourses.isEmpty
        ? '과목이 없어 자동 초안을 생성할 수 없습니다.'
        : '선택한 요일에 시간 슬롯이 없습니다.';
    return [
      ScheduleOptionDraft(
        id: 'option-1',
        label: '안 1',
        prompt: prompt,
        sessions: const [],
        issues: [
          ScheduleDraftIssue(
            code: 'WIZARD_INPUT_EMPTY',
            message: message,
            severity: 'HARD',
            sessionLocalId: null,
          ),
        ],
      ),
    ];
  }

  final dayOrder = grouped.keys.toList(growable: false)..sort();
  final options = <ScheduleOptionDraft>[];

  for (var optionIndex = 0; optionIndex < safeOptionCount; optionIndex += 1) {
    final rotatedDays = _rotateList(dayOrder, optionIndex);
    final slotPool = <TimeSlot>[];

    for (final day in rotatedDays) {
      final daySlots = grouped[day] ?? const <TimeSlot>[];
      final rotatedDaySlots = _rotateList(
        daySlots,
        optionIndex % daySlots.lengthOrOne,
      );
      final capped = rotatedDaySlots.take(safeSessionsPerDay);
      slotPool.addAll(capped);
    }

    final filteredSlotPool = keepExistingSessions
        ? slotPool
              .where((slot) => !occupiedSlotIds.contains(slot.id))
              .toList(growable: false)
        : slotPool;
    final feasibleSlotPool = filteredSlotPool
        .where((slot) => !blockedSlotIds.contains(slot.id))
        .toList(growable: false);

    final estimatedSessionCount = _minInt(
      feasibleSlotPool.length,
      fallbackCourses.length * 3,
    );

    final sessions = <ScheduleOptionSession>[];
    final teacherLoad = <String, int>{};
    final teacherBySlot = <String, Set<String>>{};

    for (var i = 0; i < estimatedSessionCount; i += 1) {
      final slot = feasibleSlotPool[i];
      final course =
          weightedCoursePool[(i + optionIndex) % weightedCoursePool.length];
      final teacher = _pickTeacherForSlot(
        teachers: teacherProfiles,
        teacherLoad: teacherLoad,
        teacherBySlot: teacherBySlot,
        slotId: slot.id,
        course: course,
        preferredTeacherIds: preferredTeacherIds,
        strategy: teacherStrategy,
        preferOnlySelectedTeachers: preferOnlySelectedTeachers,
        teacherBlockedSlotIdsByTeacher: teacherBlockedSlotIdsByTeacher,
        seed: optionIndex + i,
      );

      sessions.add(
        ScheduleOptionSession(
          localId: 'o${optionIndex + 1}-s${i + 1}',
          classGroupId: classGroupId,
          courseId: course.id,
          timeSlotId: slot.id,
          teacherMainId: teacher?.id,
        ),
      );
    }

    final issues = evaluateScheduleOptionIssues(
      sessions: sessions,
      existingSessions: keepExistingSessions ? existingSessions : const [],
      requireTeacher: true,
      blockedSlotIdsForParents: blockedSlotIds,
      teacherBlockedSlotIdsByTeacher: teacherBlockedSlotIdsByTeacher,
    );

    options.add(
      ScheduleOptionDraft(
        id: 'option-${optionIndex + 1}',
        label: '안 ${optionIndex + 1}',
        prompt: prompt,
        sessions: sessions,
        issues: issues,
      ),
    );
  }

  return options;
}

List<ScheduleDraftIssue> evaluateScheduleOptionIssues({
  required List<ScheduleOptionSession> sessions,
  required List<ClassSession> existingSessions,
  bool requireTeacher = false,
  Set<String> blockedSlotIdsForParents = const {},
  Map<String, Set<String>> teacherBlockedSlotIdsByTeacher = const {},
}) {
  final issues = <ScheduleDraftIssue>[];

  final occupiedSlots = existingSessions
      .map((session) => session.timeSlotId)
      .toSet();

  final sessionsBySlot = <String, List<ScheduleOptionSession>>{};
  final sessionsByTeacherSlot = <String, List<ScheduleOptionSession>>{};

  for (final session in sessions) {
    sessionsBySlot.putIfAbsent(
      session.timeSlotId,
      () => <ScheduleOptionSession>[],
    );
    sessionsBySlot[session.timeSlotId]!.add(session);

    if (occupiedSlots.contains(session.timeSlotId)) {
      issues.add(
        ScheduleDraftIssue(
          code: 'SLOT_OCCUPIED',
          message: '이미 사용 중인 시간 슬롯입니다.',
          severity: 'HARD',
          sessionLocalId: session.localId,
        ),
      );
    }

    if (blockedSlotIdsForParents.contains(session.timeSlotId)) {
      issues.add(
        ScheduleDraftIssue(
          code: 'PARENT_SLOT_UNAVAILABLE',
          message: '부모 불가 시간대와 충돌합니다.',
          severity: 'HARD',
          sessionLocalId: session.localId,
        ),
      );
    }

    final teacherId = session.teacherMainId?.trim() ?? '';
    if (requireTeacher && teacherId.isEmpty) {
      issues.add(
        ScheduleDraftIssue(
          code: 'MAIN_TEACHER_MISSING',
          message: '주강사가 지정되지 않았습니다.',
          severity: 'WARN',
          sessionLocalId: session.localId,
        ),
      );
    }

    if (teacherId.isNotEmpty) {
      final blockedSlots = teacherBlockedSlotIdsByTeacher[teacherId];
      if (blockedSlots != null && blockedSlots.contains(session.timeSlotId)) {
        issues.add(
          ScheduleDraftIssue(
            code: 'TEACHER_SLOT_UNAVAILABLE',
            message: '교사 불가 시간대와 충돌합니다.',
            severity: 'HARD',
            sessionLocalId: session.localId,
          ),
        );
      }
      final key = '$teacherId::${session.timeSlotId}';
      sessionsByTeacherSlot.putIfAbsent(key, () => <ScheduleOptionSession>[]);
      sessionsByTeacherSlot[key]!.add(session);
    }
  }

  for (final entry in sessionsBySlot.entries) {
    if (entry.value.length < 2) {
      continue;
    }
    for (final conflicted in entry.value) {
      issues.add(
        ScheduleDraftIssue(
          code: 'SLOT_DUPLICATED',
          message: '같은 슬롯에 수업이 중복 배치되었습니다.',
          severity: 'HARD',
          sessionLocalId: conflicted.localId,
        ),
      );
    }
  }

  for (final entry in sessionsByTeacherSlot.entries) {
    if (entry.value.length < 2) {
      continue;
    }
    for (final conflicted in entry.value) {
      issues.add(
        ScheduleDraftIssue(
          code: 'TEACHER_SLOT_CONFLICT',
          message: '같은 시간에 동일 교사가 중복 배정되었습니다.',
          severity: 'HARD',
          sessionLocalId: conflicted.localId,
        ),
      );
    }
  }

  return issues;
}

TeacherProfile? _pickTeacherForSlot({
  required List<TeacherProfile> teachers,
  required Map<String, int> teacherLoad,
  required Map<String, Set<String>> teacherBySlot,
  required String slotId,
  required Course course,
  required Set<String> preferredTeacherIds,
  required String strategy,
  required bool preferOnlySelectedTeachers,
  required Map<String, Set<String>> teacherBlockedSlotIdsByTeacher,
  required int seed,
}) {
  if (teachers.isEmpty) {
    return null;
  }

  final selectedTeachers = preferOnlySelectedTeachers
      ? teachers
            .where((teacher) => preferredTeacherIds.contains(teacher.id))
            .toList(growable: false)
      : teachers.toList(growable: false);

  if (selectedTeachers.isEmpty) {
    return null;
  }

  final sorted = selectedTeachers.toList(growable: false)
    ..sort((a, b) {
      final leftScore = _teacherPriorityScore(
        teacher: a,
        course: course,
        preferredTeacherIds: preferredTeacherIds,
        strategy: strategy,
      );
      final rightScore = _teacherPriorityScore(
        teacher: b,
        course: course,
        preferredTeacherIds: preferredTeacherIds,
        strategy: strategy,
      );
      if (leftScore != rightScore) {
        return rightScore.compareTo(leftScore);
      }

      final leftLoad = teacherLoad[a.id] ?? 0;
      final rightLoad = teacherLoad[b.id] ?? 0;
      if (leftLoad != rightLoad) {
        return leftLoad.compareTo(rightLoad);
      }
      return a.displayName.compareTo(b.displayName);
    });

  final rotated = _rotateList(sorted, seed % sorted.lengthOrOne);
  final occupied = teacherBySlot[slotId] ?? <String>{};

  for (final teacher in rotated) {
    if (occupied.contains(teacher.id)) {
      continue;
    }
    final blocked = teacherBlockedSlotIdsByTeacher[teacher.id];
    if (blocked != null && blocked.contains(slotId)) {
      continue;
    }
    teacherLoad[teacher.id] = (teacherLoad[teacher.id] ?? 0) + 1;
    occupied.add(teacher.id);
    teacherBySlot[slotId] = occupied;
    return teacher;
  }

  return null;
}

Map<String, int> _normalizeCourseWeights({
  required List<Course> courses,
  required Map<String, int> courseWeightsById,
  required String prompt,
}) {
  final normalized = <String, int>{};
  for (final course in courses) {
    final fromUi = courseWeightsById[course.id] ?? 0;
    final fromPrompt = _inferPromptBoost(
      prompt: prompt,
      courseName: course.name,
    );
    final weight = fromUi > 0 ? fromUi : (1 + fromPrompt);
    normalized[course.id] = weight.clamp(1, 5);
  }
  return normalized;
}

List<Course> _buildWeightedCoursePool({
  required List<Course> courses,
  required Map<String, int> normalizedWeights,
}) {
  final pool = <Course>[];
  for (final course in courses) {
    final weight = (normalizedWeights[course.id] ?? 1).clamp(1, 5);
    for (var i = 0; i < weight; i += 1) {
      pool.add(course);
    }
  }
  return pool.isEmpty ? courses : pool;
}

int _inferPromptBoost({required String prompt, required String courseName}) {
  final normalizedPrompt = prompt.trim().toLowerCase();
  if (normalizedPrompt.isEmpty) {
    return 0;
  }

  final loweredCourse = courseName.toLowerCase();
  if (normalizedPrompt.contains(loweredCourse)) {
    return 2;
  }

  final keywordsByCourse = <String, List<String>>{
    '국어': ['국어', '문해', '읽기', '독서', 'language'],
    '수학': ['수학', 'math', '계산'],
    '자연': ['자연', '과학', 'science', '탐구'],
    '미술': ['미술', 'art', '그림'],
  };

  for (final entry in keywordsByCourse.entries) {
    final key = entry.key.toLowerCase();
    if (!loweredCourse.contains(key)) {
      continue;
    }
    final matched = entry.value.any(
      (keyword) => normalizedPrompt.contains(keyword.toLowerCase()),
    );
    if (matched) {
      return 1;
    }
  }

  return 0;
}

int _teacherPriorityScore({
  required TeacherProfile teacher,
  required Course course,
  required Set<String> preferredTeacherIds,
  required String strategy,
}) {
  var score = 0;

  if (preferredTeacherIds.contains(teacher.id)) {
    score += 5;
  }

  if (strategy == 'PREFERRED_FIRST' &&
      preferredTeacherIds.contains(teacher.id)) {
    score += 7;
  }

  if (strategy == 'PARENT_FIRST' && teacher.teacherType == 'PARENT_TEACHER') {
    score += 7;
  }

  final lowerName = course.name.toLowerCase();
  final specialtyMatched = teacher.specialties.any(
    (specialty) => specialty.toLowerCase().contains(lowerName),
  );
  if (specialtyMatched) {
    score += 3;
  }

  return score;
}

List<T> _rotateList<T>(List<T> rows, int offset) {
  if (rows.isEmpty) {
    return const [];
  }
  final safeOffset = offset % rows.length;
  if (safeOffset == 0) {
    return rows.toList(growable: false);
  }
  return [...rows.skip(safeOffset), ...rows.take(safeOffset)];
}

extension _ListLengthOrOne<T> on List<T> {
  int get lengthOrOne => isEmpty ? 1 : length;
}
