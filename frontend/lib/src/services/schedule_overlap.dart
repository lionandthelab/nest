import '../models/nest_models.dart';
import 'schedule_occurrence.dart';

/// 두 반열린 구간 [aStart, aEnd) / [bStart, bEnd) 가 겹치면 true.
bool rangesOverlap(
  DateTime aStart,
  DateTime aEnd,
  DateTime bStart,
  DateTime bEnd,
) {
  return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
}

DateTime nestDateTimeOn(DateTime date, String clock) {
  final minutes = nestMinutesFromTime(clock);
  final day = nestDateOnly(date);
  return day.add(Duration(minutes: minutes));
}

/// 개인 일정이 그날 그 교시와 시간이 겹치는지.
bool personalOverlapsSlot({
  required PersonalEvent event,
  required DateTime date,
  required TimeSlot slot,
}) {
  if (!event.coversDate(date)) return false;
  final slotStart = nestDateTimeOn(date, slot.startTime);
  final slotEnd = nestDateTimeOn(date, slot.endTime);
  return rangesOverlap(event.startsAt, event.endsAt, slotStart, slotEnd);
}

/// 시각이 있는 학사일정이 그날 그 교시와 겹치는지. 종일은 false
/// (요일 헤더에만 올리고 교시 충돌로는 보지 않는다).
bool academicOverlapsSlot({
  required AcademicEvent event,
  required DateTime date,
  required TimeSlot slot,
}) {
  if (!event.showOnTimetable || !event.coversDate(date) || event.isAllDay) {
    return false;
  }
  final startClock = event.startTime ?? '00:00:00';
  final endClock = (event.endTime ?? '').trim().isEmpty
      ? startClock
      : event.endTime!;
  var eventStart = nestDateTimeOn(date, startClock);
  var eventEnd = nestDateTimeOn(date, endClock);
  if (!eventEnd.isAfter(eventStart)) {
    eventEnd = eventStart.add(const Duration(minutes: 30));
  }
  final slotStart = nestDateTimeOn(date, slot.startTime);
  final slotEnd = nestDateTimeOn(date, slot.endTime);
  return rangesOverlap(eventStart, eventEnd, slotStart, slotEnd);
}

List<PersonalEvent> personalEventsOnDate({
  required List<PersonalEvent> events,
  required DateTime date,
  String? childId,
}) {
  return events
      .where(
        (event) =>
            (childId == null || event.childId == childId) &&
            event.coversDate(date),
      )
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
}

List<AcademicEvent> academicEventsOnDate({
  required List<AcademicEvent> events,
  required DateTime date,
  bool timetableOnly = false,
}) {
  return events
      .where((event) {
        if (timetableOnly && !event.showOnTimetable) return false;
        return event.coversDate(date);
      })
      .toList()
    ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
}

List<PersonalEvent> personalEventsOverlappingSlot({
  required List<PersonalEvent> events,
  required DateTime date,
  required TimeSlot slot,
  String? childId,
}) {
  return events
      .where(
        (event) =>
            (childId == null || event.childId == childId) &&
            personalOverlapsSlot(event: event, date: date, slot: slot),
      )
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
}

List<AcademicEvent> academicEventsOverlappingSlot({
  required List<AcademicEvent> events,
  required DateTime date,
  required TimeSlot slot,
}) {
  return events
      .where(
        (event) => academicOverlapsSlot(event: event, date: date, slot: slot),
      )
      .toList()
    ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
}

List<AcademicEvent> academicEventsInWeek({
  required List<AcademicEvent> events,
  required DateTime weekMonday,
  bool timetableOnly = true,
}) {
  final monday = nestMondayOf(weekMonday);
  final sunday = monday.add(const Duration(days: 6));
  return events
      .where((event) {
        if (timetableOnly && !event.showOnTimetable) return false;
        final start = nestDateOnly(event.eventDate);
        final end = nestDateOnly(event.endDate ?? event.eventDate);
        return !end.isBefore(monday) && !start.isAfter(sunday);
      })
      .toList()
    ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
}

List<ResolvedOccurrence> classesOverlappingPersonal({
  required PersonalEvent event,
  required List<ResolvedOccurrence> classes,
}) {
  return classes.where((row) {
    if (row.isCanceled) return false;
    final start = nestDateTimeOn(row.date, row.slot.startTime);
    final end = nestDateTimeOn(row.date, row.slot.endTime);
    return rangesOverlap(event.startsAt, event.endsAt, start, end);
  }).toList();
}

/// 개인 일정이 수업을 가리는지(PRIORITIZE_PERSONAL + 시간 겹침).
bool personalHidesClass({
  required List<PersonalEvent> events,
  required DateTime date,
  required TimeSlot slot,
  String? childId,
}) {
  return personalEventsOverlappingSlot(
    events: events,
    date: date,
    slot: slot,
    childId: childId,
  ).any((event) => event.prioritizesPersonal);
}

String academicKindLabel(String kind) {
  return switch (kind) {
    'HOLIDAY' => '휴일',
    'FIELD_TRIP' => '현장학습',
    'CEREMONY' => '식전·행사',
    'BREAK' => '방학·휴강',
    _ => '행사',
  };
}

String conflictPolicyLabel(String policy) {
  return policy == 'PRIORITIZE_PERSONAL' ? '개인 일정 우선' : '수업과 함께 표시';
}
