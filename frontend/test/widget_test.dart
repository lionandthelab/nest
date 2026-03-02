import 'package:flutter_test/flutter_test.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/local_planner.dart';

void main() {
  group('local planner', () {
    test('prioritizes courses from prompt keywords', () {
      final courses = [
        const Course(
          id: 'c1',
          homeschoolId: 'h1',
          name: '국어 기초',
          defaultDurationMin: 50,
        ),
        const Course(
          id: 'c2',
          homeschoolId: 'h1',
          name: '수학 놀이',
          defaultDurationMin: 50,
        ),
        const Course(
          id: 'c3',
          homeschoolId: 'h1',
          name: '미술 탐색',
          defaultDurationMin: 50,
        ),
      ];

      final selected = pickCoursesByPrompt(
        prompt: '화목 오전은 국어와 수학 중심으로 부탁해',
        courses: courses,
      );

      expect(selected.length, 2);
      expect(selected.first.id, 'c1');
      expect(selected[1].id, 'c2');
    });

    test('returns conflict when no free slot remains', () {
      final slots = [
        const TimeSlot(
          id: 's1',
          termId: 't1',
          dayOfWeek: 2,
          startTime: '09:30:00',
          endTime: '10:20:00',
        ),
      ];

      final existingSessions = [
        const ClassSession(
          id: 'cs1',
          classGroupId: 'g1',
          courseId: 'c1',
          timeSlotId: 's1',
          title: '국어 수업',
          sourceType: 'MANUAL',
          status: 'PLANNED',
        ),
      ];

      final draft = buildLocalProposalDraft(
        prompt: '국어 중심',
        classGroupId: 'g1',
        courses: const [
          Course(
            id: 'c1',
            homeschoolId: 'h1',
            name: '국어',
            defaultDurationMin: 50,
          ),
        ],
        timeSlots: slots,
        existingSessions: existingSessions,
      );

      expect(draft.sessions, isEmpty);
      expect(draft.hardConflicts, isNotEmpty);
      expect((draft.hardConflicts.first as Map)['code'], 'NO_FREE_SLOT');
    });
  });
}
