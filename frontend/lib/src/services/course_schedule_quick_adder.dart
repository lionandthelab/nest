import '../models/nest_models.dart';

/// 템플릿이나 문장 입력으로 생성할 과목 항목.
class CourseTemplateItem {
  const CourseTemplateItem({
    required this.name,
    this.defaultDurationMin = 50,
  });

  final String name;
  final int defaultDurationMin;
}

/// 요일·시작 시각(HH:MM) 기준 시간표 배치 항목.
class TemplateSlotPlacement {
  const TemplateSlotPlacement({
    required this.dayOfWeek,
    required this.startTime,
    required this.courseName,
  });

  final int dayOfWeek;
  final String startTime;
  final String courseName;

  String get dayLabel {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return (dayOfWeek >= 0 && dayOfWeek < labels.length)
        ? labels[dayOfWeek]
        : '?';
  }
}

/// 홈스쿨 스타일/연령대별 수업·시간표 패키지 템플릿.
class CourseScheduleTemplate {
  const CourseScheduleTemplate({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.courses,
    required this.placements,
  });

  final String id;
  final String title;
  final String subtitle;
  final String badge;
  final List<CourseTemplateItem> courses;
  final List<TemplateSlotPlacement> placements;
}

/// 문장 입력창 아래에 바로 눌러서 쓸 수 있는 예시 문장 목록.
const kCourseScheduleExampleSentences =
    <({String label, String sentence})>[
  (
    label: '요일·시간 지정',
    sentence: '월수금 9시 국어, 10시 수학, 화목 10시 영어, 오후 2시 미술 추가해줘',
  ),
  (
    label: '매일 루틴 + 오후 활동',
    sentence: '매일 9시 아침독서, 월수금 10시 수학, 화목 10시 과학실험, 수요일 오후 3시 피아노',
  ),
  (
    label: '교시 단위 입력',
    sentence: '월요일 1교시 국어 2교시 수학, 화요일 1교시 영어 2교시 사회, 목요일 6교시 체육',
  ),
  (
    label: '과목만 한 번에 추가',
    sentence: '국어, 수학, 영어회화, 과학실험, 미술창작, 피아노 60분, 체육 추가해줘',
  ),
];

