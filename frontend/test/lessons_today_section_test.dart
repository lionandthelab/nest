import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/models/child_class_bundle.dart';
import 'package:nest_frontend/src/ui/tabs/lessons_today_section.dart';

/// 학부모·학생 홈의 "오늘의 수업" 섹션. 모바일에서 회차 내용을 바로 보게 하는 것이
/// 이 위젯의 목적이라, 좁은 폭 렌더와 다음 수업일 폴백을 함께 검증한다.

NestController _controller() {
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return NestController(repository: NestRepository(client));
}

/// ⚠️ 학기 기간과 수업 요일을 **실행 시각 기준 상대값**으로 만든다.
/// 고정 날짜(2026-09-01 ~ 11-30)를 쓰면 그 날짜가 지나는 순간
/// `_resolveDay` 의 학기 종료 클램프에 걸려 프로덕션 코드 변경 없이 테스트가 깨진다.
final DateTime _today = DateTime(
  DateTime.now().year,
  DateTime.now().month,
  DateTime.now().day,
);

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// 오늘이 학기 한가운데에 오도록 잡는다.
final DateTime _termStart = _today.subtract(const Duration(days: 7));
final DateTime _termEnd = _today.add(const Duration(days: 60));

/// 오늘의 요일에 수업이 있도록 해서 "오늘의 수업" 경로를 확정적으로 태운다.
final int _todayDayOfWeek = _today.weekday % 7;

Term _term() => Term.fromMap({
  'id': 't-fall',
  'homeschool_id': 's1',
  'name': '2026 가을',
  'status': 'DRAFT',
  'start_date': _iso(_termStart),
  'end_date': _iso(_termEnd),
});

TimeSlot _slot({required String id, required int dayOfWeek}) =>
    TimeSlot.fromMap({
      'id': id,
      'term_id': 't-fall',
      'day_of_week': dayOfWeek,
      'start_time': '10:00:00',
      'end_time': '10:30:00',
    });

ClassSession _session({
  required String id,
  required String courseId,
  required String timeSlotId,
}) => ClassSession.fromMap({
  'id': id,
  'class_group_id': 'cg1',
  'course_id': courseId,
  'time_slot_id': timeSlotId,
  'title': '',
  'source_type': 'MANUAL',
  'status': 'PLANNED',
  'location': '4중예배실',
});

CourseLesson _lesson({
  required String date,
  String courseId = 'c-qt',
  String title = '창세기 36장',
  String subtitle = '에서의 자손',
  String presenter = '리아',
}) => CourseLesson.fromMap({
  'id': 'l-$date',
  'course_id': courseId,
  'lesson_date': date,
  'title': title,
  'subtitle': subtitle,
  'presenter': presenter,
  'content': '',
  'is_confirmed': true,
});

/// 화요일에 통합 모임이 있는 반 하나.
Map<String, ChildClassBundle> _bundles() {
  return {
    'cg1': ChildClassBundle(
      classGroup: ClassGroup.fromMap({
        'id': 'cg1',
        'term_id': 't-fall',
        'name': '초3',
        'capacity': 12,
      }),
      sessions: [
        _session(id: 'cs1', courseId: 'c-qt', timeSlotId: 'ts-tue'),
      ],
      assignments: const [],
      changes: const [],
      announcements: const [],
    ),
  };
}

NestController _fallController() {
  final controller = _controller();
  controller.currentRole = 'PARENT';
  controller.terms = [_term()];
  controller.selectedTermId = 't-fall';
  controller.timeSlots = [_slot(id: 'ts-tue', dayOfWeek: _todayDayOfWeek)];
  controller.allTermSessions = [
    _session(id: 'cs1', courseId: 'c-qt', timeSlotId: 'ts-tue'),
  ];
  controller.courses = [
    Course.fromMap({
      'id': 'c-qt',
      'name': '주중예배',
      'default_duration_min': 30,
    }),
  ];
  return controller;
}

