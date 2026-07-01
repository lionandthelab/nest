/// 공과(수업외 자습) 배치 로직 — 순수 함수 모음.
///
/// 수업 시간표에서 각 반이 "지정된 창(예: 오전 9-12시)" 안에서 수업이 없는
/// 빈 시간(공강)을 계산해, 그 공강을 자습 슬롯 후보로 만든다. Flutter/Supabase
/// 의존이 없어 단위 테스트로 JOY 수기 시간표(ground truth)를 그대로 재현할 수
/// 있다.
///
/// 요일 규약: 앱 전역과 동일하게 0=일 .. 6=토 를 사용한다.
library;

/// 자습 생성 설정.
class SelfStudyPlanConfig {
  const SelfStudyPlanConfig({
    required this.days,
    required this.windowStartMin,
    required this.windowEndMin,
    this.minGapMinutes = 60,
  });

  /// 채울 요일(0=일..6=토).
  final List<int> days;

  /// 자습 창(자정 기준 분).
  final int windowStartMin;
  final int windowEndMin;

  /// 이보다 짧은 공강은 슬롯으로 만들지 않는다.
  final int minGapMinutes;
}

/// 한 반이 특정 요일에 수업으로 점유한 구간(자정 기준 분).
class GroupOccupancy {
  const GroupOccupancy({
    required this.classGroupId,
    required this.dayOfWeek,
    required this.startMin,
    required this.endMin,
  });

  final String classGroupId;
  final int dayOfWeek;
  final int startMin;
  final int endMin;
}

/// 자동 생성된 자습 슬롯 후보(반, 요일, 공강 구간).
class GeneratedSelfStudySlot {
  const GeneratedSelfStudySlot({
    required this.classGroupId,
    required this.dayOfWeek,
    required this.startMin,
    required this.endMin,
  });

  final String classGroupId;
  final int dayOfWeek;
  final int startMin;
  final int endMin;

  @override
  String toString() =>
      'GeneratedSelfStudySlot($classGroupId d$dayOfWeek '
      '${timeFromMinutes(startMin)}-${timeFromMinutes(endMin)})';
}

/// 각 반의 요일별 점유 구간을 받아, 설정된 창 안에서 남는 공강을 자습 슬롯으로
/// 만든다.
///
/// - 창과 겹치는 점유 구간만 고려하고, 창 경계로 클램프한다.
/// - 겹치거나 인접한 점유 구간은 병합한다.
/// - 병합된 점유의 여집합(공강) 중 [SelfStudyPlanConfig.minGapMinutes] 이상만
///   슬롯으로 만든다.
/// - 결과는 (반 입력 순서, 요일, 시작) 순으로 정렬한다.
List<GeneratedSelfStudySlot> generateSelfStudySlots({
  required List<String> classGroupIds,
  required List<GroupOccupancy> occupancy,
  required SelfStudyPlanConfig config,
}) {
  final wStart = config.windowStartMin;
  final wEnd = config.windowEndMin;
  if (wEnd <= wStart) return const [];

  // (groupId, day) -> 점유 구간들.
  final byGroupDay = <String, Map<int, List<GroupOccupancy>>>{};
  for (final o in occupancy) {
    if (o.endMin <= wStart || o.startMin >= wEnd) continue; // 창 밖.
    byGroupDay
        .putIfAbsent(o.classGroupId, () => <int, List<GroupOccupancy>>{})
        .putIfAbsent(o.dayOfWeek, () => <GroupOccupancy>[])
        .add(o);
  }

  final result = <GeneratedSelfStudySlot>[];
  final orderedDays = config.days.toSet().toList()..sort();

  for (final groupId in classGroupIds) {
    for (final day in orderedDays) {
      final occ = (byGroupDay[groupId]?[day] ?? const <GroupOccupancy>[])
          .map((o) => _Interval(
                o.startMin.clamp(wStart, wEnd),
                o.endMin.clamp(wStart, wEnd),
              ))
          .where((i) => i.end > i.start)
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));

      // 점유 구간 병합.
      final merged = <_Interval>[];
      for (final i in occ) {
        if (merged.isEmpty || i.start > merged.last.end) {
          merged.add(_Interval(i.start, i.end));
        } else if (i.end > merged.last.end) {
          merged[merged.length - 1] = _Interval(merged.last.start, i.end);
        }
      }

      // 여집합(공강) 산출.
      var cursor = wStart;
      for (final m in merged) {
        if (m.start - cursor >= config.minGapMinutes) {
          result.add(GeneratedSelfStudySlot(
            classGroupId: groupId,
            dayOfWeek: day,
            startMin: cursor,
            endMin: m.start,
          ));
        }
        if (m.end > cursor) cursor = m.end;
      }
      if (wEnd - cursor >= config.minGapMinutes) {
        result.add(GeneratedSelfStudySlot(
          classGroupId: groupId,
          dayOfWeek: day,
          startMin: cursor,
          endMin: wEnd,
        ));
      }
    }
  }

  return result;
}