/// 다양한 연령·교육 스타일별 기본 제공 템플릿.
final List<CourseScheduleTemplate> kCourseScheduleTemplates = [
  CourseScheduleTemplate(
    id: 'basic_home',
    title: '우리집 기본 홈스쿨',
    subtitle: '오전 국·영·수·독서 루틴과 오후 예체능·탐구를 균형 있게 배치해요',
    badge: '전 학년 추천',
    courses: const [
      CourseTemplateItem(name: '아침독서'),
      CourseTemplateItem(name: '국어'),
      CourseTemplateItem(name: '수학'),
      CourseTemplateItem(name: '영어'),
      CourseTemplateItem(name: '과학·탐구'),
      CourseTemplateItem(name: '미술·음악'),
      CourseTemplateItem(name: '체육'),
    ],
    placements: [
      for (final d in [1, 2, 3, 4, 5])
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '09:00',
          courseName: '아침독서',
        ),
      for (final d in [1, 3, 5]) ...[
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '10:00',
          courseName: '국어',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '11:00',
          courseName: '수학',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '14:00',
          courseName: '미술·음악',
        ),
      ],
      for (final d in [2, 4]) ...[
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '10:00',
          courseName: '영어',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '11:00',
          courseName: '과학·탐구',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '14:00',
          courseName: '체육',
        ),
      ],
    ],
  ),
  CourseScheduleTemplate(
    id: 'elementary_low',
    title: '초등 저학년 기초·놀이',
    subtitle: '한글 문해력·놀이수학·그림책·자연관찰 중심의 따뜻한 루틴',
    badge: '초등 1~2학년',
    courses: const [
      CourseTemplateItem(name: '아침독서'),
      CourseTemplateItem(name: '한글·문해력'),
      CourseTemplateItem(name: '놀이수학'),
      CourseTemplateItem(name: '영어그림책'),
      CourseTemplateItem(name: '자연관찰'),
      CourseTemplateItem(name: '미술창작'),
      CourseTemplateItem(name: '신체놀이'),
    ],
    placements: [
      for (final d in [1, 2, 3, 4, 5])
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '09:00',
          courseName: '아침독서',
        ),
      for (final d in [1, 3, 5]) ...[
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '10:00',
          courseName: '한글·문해력',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '11:00',
          courseName: '놀이수학',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '14:00',
          courseName: '미술창작',
        ),
      ],
      for (final d in [2, 4]) ...[
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '10:00',
          courseName: '영어그림책',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '11:00',
          courseName: '자연관찰',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '14:00',
          courseName: '신체놀이',
        ),
      ],
    ],
  ),
  CourseScheduleTemplate(
    id: 'elementary_high',
    title: '초등 고학년 교과·탐구',
    subtitle: '주요 교과 심화와 과학실험·역사·코딩 프로젝트를 함께 다뤄요',
    badge: '초등 3~6학년',
    courses: const [
      CourseTemplateItem(name: '국어·논술'),
      CourseTemplateItem(name: '사고력수학'),
      CourseTemplateItem(name: '영어리딩·회화'),
      CourseTemplateItem(name: '사회·역사탐구'),
      CourseTemplateItem(name: '과학실험'),
      CourseTemplateItem(name: '코딩·메이커'),
      CourseTemplateItem(name: '자기주도학습'),
    ],
    placements: [
      for (final d in [1, 3, 5]) ...[
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '09:00',
          courseName: '국어·논술',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '10:00',
          courseName: '사고력수학',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '11:00',
          courseName: '영어리딩·회화',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '14:00',
          courseName: '자기주도학습',
        ),
      ],
      for (final d in [2, 4]) ...[
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '09:00',
          courseName: '영어리딩·회화',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '10:00',
          courseName: '사회·역사탐구',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '11:00',
          courseName: '과학실험',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '14:00',
          courseName: '코딩·메이커',
        ),
      ],
    ],
  ),
  CourseScheduleTemplate(
    id: 'reading_humanities',
    title: '독서·인문·문해력 집중',
    subtitle: '고전 읽기·글쓰기·원서 리딩·역사 토론으로 생각하는 힘을 길러요',
    badge: '문해력·인문',
    courses: const [
      CourseTemplateItem(name: '아침독서'),
      CourseTemplateItem(name: '고전·문학읽기'),
      CourseTemplateItem(name: '글쓰기·독서록'),
      CourseTemplateItem(name: '영어원서리딩'),
      CourseTemplateItem(name: '역사기행'),
      CourseTemplateItem(name: '기초수학'),
      CourseTemplateItem(name: '토론·발표'),
    ],
    placements: [
      for (final d in [1, 2, 3, 4, 5])
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '09:00',
          courseName: '아침독서',
        ),
      for (final d in [1, 3, 5]) ...[
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '10:00',
          courseName: '고전·문학읽기',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '11:00',
          courseName: '기초수학',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '14:00',
          courseName: '글쓰기·독서록',
        ),
      ],
      for (final d in [2, 4]) ...[
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '10:00',
          courseName: '영어원서리딩',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '11:00',
          courseName: '역사기행',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '14:00',
          courseName: '토론·발표',
        ),
      ],
    ],
  ),
  CourseScheduleTemplate(
    id: 'arts_nature',
    title: '예체능·숲체험·창의 중심',
    subtitle: '생태 감수성과 예술·신체 활동, 생활 속 과학·수학을 즐겁게 배워요',
    badge: '체험·예술',
    courses: const [
      CourseTemplateItem(name: '감성독서'),
      CourseTemplateItem(name: '보드게임수학'),
      CourseTemplateItem(name: '숲체험·생태'),
      CourseTemplateItem(name: '미술·공예'),
      CourseTemplateItem(name: '피아노·음악'),
      CourseTemplateItem(name: '체육·수영'),
      CourseTemplateItem(name: '요리과학'),
    ],
    placements: [
      for (final d in [1, 3, 5]) ...[
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '09:00',
          courseName: '감성독서',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '10:00',
          courseName: '보드게임수학',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '14:00',
          courseName: '미술·공예',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '15:00',
          courseName: '피아노·음악',
        ),
      ],
      for (final d in [2, 4]) ...[
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '09:00',
          courseName: '감성독서',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '10:00',
          courseName: '숲체험·생태',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '14:00',
          courseName: '요리과학',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '15:00',
          courseName: '체육·수영',
        ),
      ],
    ],
  ),
  CourseScheduleTemplate(
    id: 'global_bilingual',
    title: '이중언어·글로벌 자기주도',
    subtitle: '오전 영어 몰입 루틴과 오후 국어·수학·자율 프로젝트로 구성해요',
    badge: '영어·자기주도',
    courses: const [
      CourseTemplateItem(name: '영어파닉스·회화'),
      CourseTemplateItem(name: '영어원서읽기'),
      CourseTemplateItem(name: '영작문·스피킹'),
      CourseTemplateItem(name: '국어논술'),
      CourseTemplateItem(name: '수학탐구'),
      CourseTemplateItem(name: '세계문화탐구'),
      CourseTemplateItem(name: '프로젝트학습'),
    ],
    placements: [
      for (final d in [1, 2, 3, 4, 5])
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '09:00',
          courseName: '영어원서읽기',
        ),
      for (final d in [1, 3, 5]) ...[
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '10:00',
          courseName: '영어파닉스·회화',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '11:00',
          courseName: '수학탐구',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '14:00',
          courseName: '국어논술',
        ),
      ],
      for (final d in [2, 4]) ...[
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '10:00',
          courseName: '영작문·스피킹',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '11:00',
          courseName: '세계문화탐구',
        ),
        TemplateSlotPlacement(
          dayOfWeek: d,
          startTime: '14:00',
          courseName: '프로젝트학습',
        ),
      ],
    ],
  ),
];