Widget _mobileApp(Widget child) {
  return MaterialApp(
    locale: const Locale('ko', 'KR'),
    supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [child],
      ),
    ),
  );
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('LessonsTodaySection', () {
    testWidgets('오늘 수업이 있으면 오늘의 진도를 보여준다', (tester) async {
      await _setSize(tester, const Size(360, 780));
      final controller = _fallController();
      controller.courseLessons = [
        _lesson(date: _iso(_today)),
        _lesson(date: _iso(_today.add(const Duration(days: 7)))),
      ];

      await tester.pumpWidget(
        _mobileApp(
          LessonsTodaySection(
            controller: controller,
            childId: 'child-1',
            bundles: _bundles(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('오늘의 수업'), findsOneWidget);
      expect(find.text('주중예배'), findsOneWidget);
      // 오늘 회차의 내용이 카드 안에 바로 보인다.
      expect(find.text('창세기 36장 · 에서의 자손'), findsOneWidget);
      expect(find.text('담당 리아'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('오늘 수업이 없으면 다음 수업일로 넘어간다', (tester) async {
      await _setSize(tester, const Size(360, 780));
      final controller = _fallController();
      // 수업을 내일 요일로 옮겨 오늘은 수업이 없게 만든다.
      final tomorrow = _today.add(const Duration(days: 1));
      controller.timeSlots = [
        _slot(id: 'ts-tue', dayOfWeek: tomorrow.weekday % 7),
      ];
      controller.courseLessons = [_lesson(date: _iso(tomorrow))];

      await tester.pumpWidget(
        _mobileApp(
          LessonsTodaySection(
            controller: controller,
            childId: 'child-1',
            bundles: _bundles(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('다음 수업'), findsOneWidget);
      expect(find.text('오늘의 수업'), findsNothing);
      expect(find.text('주중예배'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('시간 변경(TIME_MOVED)이 걸리면 옮겨간 요일·시각으로 보여준다', (tester) async {
      // 원래 교시로 판단하면 옮기기 전 요일에 수업이 있다고 알려주고(엉뚱한 시각에
      // 아이를 데려오게 된다) 옮겨간 요일에는 아예 안 보인다.
      await _setSize(tester, const Size(360, 780));
      final controller = _fallController();
      final tomorrow = _today.add(const Duration(days: 1));
      controller.timeSlots = [
        _slot(id: 'ts-tue', dayOfWeek: _todayDayOfWeek),
        TimeSlot.fromMap({
          'id': 'ts-moved',
          'term_id': 't-fall',
          'day_of_week': tomorrow.weekday % 7,
          'start_time': '14:00:00',
          'end_time': '14:30:00',
        }),
      ];
      controller.classSessionChanges = [
        ClassSessionChange.fromMap({
          'id': 'chg-1',
          'class_session_id': 'cs1',
          'change_type': 'TIME_MOVED',
          'effective_from': _iso(_today),
          'effective_to': _iso(tomorrow),
          'new_time_slot_id': 'ts-moved',
          'reason': '강사 일정',
        }),
      ];

      await tester.pumpWidget(
        _mobileApp(
          LessonsTodaySection(
            controller: controller,
            childId: 'child-1',
            bundles: _bundles(),
          ),
        ),
      );
      await tester.pump();

      // 오늘은 원래 요일이지만 수업이 옮겨갔으므로 오늘 카드가 아니라 내일 카드다.
      expect(find.text('다음 수업'), findsOneWidget);
      expect(find.textContaining('14:00 - 14:30 (변경됨)'), findsOneWidget);
      expect(find.text('시간 변경'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('진도가 없는 회차는 "수업 내용 미등록"으로 표시한다', (tester) async {
      await _setSize(tester, const Size(360, 780));
      final controller = _fallController();
      controller.courseLessons = [];

      await tester.pumpWidget(
        _mobileApp(
          LessonsTodaySection(
            controller: controller,
            childId: 'child-1',
            bundles: _bundles(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('수업 내용 미등록'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('반 배정이 없으면 안내 문구만 보인다', (tester) async {
      await _setSize(tester, const Size(360, 780));
      final controller = _fallController();

      await tester.pumpWidget(
        _mobileApp(
          LessonsTodaySection(
            controller: controller,
            childId: 'child-1',
            bundles: const {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('반이 배정되면 수업과 진도를 여기서 볼 수 있어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final size in const [
      Size(320, 640), // 좁은 구형 폰
      Size(360, 780),
      Size(412, 915),
      Size(800, 390), // 가로모드
    ]) {
      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()} 에서 오버플로 없이 렌더된다',
        (tester) async {
          await _setSize(tester, size);
          final controller = _fallController();
          controller.courseLessons = [
            _lesson(
              date: _iso(_today),
              title: '창세기 36장',
              subtitle: '에서의 자손과 아주 긴 부제가 들어가는 경우',
              presenter: '리아',
            ),
          ];

          await tester.pumpWidget(
            _mobileApp(
              LessonsTodaySection(
                controller: controller,
                childId: 'child-1',
                bundles: _bundles(),
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
