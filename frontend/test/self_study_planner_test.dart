import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/self_study_planner.dart';

void main() {
  group('generateSelfStudySlots', () {
    test(
      'JOY 수요일 그라운드 트루스: 초2 9-10, 초5 9:30-11, 초6 11-12 공강을 재현',
      () {
        // 창 09:00-12:00 (540-720), 최소 공강 60분, 수요일(day=3).
        final occupancy = <GroupOccupancy>[
          // 초2: 창2장 10-11, 소리영어 11-12 → 병합 10-12. 공강 9-10.
          const GroupOccupancy(
              classGroupId: '초2', dayOfWeek: 3, startMin: 600, endMin: 660),
          const GroupOccupancy(
              classGroupId: '초2', dayOfWeek: 3, startMin: 660, endMin: 720),
          // 초5: 말씀선포 9-9:30, 한자 11-12 → 공강 9:30-11.
          const GroupOccupancy(
              classGroupId: '초5', dayOfWeek: 3, startMin: 540, endMin: 570),
          const GroupOccupancy(
              classGroupId: '초5', dayOfWeek: 3, startMin: 660, endMin: 720),
          // 초6A: 한자 9-10, 소리영어 10-11 → 공강 11-12.
          const GroupOccupancy(
              classGroupId: '초6A', dayOfWeek: 3, startMin: 540, endMin: 600),
          const GroupOccupancy(
              classGroupId: '초6A', dayOfWeek: 3, startMin: 600, endMin: 660),
        ];

        final slots = generateSelfStudySlots(
          classGroupIds: ['초2', '초5', '초6A'],
          occupancy: occupancy,
          config: const SelfStudyPlanConfig(
            days: [3],
            windowStartMin: 540,
            windowEndMin: 720,
            minGapMinutes: 60,
          ),
        );

        final tuples = slots
            .map((s) => '${s.classGroupId}:${s.startMin}-${s.endMin}')
            .toList();
        expect(tuples, [
          '초2:540-600', // 9-10
          '초5:570-660', // 9:30-11
          '초6A:660-720', // 11-12
        ]);
      },
    );

    test('수업이 없는 반은 창 전체가 하나의 자습 슬롯', () {
      final slots = generateSelfStudySlots(
        classGroupIds: ['초1'],
        occupancy: const [],
        config: const SelfStudyPlanConfig(
          days: [1],
          windowStartMin: 540,
          windowEndMin: 720,
          minGapMinutes: 60,
        ),
      );
      expect(slots.length, 1);
      expect(slots.first.startMin, 540);
      expect(slots.first.endMin, 720);
    });

    test('최소 공강보다 짧은 빈 시간은 슬롯으로 만들지 않음', () {
      // 9-9:30 만 비고 나머지는 수업 → 30분 공강 < 60분 → 슬롯 없음.
      final slots = generateSelfStudySlots(
        classGroupIds: ['초9'],
        occupancy: const [
          GroupOccupancy(
              classGroupId: '초9', dayOfWeek: 2, startMin: 570, endMin: 720),
        ],
        config: const SelfStudyPlanConfig(
          days: [2],
          windowStartMin: 540,
          windowEndMin: 720,
          minGapMinutes: 60,
        ),
      );
      expect(slots, isEmpty);
    });

    test('창 밖의 수업은 무시하고, 창 경계로 클램프', () {
      // 창 9-12 인데 수업이 8-10, 11-13 → 클램프 후 공강 10-11.
      final slots = generateSelfStudySlots(
        classGroupIds: ['초x'],
        occupancy: const [
          GroupOccupancy(
              classGroupId: '초x', dayOfWeek: 4, startMin: 480, endMin: 600),
          GroupOccupancy(
              classGroupId: '초x', dayOfWeek: 4, startMin: 660, endMin: 780),
        ],
        config: const SelfStudyPlanConfig(
          days: [4],
          windowStartMin: 540,
          windowEndMin: 720,
          minGapMinutes: 60,
        ),
      );
      expect(slots.length, 1);
      expect(slots.first.startMin, 600);
      expect(slots.first.endMin, 660);
    });
  });

  group('self-study helpers', () {
    test('gradeLabelForGroupName', () {
      expect(gradeLabelForGroupName('초3'), '3학년');
      expect(gradeLabelForGroupName('초6A'), '6학년');
      expect(gradeLabelForGroupName('중2A'), '중2');
      expect(gradeLabelForGroupName('중3J'), '중3');
      expect(gradeLabelForGroupName('고1'), '고1');
      expect(gradeLabelForGroupName('특별반'), '특별반');
    });

    test('minutesFromTime / timeFromMinutes', () {
      expect(minutesFromTime('09:30:00'), 570);
      expect(minutesFromTime('12:00'), 720);
      expect(timeFromMinutes(570, withSeconds: true), '09:30:00');
      expect(timeFromMinutes(720), '12:00');
    });

    test('rangeLabel', () {
      expect(rangeLabel(540, 600), '9-10시');
      expect(rangeLabel(570, 660), '9:30-11시');
    });

    test('hourBands 정각 경계 분할', () {
      expect(hourBands(540, 720), [
        [540, 600],
        [600, 660],
        [660, 720],
      ]);
      expect(hourBands(570, 660), [
        [570, 600],
        [600, 660],
      ]);
    });

    test('halfHourBands 30분 경계 분할', () {
      // 9-10 → 9:00-9:30, 9:30-10:00
      expect(halfHourBands(540, 600), [
        [540, 570],
        [570, 600],
      ]);
      // 9-12 → 30분 6칸
      expect(halfHourBands(540, 720), [
        [540, 570],
        [570, 600],
        [600, 630],
        [630, 660],
        [660, 690],
        [690, 720],
      ]);
      // 9:30-11 → 30분 경계에 정렬
      expect(halfHourBands(570, 660), [
        [570, 600],
        [600, 630],
        [630, 660],
      ]);
    });

    test('datesForWeekday: 2026년 7월 월요일 = 7/6,13,20,27', () {
      final mondays = datesForWeekday(
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 31),
        1, // 월
      );
      expect(mondays.map((d) => d.day).toList(), [6, 13, 20, 27]);
    });
  });

  group('self-study model fromMap', () {
    test('SelfStudyPlan.fromMap', () {
      final plan = SelfStudyPlan.fromMap({
        'id': 'p1',
        'term_id': 't1',
        'name': '7월 공과 자습',
        'days': [1, 2, 3, 4, 5],
        'window_start': '09:00:00',
        'window_end': '12:00:00',
        'period_start': '2026-07-01',
        'period_end': '2026-07-31',
        'min_gap_minutes': 60,
        'note': '샘플',
      });
      expect(plan.id, 'p1');
      expect(plan.days, [1, 2, 3, 4, 5]);
      expect(plan.windowStart, '09:00:00');
      expect(plan.minGapMinutes, 60);
      expect(plan.periodStart?.year, 2026);
      expect(plan.periodStart?.month, 7);
      expect(plan.periodStart?.day, 1);
    });

    test('SelfStudySlot.fromMap', () {
      final slot = SelfStudySlot.fromMap({
        'id': 's1',
        'plan_id': 'p1',
        'class_group_id': 'g1',
        'day_of_week': 3,
        'start_time': '09:00:00',
        'end_time': '10:00:00',
        'room': '아이작',
        'supervisor_teacher_id': null,
        'label': '초2 자습',
        'sort_order': 300540,
      });
      expect(slot.classGroupId, 'g1');
      expect(slot.dayOfWeek, 3);
      expect(slot.room, '아이작');
      expect(slot.supervisorTeacherId, isNull);
      expect(slot.sortOrder, 300540);
    });

    test('SelfStudySlotExclusion.fromMap', () {
      final ex = SelfStudySlotExclusion.fromMap({
        'id': 'e1',
        'slot_id': 's1',
        'child_id': 'c1',
      });
      expect(ex.slotId, 's1');
      expect(ex.childId, 'c1');
    });
  });
}
