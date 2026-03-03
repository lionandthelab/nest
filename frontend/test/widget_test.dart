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

    test('builds multiple wizard schedule options', () {
      final slots = [
        const TimeSlot(
          id: 's1',
          termId: 't1',
          dayOfWeek: 1,
          startTime: '09:30:00',
          endTime: '10:20:00',
        ),
        const TimeSlot(
          id: 's2',
          termId: 't1',
          dayOfWeek: 1,
          startTime: '10:30:00',
          endTime: '11:20:00',
        ),
        const TimeSlot(
          id: 's3',
          termId: 't1',
          dayOfWeek: 2,
          startTime: '09:30:00',
          endTime: '10:20:00',
        ),
      ];

      final courses = [
        const Course(
          id: 'c1',
          homeschoolId: 'h1',
          name: '국어',
          defaultDurationMin: 50,
        ),
        const Course(
          id: 'c2',
          homeschoolId: 'h1',
          name: '수학',
          defaultDurationMin: 50,
        ),
      ];

      final teachers = [
        const TeacherProfile(
          id: 't1',
          homeschoolId: 'h1',
          userId: 'u1',
          displayName: 'Teacher A',
          teacherType: 'TEACHER',
          specialties: [],
          bio: '',
          createdAt: null,
        ),
        const TeacherProfile(
          id: 't2',
          homeschoolId: 'h1',
          userId: 'u2',
          displayName: 'Teacher B',
          teacherType: 'TEACHER',
          specialties: [],
          bio: '',
          createdAt: null,
        ),
      ];

      final drafts = buildWizardScheduleOptions(
        prompt: '국어 수학 중심',
        classGroupId: 'g1',
        courses: courses,
        timeSlots: slots,
        existingSessions: const [],
        teacherProfiles: teachers,
        preferredDays: const {1, 2},
        sessionsPerDay: 2,
        optionCount: 3,
        keepExistingSessions: true,
      );

      expect(drafts.length, 3);
      expect(drafts.every((draft) => draft.sessions.isNotEmpty), isTrue);
      expect(drafts.any((draft) => draft.hasHardConflicts), isFalse);
    });

    test('applies course frequency weights to draft distribution', () {
      final slots = [
        const TimeSlot(
          id: 's1',
          termId: 't1',
          dayOfWeek: 1,
          startTime: '09:30:00',
          endTime: '10:20:00',
        ),
        const TimeSlot(
          id: 's2',
          termId: 't1',
          dayOfWeek: 1,
          startTime: '10:30:00',
          endTime: '11:20:00',
        ),
        const TimeSlot(
          id: 's3',
          termId: 't1',
          dayOfWeek: 2,
          startTime: '09:30:00',
          endTime: '10:20:00',
        ),
        const TimeSlot(
          id: 's4',
          termId: 't1',
          dayOfWeek: 2,
          startTime: '10:30:00',
          endTime: '11:20:00',
        ),
      ];

      final courses = [
        const Course(
          id: 'c1',
          homeschoolId: 'h1',
          name: '국어',
          defaultDurationMin: 50,
        ),
        const Course(
          id: 'c2',
          homeschoolId: 'h1',
          name: '수학',
          defaultDurationMin: 50,
        ),
      ];

      final drafts = buildWizardScheduleOptions(
        prompt: '균형 편성',
        classGroupId: 'g1',
        courses: courses,
        timeSlots: slots,
        existingSessions: const [],
        teacherProfiles: const [],
        preferredDays: const {1, 2},
        sessionsPerDay: 2,
        optionCount: 1,
        courseWeightsById: const {'c1': 3, 'c2': 1},
      );

      final sessions = drafts.single.sessions;
      final koreanCount = sessions.where((row) => row.courseId == 'c1').length;
      final mathCount = sessions.where((row) => row.courseId == 'c2').length;

      expect(koreanCount, greaterThan(mathCount));
    });

    test('respects preferred teachers when strict mode is enabled', () {
      final slots = [
        const TimeSlot(
          id: 's1',
          termId: 't1',
          dayOfWeek: 1,
          startTime: '09:30:00',
          endTime: '10:20:00',
        ),
        const TimeSlot(
          id: 's2',
          termId: 't1',
          dayOfWeek: 2,
          startTime: '09:30:00',
          endTime: '10:20:00',
        ),
      ];

      final teachers = [
        const TeacherProfile(
          id: 't1',
          homeschoolId: 'h1',
          userId: 'u1',
          displayName: 'Teacher Preferred',
          teacherType: 'TEACHER',
          specialties: [],
          bio: '',
          createdAt: null,
        ),
        const TeacherProfile(
          id: 't2',
          homeschoolId: 'h1',
          userId: 'u2',
          displayName: 'Teacher Other',
          teacherType: 'TEACHER',
          specialties: [],
          bio: '',
          createdAt: null,
        ),
      ];

      final drafts = buildWizardScheduleOptions(
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
        existingSessions: const [],
        teacherProfiles: teachers,
        preferredDays: const {1, 2},
        sessionsPerDay: 1,
        optionCount: 1,
        preferredTeacherIds: const {'t1'},
        teacherStrategy: 'PREFERRED_FIRST',
        preferOnlySelectedTeachers: true,
      );

      expect(
        drafts.single.sessions.every(
          (session) => session.teacherMainId == 't1',
        ),
        isTrue,
      );
    });

    test('avoids parent blocked slots when building drafts', () {
      final slots = [
        const TimeSlot(
          id: 's1',
          termId: 't1',
          dayOfWeek: 1,
          startTime: '09:30:00',
          endTime: '10:20:00',
        ),
        const TimeSlot(
          id: 's2',
          termId: 't1',
          dayOfWeek: 1,
          startTime: '10:30:00',
          endTime: '11:20:00',
        ),
      ];

      final drafts = buildWizardScheduleOptions(
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
        existingSessions: const [],
        teacherProfiles: const [],
        preferredDays: const {1},
        sessionsPerDay: 2,
        optionCount: 1,
        blockedSlotIds: const {'s1'},
      );

      expect(
        drafts.single.sessions.any((session) => session.timeSlotId == 's1'),
        isFalse,
      );
      expect(
        drafts.single.sessions.any((session) => session.timeSlotId == 's2'),
        isTrue,
      );
    });

    test('flags teacher unavailable slot conflicts in issue evaluator', () {
      final issues = evaluateScheduleOptionIssues(
        sessions: const [
          ScheduleOptionSession(
            localId: 'local-1',
            classGroupId: 'g1',
            courseId: 'c1',
            timeSlotId: 'slot-1',
            teacherMainId: 'teacher-1',
          ),
        ],
        existingSessions: const [],
        requireTeacher: true,
        teacherBlockedSlotIdsByTeacher: const {
          'teacher-1': {'slot-1'},
        },
      );

      expect(
        issues.any((issue) => issue.code == 'TEACHER_SLOT_UNAVAILABLE'),
        isTrue,
      );
    });

    test('detects duplicate slot and teacher conflicts in draft issues', () {
      final sessions = [
        const ScheduleOptionSession(
          localId: 's1',
          classGroupId: 'g1',
          courseId: 'c1',
          timeSlotId: 'slot-a',
          teacherMainId: 'teacher-1',
        ),
        const ScheduleOptionSession(
          localId: 's2',
          classGroupId: 'g1',
          courseId: 'c2',
          timeSlotId: 'slot-a',
          teacherMainId: 'teacher-1',
        ),
      ];

      final issues = evaluateScheduleOptionIssues(
        sessions: sessions,
        existingSessions: const [],
        requireTeacher: true,
      );

      final codes = issues.map((issue) => issue.code).toSet();
      expect(codes, contains('SLOT_DUPLICATED'));
      expect(codes, contains('TEACHER_SLOT_CONFLICT'));
    });
  });
}
