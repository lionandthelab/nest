import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/schedule_occurrence.dart';

TimeSlot _slot({
  required String id,
  required int dayOfWeek,
  String start = '09:00:00',
  String end = '10:00:00',
}) {
  return TimeSlot(
    id: id,
    termId: 't-1',
    dayOfWeek: dayOfWeek,
    startTime: start,
    endTime: end,
  );
}

ClassSession _session({
  required String id,
  required String slotId,
}) {
  return ClassSession(
    id: id,
    classGroupId: 'g-1',
    courseId: 'c-1',
    timeSlotId: slotId,
    title: '수업',
    sourceType: 'MANUAL',
    status: 'PLANNED',
    location: '2층',
  );
}

void main() {
  final tuesday = DateTime(2026, 9, 8); // 화요일, nestDayOfWeek = 2

  test('nestDayOfWeek uses 0 = Sunday', () {
    expect(nestDayOfWeek(DateTime(2026, 9, 6)), 0);
    expect(nestDayOfWeek(tuesday), 2);
  });

  test('resolveOccurrencesOn skips canceled sessions', () {
    final sessions = [_session(id: 's-1', slotId: 'slot-tue')];
    final slots = {
      'slot-tue': _slot(id: 'slot-tue', dayOfWeek: 2),
    };
    final changes = [
      ClassSessionChange(
        id: 'ch-1',
        classSessionId: 's-1',
        changeType: 'CANCELED',
        effectiveFrom: tuesday,
        effectiveTo: tuesday,
      ),
    ];

    final rows = resolveOccurrencesOn(
      date: tuesday,
      sessions: sessions,
      slotsById: slots,
      changes: changes,
    );
    expect(rows, hasLength(1));
    expect(rows.first.isCanceled, isTrue);
  });

  test('TIME_MOVED uses the destination slot weekday', () {
    final monday = DateTime(2026, 9, 7);
    final sessions = [_session(id: 's-1', slotId: 'slot-mon')];
    final slots = {
      'slot-mon': _slot(id: 'slot-mon', dayOfWeek: 1, start: '09:00:00'),
      'slot-tue': _slot(id: 'slot-tue', dayOfWeek: 2, start: '14:00:00'),
    };
    final changes = [
      ClassSessionChange(
        id: 'ch-1',
        classSessionId: 's-1',
        changeType: 'TIME_MOVED',
        effectiveFrom: monday,
        effectiveTo: tuesday,
        newTimeSlotId: 'slot-tue',
      ),
    ];

    expect(
      resolveOccurrencesOn(
        date: monday,
        sessions: sessions,
        slotsById: slots,
        changes: changes,
      ),
      isEmpty,
    );
    final moved = resolveOccurrencesOn(
      date: tuesday,
      sessions: sessions,
      slotsById: slots,
      changes: changes,
    );
    expect(moved, hasLength(1));
    expect(moved.first.isTimeMoved, isTrue);
    expect(moved.first.slot.startTime, '14:00:00');
  });

  test('startsWithinReminderWindow is 25-35 minutes before start', () {
    final now = DateTime(2026, 9, 8, 8, 32);
    expect(
      startsWithinReminderWindow(now: now, startTime: '09:00:00'),
      isTrue,
    );
    expect(
      startsWithinReminderWindow(now: now, startTime: '10:00:00'),
      isFalse,
    );
  });

  test('nextUpcomingOccurrence skips ended and canceled classes', () {
    final slots = {
      'a': _slot(id: 'a', dayOfWeek: 2, start: '08:00:00', end: '09:00:00'),
      'b': _slot(id: 'b', dayOfWeek: 2, start: '10:00:00', end: '11:00:00'),
    };
    final live = resolveOccurrencesOn(
      date: tuesday,
      sessions: [
        _session(id: 'past', slotId: 'a'),
        _session(id: 'next', slotId: 'b'),
      ],
      slotsById: slots,
      changes: const [],
    );
    final next = nextUpcomingOccurrence(
      now: DateTime(2026, 9, 8, 9, 10),
      occurrences: live,
    );
    expect(next?.session.id, 'next');
  });
}
