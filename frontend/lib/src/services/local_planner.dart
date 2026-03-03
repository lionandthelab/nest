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

    final estimatedSessionCount = _minInt(
      filteredSlotPool.length,
      fallbackCourses.length * 3,
    );

    final sessions = <ScheduleOptionSession>[];
    final teacherLoad = <String, int>{};
    final teacherBySlot = <String, Set<String>>{};

    for (var i = 0; i < estimatedSessionCount; i += 1) {
      final slot = filteredSlotPool[i];
      final course =
          fallbackCourses[(i + optionIndex) % fallbackCourses.length];
      final teacher = _pickTeacherForSlot(
        teachers: teacherProfiles,
        teacherLoad: teacherLoad,
        teacherBySlot: teacherBySlot,
        slotId: slot.id,
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
  required int seed,
}) {
  if (teachers.isEmpty) {
    return null;
  }

  final sorted = teachers.toList(growable: false)
    ..sort((a, b) {
      final left = teacherLoad[a.id] ?? 0;
      final right = teacherLoad[b.id] ?? 0;
      if (left != right) {
        return left.compareTo(right);
      }
      return a.displayName.compareTo(b.displayName);
    });

  final rotated = _rotateList(sorted, seed % sorted.lengthOrOne);
  final occupied = teacherBySlot[slotId] ?? <String>{};

  for (final teacher in rotated) {
    if (occupied.contains(teacher.id)) {
      continue;
    }
    teacherLoad[teacher.id] = (teacherLoad[teacher.id] ?? 0) + 1;
    occupied.add(teacher.id);
    teacherBySlot[slotId] = occupied;
    return teacher;
  }

  return null;
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
