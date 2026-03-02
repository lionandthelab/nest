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
