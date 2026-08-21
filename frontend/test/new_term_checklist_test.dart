import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/ui/models/new_term_checklist.dart';

/// 아무것도 준비되지 않은 홈스쿨.
NewTermChecklist emptyChecklist({bool hasTerm = false}) {
  return buildNewTermChecklist(
    hasTerm: hasTerm,
    familyCount: 0,
    childCount: 0,
    teacherCount: 0,
    classGroupCount: 0,
    enrollmentCount: 0,
    courseCount: 0,
    classroomCount: 0,
    timeSlotCount: 0,
    sessionCount: 0,
    academicEventCount: 0,
    announcementCount: 0,
  );
}

/// 신학기 준비가 모두 끝난 홈스쿨.
NewTermChecklist fullChecklist() {
  return buildNewTermChecklist(
    hasTerm: true,
    familyCount: 3,
    childCount: 5,
    teacherCount: 2,
    classGroupCount: 2,
    enrollmentCount: 5,
    courseCount: 4,
    classroomCount: 2,
    timeSlotCount: 6,
    sessionCount: 12,
    academicEventCount: 1,
    announcementCount: 1,
  );
}

NewTermStep stepById(NewTermChecklist checklist, String id) =>
    checklist.steps.firstWhere((step) => step.id == id);

void main() {
  group('buildNewTermChecklist', () {
    test('빈 홈스쿨은 진행률 0이고 첫 단계가 학기 만들기다', () {
      final checklist = emptyChecklist();

      expect(checklist.completedCount, 0);
      expect(checklist.progress, 0);
      expect(checklist.isComplete, isFalse);
      expect(checklist.nextStep?.id, 'term');
    });

    test('선택 단계(교실)는 진행률 분모에서 빠진다', () {
      final checklist = emptyChecklist();

      expect(stepById(checklist, 'classroom').optional, isTrue);
      expect(checklist.totalCount, checklist.steps.length - 1);
      expect(
        checklist.requiredSteps.any((step) => step.id == 'classroom'),
        isFalse,
      );
    });

    test('학기가 없으면 반·시간표·학사일정 단계가 잠긴다', () {
      final checklist = emptyChecklist();

      expect(stepById(checklist, 'class').state, NewTermStepState.blocked);
      expect(stepById(checklist, 'timetable').state, NewTermStepState.blocked);
      expect(stepById(checklist, 'event').state, NewTermStepState.blocked);

      // 홈스쿨 단위 데이터는 학기가 없어도 미리 준비할 수 있다.
      expect(stepById(checklist, 'family').state, NewTermStepState.ready);
      expect(stepById(checklist, 'teacher').state, NewTermStepState.ready);
      expect(stepById(checklist, 'course').state, NewTermStepState.ready);
      expect(
        stepById(checklist, 'announcement').state,
        NewTermStepState.ready,
      );
    });

    test('학기를 만들면 학기 종속 단계가 열린다', () {
      final checklist = emptyChecklist(hasTerm: true);

      expect(stepById(checklist, 'term').state, NewTermStepState.done);
      expect(stepById(checklist, 'class').state, NewTermStepState.ready);
      expect(stepById(checklist, 'event').state, NewTermStepState.ready);
      expect(checklist.nextStep?.id, 'family');
    });

    test('반·과목·시간 슬롯이 모두 있어야 시간표 단계가 열린다', () {
      NewTermChecklist withCounts({
        required int classGroupCount,
        required int courseCount,
        required int timeSlotCount,
      }) {
        return buildNewTermChecklist(
          hasTerm: true,
          familyCount: 1,
          childCount: 1,
          teacherCount: 1,
          classGroupCount: classGroupCount,
          enrollmentCount: 1,
          courseCount: courseCount,
          classroomCount: 0,
          timeSlotCount: timeSlotCount,
          sessionCount: 0,
          academicEventCount: 0,
          announcementCount: 0,
        );
      }

      expect(
        stepById(
          withCounts(classGroupCount: 1, courseCount: 1, timeSlotCount: 0),
          'timetable',
        ).state,
        NewTermStepState.blocked,
      );
      expect(
        stepById(
          withCounts(classGroupCount: 0, courseCount: 1, timeSlotCount: 4),
          'timetable',
        ).state,
        NewTermStepState.blocked,
      );
      expect(
        stepById(
          withCounts(classGroupCount: 1, courseCount: 1, timeSlotCount: 4),
          'timetable',
        ).state,
        NewTermStepState.ready,
      );
    });

    test('반은 만들었지만 배정이 없으면 아직 완료가 아니다', () {
      final checklist = buildNewTermChecklist(
        hasTerm: true,
        familyCount: 1,
        childCount: 2,
        teacherCount: 1,
        classGroupCount: 2,
        enrollmentCount: 0,
        courseCount: 1,
        classroomCount: 0,
        timeSlotCount: 4,
        sessionCount: 0,
        academicEventCount: 0,
        announcementCount: 0,
      );

      expect(stepById(checklist, 'class').completed, isFalse);
      expect(stepById(checklist, 'class').state, NewTermStepState.ready);
    });

    test('모두 준비되면 완료 상태가 되고 다음 단계가 없다', () {
      final checklist = fullChecklist();

      expect(checklist.isComplete, isTrue);
      expect(checklist.progress, 1);
      expect(checklist.nextStep, isNull);
      expect(checklist.remainingSteps, isEmpty);
    });

    test('필수 단계가 끝나면 남은 선택 단계를 다음 단계로 제안한다', () {
      final checklist = buildNewTermChecklist(
        hasTerm: true,
        familyCount: 1,
        childCount: 1,
        teacherCount: 1,
        classGroupCount: 1,
        enrollmentCount: 1,
        courseCount: 1,
        classroomCount: 0, // 선택 단계만 미완료
        timeSlotCount: 4,
        sessionCount: 3,
        academicEventCount: 1,
        announcementCount: 1,
      );

      expect(checklist.isComplete, isTrue);
      expect(checklist.nextStep?.id, 'classroom');
    });

    test('모든 단계의 이동 대상 탭·섹션이 채워져 있다', () {
      final checklist = fullChecklist();

      for (final step in checklist.steps) {
        if (step.id == 'term') {
          // 학기 만들기는 탭 이동 대신 학기 편집 다이얼로그를 연다.
          expect(step.targetTab, isNull);
          continue;
        }
        expect(step.targetTab, isNotNull, reason: '${step.id} 단계에 대상 탭이 없음');
        expect(
          step.targetSection,
          isNotNull,
          reason: '${step.id} 단계에 대상 섹션이 없음',
        );
      }
    });
  });
}