/// 자연어 문장에서 추출된 과목 및 시간표 배치 결과.
class ParsedCourseScheduleResult {
  const ParsedCourseScheduleResult({
    required this.courses,
    required this.placements,
  });

  final List<CourseTemplateItem> courses;
  final List<TemplateSlotPlacement> placements;

  bool get isEmpty => courses.isEmpty && placements.isEmpty;
  bool get hasPlacements => placements.isNotEmpty;
}

/// 한국어 자연어 문장을 분석하여 과목 목록과 시간표 배치(요일·시간)를 추출한다.
///
/// 지원 예시:
/// - "월수금 9시 국어, 10시 수학, 화목 10시 영어, 오후 2시 미술 추가해줘"
/// - "매일 9시 아침독서, 월수금 10시 수학, 화목 10시 과학실험"
/// - "월요일 1교시 국어 2교시 수학, 화요일 1교시 영어"
/// - "국어, 수학, 영어회화 40분, 피아노 60분 추가"
ParsedCourseScheduleResult parseCourseScheduleSentence(String rawInput) {
  final normalizedInput = rawInput.trim();
  if (normalizedInput.isEmpty) {
    return const ParsedCourseScheduleResult(courses: [], placements: []);
  }

  // 한 구절 안에 "월요일 1교시 국어 2교시 수학"처럼 시간/교시가 연달아 나오는 경우
  // 구분자(,)를 보강해 각각 독립 토큰으로 분리한다.
  var preSplit = normalizedInput.replaceAll(RegExp(r'[\n;/]+'), ',');
  preSplit = preSplit.replaceAllMapped(
    RegExp(
      r'(\S)\s+((?:오전|오후)\s*\d{1,2}\s*시|\d{1,2}\s*교시|\d{1,2}\s*:\s*\d{2}|\d{1,2}\s*시(?:\s*\d{1,2}\s*분)?)',
    ),
    (m) {
      final prev = m.group(1)!;
      // 앞 토큰이 요일 표현(예: "월요일", "월수금", "매일", "평일")이면 끊지 않는다.
      if (RegExp(r'[월화수목금토일요매일평주말~]$').hasMatch(prev)) {
        return m.group(0)!;
      }
      return '$prev, ${m.group(2)}';
    },
  );

  final rawClauses = preSplit
      .split(RegExp(r',|\s+그리고\s+|\s+및\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  final coursesByLower = <String, CourseTemplateItem>{};
  final placements = <TemplateSlotPlacement>[];
  final placementKeys = <String>{};

  var activeDays = <int>[];
  int? lastHour;

  for (final clause in rawClauses) {
    var working = clause;

    // 1. 요일 추출 (예: "월수금", "화목", "매일", "평일", "월~금", "월요일")
    final extractedDays = _extractDaysFromPrefix(working);
    if (extractedDays != null) {
      activeDays = extractedDays.days;
      working = extractedDays.remainder.trim();
      lastHour = null;
    }

    // 2. 시간 또는 교시 추출 (예: "오전 9시", "오후 2시", "14:00", "1교시")
    final extractedTime = _extractTimeFromClause(working);
    int? resolvedHour;
    if (extractedTime != null) {
      resolvedHour = extractedTime.hour24;
      lastHour = resolvedHour;
      working = extractedTime.remainder.trim();
      if (activeDays.isEmpty) {
        activeDays = const [1, 2, 3, 4, 5];
      }
    } else if (activeDays.isNotEmpty && lastHour != null) {
      // "월수금 9시 국어, 수학, 영어"처럼 요일·시간 뒤에 과목만 이어진 경우 다음 교시로 자동 진행
      final nextHour = lastHour + 1;
      if (nextHour <= 17) {
        resolvedHour = nextHour;
        lastHour = nextHour;
      }
    }

    // 3. 수업 길이(분) 추출 (예: "60분", "40분")
    var durationMin = 50;
    final durationMatch = RegExp(r'(\d{2,3})\s*분').firstMatch(working);
    if (durationMatch != null) {
      final parsed = int.tryParse(durationMatch.group(1) ?? '');
      if (parsed != null && parsed >= 20 && parsed <= 300) {
        durationMin = parsed;
      }
      working = working.replaceFirst(durationMatch.group(0)!, ' ').trim();
    }

    // 4. 불필요한 서술어/조사 정리
    final courseName = _cleanCourseName(working);
    if (courseName.isEmpty) {
      continue;
    }

    final lowerKey = courseName.toLowerCase();
    coursesByLower.putIfAbsent(
      lowerKey,
      () => CourseTemplateItem(
        name: courseName,
        defaultDurationMin: durationMin,
      ),
    );

    if (resolvedHour != null && activeDays.isNotEmpty) {
      final startTime = '${resolvedHour.toString().padLeft(2, '0')}:00';
      for (final day in activeDays) {
        final key = '$day|$startTime|$lowerKey';
        if (placementKeys.add(key)) {
          placements.add(
            TemplateSlotPlacement(
              dayOfWeek: day,
              startTime: startTime,
              courseName: coursesByLower[lowerKey]!.name,
            ),
          );
        }
      }
    }
  }

  return ParsedCourseScheduleResult(
    courses: coursesByLower.values.toList(),
    placements: placements,
  );
}

/// 시간표 슬롯 목록에서 (dayOfWeek, startTime)과 가장 잘 맞는 슬롯을 찾는다.
TimeSlot? matchTimeSlotForPlacement({
  required List<TimeSlot> timeSlots,
  required int dayOfWeek,
  required String startTime,
}) {
  final targetPrefix = startTime.length >= 5
      ? startTime.substring(0, 5)
      : startTime;
  final daySlots = timeSlots.where((s) => s.dayOfWeek == dayOfWeek).toList();
  if (daySlots.isEmpty) return null;

  for (final slot in daySlots) {
    final slotPrefix = slot.startTime.length >= 5
        ? slot.startTime.substring(0, 5)
        : slot.startTime;
    if (slotPrefix == targetPrefix) {
      return slot;
    }
  }

  // 정확히 같은 분이 없으면 같은 시(hour)로 시작하는 슬롯과 매칭 (예: 09:00 -> 09:30)
  final targetHour = targetPrefix.split(':').first;
  for (final slot in daySlots) {
    final slotHour = slot.startTime.split(':').first.padLeft(2, '0');
    if (slotHour == targetHour) {
      return slot;
    }
  }
  return null;
}

({List<int> days, String remainder})? _extractDaysFromPrefix(String input) {
  final trimmed = input.trimLeft();

  // "매일", "평일", "월~금", "월-금"
  final everyDayMatch = RegExp(
    r'^(?:매일|평일|매주\s*평일|월\s*[~\-]\s*금(?:요일)?)\s*',
  ).firstMatch(trimmed);
  if (everyDayMatch != null) {
    return (
      days: const [1, 2, 3, 4, 5],
      remainder: trimmed.substring(everyDayMatch.end),
    );
  }

  // "월수금", "화목", "월,수,금", "월요일", "수요일마다" 등
  final dayTokenMatch = RegExp(
    r'^((?:[월화수목금토일](?:요일)?(?:\s*[·,/&\s]\s*)?)+)(?:마다|에는|에)?(?=\s|$|\d|오전|오후)',
  ).firstMatch(trimmed);

  if (dayTokenMatch != null) {
    final token = dayTokenMatch.group(1)!;
    // 단일 글자 과목 오인 방지: 뒤에 시간/교시가 없거나 단독 글자면 요일로 보지 않음
    final after = trimmed.substring(dayTokenMatch.end).trimLeft();
    final hasTimeOrExplicitDay =
        token.contains('요일') ||
        token.length >= 2 ||
        RegExp(r'^(?:오전|오후|\d{1,2}\s*(?:시|교시|:))').hasMatch(after);

    if (hasTimeOrExplicitDay && after.isNotEmpty) {
      final dayMap = <String, int>{
        '일': 0,
        '월': 1,
        '화': 2,
        '수': 3,
        '목': 4,
        '금': 5,
        '토': 6,
      };
      final days = <int>[];
      for (final rune in token.runes) {
        final ch = String.fromCharCode(rune);
        final d = dayMap[ch];
        if (d != null && !days.contains(d)) {
          days.add(d);
        }
      }
      if (days.isNotEmpty) {
        return (days: days, remainder: after);
      }
    }
  }

  return null;
}

({int hour24, String remainder})? _extractTimeFromClause(String input) {
  final trimmed = input.trim();

  // 1) "N교시" (1교시 = 09:00, 2교시 = 10:00, ... 9교시 = 17:00)
  final periodMatch = RegExp(r'(\d{1,2})\s*교시(?:에|에는)?').firstMatch(trimmed);
  if (periodMatch != null) {
    final period = int.tryParse(periodMatch.group(1) ?? '');
    if (period != null && period >= 1 && period <= 9) {
      final hour = 8 + period; // 1교시 -> 9시
      final remainder = trimmed
          .replaceFirst(periodMatch.group(0)!, ' ')
          .trim();
      return (hour24: hour, remainder: remainder);
    }
  }

  // 2) "(오전/오후) HH:MM" 또는 "(오전/오후) H시 (M분) (부터)"
  final clockMatch = RegExp(
    r'(?:(오전|오후|아침|낮|저녁)\s*)?(\d{1,2})\s*(?::\s*(\d{2})|시(?:\s*(\d{1,2})\s*분)?)(?:\s*부터)?(?:에|에는)?',
  ).firstMatch(trimmed);

  if (clockMatch != null) {
    final meridiem = clockMatch.group(1);
    var hour = int.tryParse(clockMatch.group(2) ?? '');
    if (hour != null && hour >= 1 && hour <= 23) {
      if (meridiem == '오후' || meridiem == '낮' || meridiem == '저녁') {
        if (hour < 12) hour += 12;
      } else if (meridiem == '오전' || meridiem == '아침') {
        if (hour == 12) hour = 0;
      } else {
        // 홈스쿨 기본 시간대(09:00~18:00) 기준: 1시~6시는 오후(13시~18시)로 해석
        if (hour >= 1 && hour <= 6) {
          hour += 12;
        }
      }
      final remainder = trimmed.replaceFirst(clockMatch.group(0)!, ' ').trim();
      return (hour24: hour, remainder: remainder);
    }
  }

  return null;
}

String _cleanCourseName(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';

  // 앞쪽 불필요 부사/조사 제거
  s = s.replaceFirst(RegExp(r'^(?:부터|에는|에|그리고|및)\s*'), '').trim();

  // 뒤쪽 서술어("추가해줘", "넣어줘", "배치해줘", "만들어줘", "수업 추가", "과목 추가" 등) 제거
  s = s
      .replaceFirst(
        RegExp(
          r'\s*(?:과목|수업)?\s*(?:추가해\s*주세요|추가해\s*줘요?|추가할래요?|추가하기|추가|넣어\s*주세요|넣어\s*줘요?|배치해\s*줘요?|배치|만들어\s*줘요?|등록해\s*줘요?|등록|해\s*줘요?|해\s*주세요)$',
        ),
        '',
      )
      .trim();

  // 끝에 단독으로 남은 '수업' 또는 '과목' 정리 (단, '미술수업'처럼 붙어있지 않고 띄어쓰기 된 경우)
  s = s.replaceFirst(RegExp(r'\s+(?:수업|과목)$'), '').trim();

  // 끝에 남은 조사(을/를) 제거 (예: "미술을" -> "미술", "국어를" -> "국어")
  if (s.length >= 3 && (s.endsWith('을') || s.endsWith('를'))) {
    s = s.substring(0, s.length - 1).trim();
  }

  return s;
}
