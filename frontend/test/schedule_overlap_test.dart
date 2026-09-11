import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/schedule_occurrence.dart';
import 'package:nest_frontend/src/services/schedule_overlap.dart';

PersonalEvent _event({
  required DateTime start,
  required DateTime end,
  String policy = 'KEEP_BOTH',
  String childId = 'child-1',
}) {
  return PersonalEvent(
    id: 'pe-1',
    homeschoolId: 'hs-1',
    ownerUserId: 'user-1',
    childId: childId,
    title: '피아노',
    startsAt: start,
    endsAt: end,
    conflictPolicy: policy,
  );
}

void main() {
  final monday = DateTime(2026, 9, 14);
  final slot = TimeSlot(
    id: 'slot-1',
    termId: 'term-1',
    dayOfWeek: 1,
    startTime: '09:00:00',
    endTime: '09:50:00',
  );

  test('rangesOverlap treats end as exclusive', () {
    final nine = DateTime(2026, 9, 14, 9);
    final ten = DateTime(2026, 9, 14, 10);
    final eleven = DateTime(2026, 9, 14, 11);
    expect(rangesOverlap(nine, ten, ten, eleven), isFalse);
    expect(rangesOverlap(nine, DateTime(2026, 9, 14, 10, 1), ten, eleven), isTrue);
  });

  test('personalOverlapsSlot detects class collision', () {
    final hit = _event(
      start: DateTime(2026, 9, 14, 9, 30),
      end: DateTime(2026, 9, 14, 10, 30),
    );
    final miss = _event(
      start: DateTime(2026, 9, 14, 10),
      end: DateTime(2026, 9, 14, 11),
    );
    expect(personalOverlapsSlot(event: hit, date: monday, slot: slot), isTrue);
    expect(personalOverlapsSlot(event: miss, date: monday, slot: slot), isFalse);
  });

  test('all-day academic event does not collide with a period', () {
    final event = AcademicEvent(
      id: 'ae-1',
      homeschoolId: 'hs-1',
      termId: 'term-1',
      title: '개학식',
      description: '',
      eventDate: monday,
      kind: 'CEREMONY',
    );
    expect(event.isAllDay, isTrue);
    expect(event.coversDate(monday), isTrue);
    expect(
      academicOverlapsSlot(event: event, date: monday, slot: slot),
      isFalse,
    );
  });

  test('academicEventsOverlappingSlot keeps only timed hits', () {
    final timed = AcademicEvent(
      id: 'ae-2',
      homeschoolId: 'hs-1',
      termId: 'term-1',
      title: '소방 훈련',
      description: '',
      eventDate: monday,
      kind: 'EVENT',
      startTime: '09:10:00',
      endTime: '09:40:00',
    );
    final allDay = AcademicEvent(
      id: 'ae-1',
      homeschoolId: 'hs-1',
      termId: 'term-1',
      title: '개학식',
      description: '',
      eventDate: monday,
      kind: 'CEREMONY',
    );
    final hits = academicEventsOverlappingSlot(
      events: [timed, allDay],
      date: monday,
      slot: slot,
    );
    expect(hits.map((e) => e.id), ['ae-2']);
  });

  test('academicEventsInWeek includes multi-day events that overlap', () {
    final trip = AcademicEvent(
      id: 'ae-3',
      homeschoolId: 'hs-1',
      termId: 'term-1',
      title: '현장학습',
      description: '',
      eventDate: DateTime(2026, 9, 16),
      endDate: DateTime(2026, 9, 18),
      kind: 'FIELD_TRIP',
    );
    final nextWeek = AcademicEvent(
      id: 'ae-4',
      homeschoolId: 'hs-1',
      termId: 'term-1',
      title: '방학',
      description: '',
      eventDate: DateTime(2026, 9, 21),
      kind: 'BREAK',
    );
    final week = academicEventsInWeek(
      events: [trip, nextWeek],
      weekMonday: monday,
    );
    expect(week.map((e) => e.id), ['ae-3']);
  });

  test('timed academic event collides with the matching period', () {
    final event = AcademicEvent(
      id: 'ae-2',
      homeschoolId: 'hs-1',
      termId: 'term-1',
      title: '소방 훈련',
      description: '',
      eventDate: monday,
      kind: 'EVENT',
      startTime: '09:10:00',
      endTime: '09:40:00',
    );
    expect(
      academicOverlapsSlot(event: event, date: monday, slot: slot),
      isTrue,
    );
  });

  test('PRIORITIZE_PERSONAL hides the overlapping class', () {
    final events = [
      _event(
        start: DateTime(2026, 9, 14, 9),
        end: DateTime(2026, 9, 14, 10),
        policy: 'PRIORITIZE_PERSONAL',
      ),
    ];
    expect(
      personalHidesClass(events: events, date: monday, slot: slot),
      isTrue,
    );
    expect(
      personalHidesClass(
        events: [
          _event(
            start: DateTime(2026, 9, 14, 9),
            end: DateTime(2026, 9, 14, 10),
          ),
        ],
        date: monday,
        slot: slot,
      ),
      isFalse,
    );
  });

  test('nestMondayOf and nestDateForWeekday stay on the same week', () {
    final wednesday = DateTime(2026, 9, 16);
    final weekStart = nestMondayOf(wednesday);
    expect(weekStart, DateTime(2026, 9, 14));
    expect(nestDateForWeekday(weekStart, 1), DateTime(2026, 9, 14));
    expect(nestDateForWeekday(weekStart, 0), DateTime(2026, 9, 20));
  });
}
