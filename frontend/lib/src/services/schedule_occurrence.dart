import '../models/nest_models.dart';

/// 주간 템플릿 세션 + 날짜별 변경을 합친 "그날의 실제 수업".
class ResolvedOccurrence {
  const ResolvedOccurrence({
    required this.session,
    required this.slot,
    required this.date,
    this.change,
    this.isTimeMoved = false,
  });

  final ClassSession session;
  final TimeSlot slot;
  final DateTime date;
  final ClassSessionChange? change;
  final bool isTimeMoved;

  bool get isCanceled => change?.changeType == 'CANCELED';

  String get location {
    final moved = change?.newLocation.trim() ?? '';
    if (moved.isNotEmpty) return moved;
    return (session.location ?? '').trim();
  }
}

DateTime nestDateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// 앱 규약: 0 = 일요일 (`DateTime.weekday` 는 1 = 월요일).
int nestDayOfWeek(DateTime date) => date.weekday % 7;

int nestMinutesFromTime(String value) {
  final parts = value.split(':');
  if (parts.length < 2) return 0;
  final hours = int.tryParse(parts[0]) ?? 0;
  final minutes = int.tryParse(parts[1]) ?? 0;
  return hours * 60 + minutes;
}

/// 세션에 걸린 변경 중 [date]에 실제로 적용되는 하나를 고른다.
/// 우선순위: 단일 날짜 → 유한 기간(짧은 기간 우선) → 학기 끝까지.
/// 같은 순위면 나중에 등록한 것이 이긴다.
ClassSessionChange? pickEffectiveChange({
  required List<ClassSessionChange> changes,
  required String sessionId,
  required DateTime date,
}) {
  final matches = changes
      .where((row) => row.classSessionId == sessionId && row.appliesOn(date))
      .toList();
  if (matches.isEmpty) return null;

  matches.sort((a, b) {
    final byScope = _changeScopeRank(a).compareTo(_changeScopeRank(b));
    if (byScope != 0) return byScope;
    final bySpan = _changeSpanDays(a).compareTo(_changeSpanDays(b));
    if (bySpan != 0) return bySpan;
    final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return right.compareTo(left);
  });
  return matches.first;
}

int _changeScopeRank(ClassSessionChange change) {
  final to = change.effectiveTo;
  if (to == null) return 2;
  final from = change.effectiveFrom;
  if (to.year == from.year && to.month == from.month && to.day == from.day) {
    return 0;
  }
  return 1;
}

int _changeSpanDays(ClassSessionChange change) {
  final to = change.effectiveTo;
  if (to == null) return 1 << 30;
  return to.difference(change.effectiveFrom).inDays.abs();
}

/// [date]에 실제로 열리는 수업. TIME_MOVED는 옮겨간 교시 요일로 판단한다.
List<ResolvedOccurrence> resolveOccurrencesOn({
  required DateTime date,
  required Iterable<ClassSession> sessions,
  required Map<String, TimeSlot> slotsById,
  required List<ClassSessionChange> changes,
}) {
  final day = nestDayOfWeek(date);
  final dayOnly = nestDateOnly(date);
  final out = <ResolvedOccurrence>[];

  for (final session in sessions) {
    final baseSlot = slotsById[session.timeSlotId];
    if (baseSlot == null) continue;

    final change = pickEffectiveChange(
      changes: changes,
      sessionId: session.id,
      date: dayOnly,
    );

    var slot = baseSlot;
    var moved = false;
    if (change != null &&
        change.changeType == 'TIME_MOVED' &&
        (change.newTimeSlotId ?? '').isNotEmpty) {
      final next = slotsById[change.newTimeSlotId!];
      if (next != null) {
        slot = next;
        moved = true;
      }
    }

    if (slot.dayOfWeek != day) continue;

    out.add(
      ResolvedOccurrence(
        session: session,
        slot: slot,
        date: dayOnly,
        change: change,
        isTimeMoved: moved,
      ),
    );
  }

  out.sort((a, b) => a.slot.startTime.compareTo(b.slot.startTime));
  return out;
}

/// 오늘 아직 끝나지 않은 다음 수업. 휴강은 건너뛴다.
ResolvedOccurrence? nextUpcomingOccurrence({
  required DateTime now,
  required List<ResolvedOccurrence> occurrences,
}) {
  final today = nestDateOnly(now);
  final nowMin = now.hour * 60 + now.minute;
  for (final occurrence in occurrences) {
    if (occurrence.isCanceled) continue;
    if (nestDateOnly(occurrence.date) != today) continue;
    if (nestMinutesFromTime(occurrence.slot.endTime) <= nowMin) continue;
    return occurrence;
  }
  return null;
}

/// 수업 시작이 [minAhead]분 이상 [maxAhead]분 미만인지 (30분 전 크론 윈도우).
bool startsWithinReminderWindow({
  required DateTime now,
  required String startTime,
  int minAheadMinutes = 25,
  int maxAheadMinutes = 35,
}) {
  final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(minutes: nestMinutesFromTime(startTime)));
  final delta = start.difference(now).inMinutes;
  return delta >= minAheadMinutes && delta < maxAheadMinutes;
}

String shortTimeLabel(String value) {
  final parts = value.split(':');
  if (parts.length < 2) return value;
  final hours = parts[0].padLeft(2, '0');
  final minutes = parts[1].padLeft(2, '0');
  return '$hours:$minutes';
}