class _Interval {
  const _Interval(this.start, this.end);
  final int start;
  final int end;
}

/// 'HH:MM' 또는 'HH:MM:SS' → 자정 기준 분. 파싱 실패 시 0.
int minutesFromTime(String value) {
  final parts = value.split(':');
  if (parts.length < 2) return 0;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return h * 60 + m;
}

/// 자정 기준 분 → 'HH:MM' (또는 [withSeconds] 시 'HH:MM:SS').
String timeFromMinutes(int minutes, {bool withSeconds = false}) {
  final h = (minutes ~/ 60).clamp(0, 23);
  final m = minutes % 60;
  final hh = h.toString().padLeft(2, '0');
  final mm = m.toString().padLeft(2, '0');
  return withSeconds ? '$hh:$mm:00' : '$hh:$mm';
}

/// 사람이 읽는 시간 라벨: 정각은 '9시', 분이 있으면 '9:30'.
String humanTimeLabel(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h시' : '$h:${m.toString().padLeft(2, '0')}';
}

/// 슬롯 구간을 사람이 읽는 라벨로: '9-10시', '9:30-11시'.
String rangeLabel(int startMin, int endMin) {
  final s = startMin ~/ 60;
  final sm = startMin % 60;
  final e = endMin ~/ 60;
  final em = endMin % 60;
  final start = sm == 0 ? '$s' : '$s:${sm.toString().padLeft(2, '0')}';
  final end = em == 0 ? '$e' : '$e:${em.toString().padLeft(2, '0')}';
  return '$start-$end시';
}

/// 반 이름에서 학년 라벨을 파생한다.
/// '초3','초6A' → '3학년' ; '중2A' → '중2' ; '중3J' → '중3' ; '고1' → '고1'.
/// 규칙에 맞지 않으면 반 이름을 그대로 돌려준다.
String gradeLabelForGroupName(String groupName) {
  final name = groupName.trim();
  final match = RegExp(r'^(초|중|고)\s*([1-6])').firstMatch(name);
  if (match == null) return name;
  final band = match.group(1)!;
  final num = match.group(2)!;
  return band == '초' ? '$num학년' : '$band$num';
}

/// 요일 한글 라벨(0=일..6=토).
String weekdayLabel(int dayOfWeek) {
  const labels = ['일', '월', '화', '수', '목', '금', '토'];
  return (dayOfWeek >= 0 && dayOfWeek < labels.length)
      ? labels[dayOfWeek]
      : '$dayOfWeek';
}

/// 앱 요일(0=일..6=토) → DateTime.weekday(1=월..7=일) 변환.
int _appDayToDartWeekday(int appDay) => appDay == 0 ? 7 : appDay;

/// [start]~[end](양끝 포함) 사이에서 주어진 요일(0=일..6=토)에 해당하는 날짜들.
List<DateTime> datesForWeekday(DateTime start, DateTime end, int dayOfWeek) {
  final target = _appDayToDartWeekday(dayOfWeek);
  final from = DateTime(start.year, start.month, start.day);
  final to = DateTime(end.year, end.month, end.day);
  if (to.isBefore(from)) return const [];
  final result = <DateTime>[];
  var cursor = from;
  // 첫 대상 요일까지 전진.
  while (cursor.weekday != target) {
    cursor = cursor.add(const Duration(days: 1));
    if (cursor.isAfter(to)) return const [];
  }
  while (!cursor.isAfter(to)) {
    result.add(cursor);
    cursor = cursor.add(const Duration(days: 7));
  }
  return result;
}

/// 자습 창을 정각 경계로 나눈 시간 밴드(출석부 소열). 각 밴드는 창과 겹치는
/// 부분만 남기며, 30분 미만으로 겹치는 밴드는 버린다.
/// 9-12 → [9-10, 10-11, 11-12] ; 9:30-11 → [9:30-10, 10-11].
List<List<int>> hourBands(int windowStartMin, int windowEndMin) {
  final bands = <List<int>>[];
  var hourStart = (windowStartMin ~/ 60) * 60;
  while (hourStart < windowEndMin) {
    final bandStart = hourStart < windowStartMin ? windowStartMin : hourStart;
    final bandEnd =
        (hourStart + 60) > windowEndMin ? windowEndMin : (hourStart + 60);
    if (bandEnd - bandStart >= 30) {
      bands.add([bandStart, bandEnd]);
    }
    hourStart += 60;
  }
  return bands;
}
