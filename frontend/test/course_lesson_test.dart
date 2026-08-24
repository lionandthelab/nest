import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/tabs/timetable/course_lesson_sheet.dart';

// 네트워크를 타지 않는 컨트롤러. 검증 대상은 모두 메모리 컬렉션만 읽는다.
// autoRefreshToken 을 꺼야 GoTrue 타이머가 남지 않는다.
NestController _controller() {
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return NestController(repository: NestRepository(client));
}

Term _term({
  String id = 't-fall',
  String name = '2026 가을',
  String start = '2026-09-01',
  String end = '2026-11-30',
}) => Term.fromMap({
  'id': id,
  'homeschool_id': 's1',
  'name': name,
  'status': 'DRAFT',
  'start_date': start,
  'end_date': end,
});

TimeSlot _slot({
  required String id,
  required int dayOfWeek,
  String start = '10:00:00',
  String end = '10:30:00',
}) => TimeSlot.fromMap({
  'id': id,
  'term_id': 't-fall',
  'day_of_week': dayOfWeek,
  'start_time': start,
  'end_time': end,
});

ClassSession _session({
  required String id,
  required String courseId,
  required String timeSlotId,
  String classGroupId = 'cg1',
}) => ClassSession.fromMap({
  'id': id,
  'class_group_id': classGroupId,
  'course_id': courseId,
  'time_slot_id': timeSlotId,
  'title': '',
  'source_type': 'MANUAL',
  'status': 'PLANNED',
});

CourseLesson _lesson({
  required String id,
  required String date,
  String courseId = 'c-qt',
  String title = '창세기 36장',
  String presenter = '',
}) => CourseLesson.fromMap({
  'id': id,
  'course_id': courseId,
  'lesson_date': date,
  'title': title,
  'subtitle': '',
  'presenter': presenter,
  'content': '',
  'is_confirmed': false,
});

/// 화요일 4교시에 걸린 전교생 공통 과목(통합QT/주중예배) 형태로 세팅한다.
/// 반 14개 × 교시 4개처럼 세션이 많아도 회차는 과목+날짜로 하나여야 한다.
NestController _wholeSchoolTuesdayCourse() {
  final controller = _controller();
  controller.terms = [_term()];
  controller.selectedTermId = 't-fall';
  controller.timeSlots = [
    _slot(id: 'ts1', dayOfWeek: 2, start: '10:00:00', end: '10:30:00'),
    _slot(id: 'ts2', dayOfWeek: 2, start: '10:30:00', end: '11:00:00'),
    _slot(id: 'ts-thu', dayOfWeek: 4),
  ];
  controller.allTermSessions = [
    // 같은 과목이 반 2개 × 교시 2개 = 4개 세션에 걸려 있다.
    _session(id: 'cs1', courseId: 'c-qt', timeSlotId: 'ts1', classGroupId: 'a'),
    _session(id: 'cs2', courseId: 'c-qt', timeSlotId: 'ts2', classGroupId: 'a'),
    _session(id: 'cs3', courseId: 'c-qt', timeSlotId: 'ts1', classGroupId: 'b'),
    _session(id: 'cs4', courseId: 'c-qt', timeSlotId: 'ts2', classGroupId: 'b'),
    // 다른 과목(목요일)은 섞이지 않아야 한다.
    _session(id: 'cs5', courseId: 'c-kor', timeSlotId: 'ts-thu'),
  ];
  return controller;
}

/// 좁은 모바일 폭(360x780)으로 고정한 앱 셸. DateFormat('...', 'ko') 를 쓰므로
/// 로컬라이제이션 델리게이트를 붙여 ko 날짜 심볼이 초기화되게 한다
/// (admin_view_mobile_test 와 같은 이유).
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
      body: Padding(padding: const EdgeInsets.all(10), child: child),
    ),
  );
}

Future<void> _setMobileSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _setViewSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('NestController 회차 헬퍼', () {
    test('courseWeekdays: 세션이 여러 개여도 요일은 중복 없이 모인다', () {
      final controller = _wholeSchoolTuesdayCourse();

      expect(controller.courseWeekdays('c-qt'), {2});
      expect(controller.courseWeekdays('c-kor'), {4});
      expect(controller.courseWeekdays('c-none'), isEmpty);
      expect(controller.courseWeekdays(''), isEmpty);
    });

    test('lessonsForCourse: 해당 과목만 날짜 순으로 준다', () {
      final controller = _wholeSchoolTuesdayCourse();
      controller.courseLessons = [
        _lesson(id: 'l3', date: '2026-09-22'),
        _lesson(id: 'l1', date: '2026-09-08'),
        _lesson(id: 'other', date: '2026-09-10', courseId: 'c-kor'),
        _lesson(id: 'l2', date: '2026-09-15'),
      ];

      final rows = controller.lessonsForCourse('c-qt');
      expect(rows.map((row) => row.id).toList(), ['l1', 'l2', 'l3']);
      expect(controller.lessonsForCourse('c-kor').single.id, 'other');
      expect(controller.lessonsForCourse(''), isEmpty);
    });

    test('courseLessonOn: 날짜가 정확히 맞는 회차만 찾는다', () {
      final controller = _wholeSchoolTuesdayCourse();
      controller.courseLessons = [_lesson(id: 'l1', date: '2026-09-15')];

      expect(
        controller
            .courseLessonOn(courseId: 'c-qt', date: DateTime(2026, 9, 15))
            ?.id,
        'l1',
      );
      // 시분초가 붙어도 같은 날짜면 찾아야 한다.
      expect(
        controller
            .courseLessonOn(
              courseId: 'c-qt',
              date: DateTime(2026, 9, 15, 23, 30),
            )
            ?.id,
        'l1',
      );
      expect(
        controller.courseLessonOn(
          courseId: 'c-qt',
          date: DateTime(2026, 9, 16),
        ),
        isNull,
      );
      // 과목이 다르면 같은 날짜여도 안 된다.
      expect(
        controller.courseLessonOn(
          courseId: 'c-kor',
          date: DateTime(2026, 9, 15),
        ),
        isNull,
      );
    });

    test('upcomingCourseLesson: 기준일 이후 첫 회차(당일 포함)를 준다', () {
      final controller = _wholeSchoolTuesdayCourse();
      controller.courseLessons = [
        _lesson(id: 'l1', date: '2026-09-08'),
        _lesson(id: 'l2', date: '2026-09-15'),
        _lesson(id: 'l3', date: '2026-09-22'),
      ];

      expect(
        controller
            .upcomingCourseLesson(courseId: 'c-qt', from: DateTime(2026, 9, 9))
            ?.id,
        'l2',
      );
      // 당일은 포함한다.
      expect(
        controller
            .upcomingCourseLesson(courseId: 'c-qt', from: DateTime(2026, 9, 15))
            ?.id,
        'l2',
      );
      // 마지막 회차 이후면 null.
      expect(
        controller.upcomingCourseLesson(
          courseId: 'c-qt',
          from: DateTime(2026, 9, 23),
        ),
        isNull,
      );
    });

    test('canManageCourseLessons: 교사·관리자만 true', () {
      final controller = _controller();

      controller.currentRole = 'HOMESCHOOL_ADMIN';
      expect(controller.canManageCourseLessons, isTrue);
      controller.currentRole = 'STAFF';
      expect(controller.canManageCourseLessons, isTrue);
      controller.currentRole = 'TEACHER';
      expect(controller.canManageCourseLessons, isTrue);
      controller.currentRole = 'PARENT';
      expect(controller.canManageCourseLessons, isFalse);
      controller.currentRole = 'STUDENT';
      expect(controller.canManageCourseLessons, isFalse);
    });
  });

  group('buildCourseLessonRows', () {
    test('학기 기간의 수업 요일을 모두 펼쳐 빈 회차 자리를 만든다', () {
      final controller = _wholeSchoolTuesdayCourse();

      final rows = buildCourseLessonRows(controller, 'c-qt');

      // 2026-09-01 ~ 2026-11-30 사이의 화요일은 13번.
      expect(rows.length, 13);
      expect(rows.first.date, DateTime(2026, 9, 1));
      expect(rows.last.date, DateTime(2026, 11, 24));
      expect(rows.every((row) => row.date.weekday == DateTime.tuesday), isTrue);
      expect(rows.every((row) => row.isInTerm), isTrue);
      expect(rows.every((row) => row.lesson == null), isTrue);
      expect(rows.every((row) => !row.isFilled), isTrue);
    });

    test('저장된 회차가 같은 날짜 자리에 붙는다(중복 줄이 생기지 않는다)', () {
      final controller = _wholeSchoolTuesdayCourse();
      controller.courseLessons = [
        _lesson(id: 'l1', date: '2026-09-15', presenter: '리아'),
      ];

      final rows = buildCourseLessonRows(controller, 'c-qt');

      expect(rows.length, 13);
      final matched = rows.where((row) => row.lesson != null).toList();
      expect(matched.length, 1);
      expect(matched.single.date, DateTime(2026, 9, 15));
      expect(matched.single.lesson!.presenter, '리아');
      expect(matched.single.isFilled, isTrue);
    });

    test('학기 종료일을 넘긴 회차도 목록에 남고 isInTerm 이 false 다', () {
      final controller = _wholeSchoolTuesdayCourse();
      controller.courseLessons = [
        _lesson(id: 'dec1', date: '2026-12-01'),
        _lesson(id: 'dec2', date: '2026-12-08'),
        _lesson(id: 'dec3', date: '2026-12-15'),
      ];

      final rows = buildCourseLessonRows(controller, 'c-qt');

      // 학기 내 화요일 13개 + 학기 밖 12월 3개.
      expect(rows.length, 16);
      final outside = rows.where((row) => !row.isInTerm).toList();
      expect(outside.length, 3);
      expect(outside.map((row) => row.date.month).toSet(), {12});
      // 날짜 순서가 유지된다.
      expect(rows.last.date, DateTime(2026, 12, 15));
    });

    test('시간표에 없는 과목은 저장된 회차만 보여준다', () {
      final controller = _wholeSchoolTuesdayCourse();
      controller.courseLessons = [
        _lesson(id: 'l1', date: '2026-09-15', courseId: 'c-orphan'),
      ];

      final rows = buildCourseLessonRows(controller, 'c-orphan');

      expect(rows.length, 1);
      expect(rows.single.date, DateTime(2026, 9, 15));
      // 빈 자리를 만들 요일 정보는 없지만 날짜 자체는 학기 안이다.
      // isInTerm 은 요일이 아니라 학기 기간만 본다.
      expect(rows.single.isInTerm, isTrue);
    });

    test('학기 중 보강(수업 요일이 아닌 날)은 학기 밖으로 찍히지 않는다', () {
      final controller = _wholeSchoolTuesdayCourse();
      controller.courseLessons = [
        // 학기(9/1~11/30) 안이지만 화요일이 아닌 목요일 보강.
        _lesson(id: 'makeup', date: '2026-10-08'),
      ];

      final rows = buildCourseLessonRows(controller, 'c-qt');
      final makeup = rows.firstWhere((row) => row.lesson?.id == 'makeup');

      expect(makeup.date.weekday, DateTime.thursday);
      expect(makeup.isInTerm, isTrue);
    });

    test('학기 기간을 벗어난 회차만 학기 밖으로 찍힌다', () {
      final controller = _wholeSchoolTuesdayCourse();
      controller.courseLessons = [
        _lesson(id: 'before', date: '2026-08-25'),
        _lesson(id: 'inside', date: '2026-09-15'),
        _lesson(id: 'after', date: '2026-12-15'),
      ];

      final byId = {
        for (final row in buildCourseLessonRows(controller, 'c-qt'))
          if (row.lesson != null) row.lesson!.id: row,
      };

      expect(byId['before']!.isInTerm, isFalse);
      expect(byId['inside']!.isInTerm, isTrue);
      expect(byId['after']!.isInTerm, isFalse);
    });

    test('학기가 선택되지 않았으면 저장된 회차만 나온다', () {
      final controller = _wholeSchoolTuesdayCourse();
      controller.selectedTermId = null;
      controller.courseLessons = [_lesson(id: 'l1', date: '2026-09-15')];

      final rows = buildCourseLessonRows(controller, 'c-qt');

      expect(rows.length, 1);
      expect(rows.single.lesson!.id, 'l1');
    });
  });

  group('CourseLessonSummary (모바일 폭)', () {
    testWidgets('내용이 있으면 회차 수와 담당이 함께 보이고, 입력 버튼이 뜬다', (tester) async {
      await _setMobileSize(tester);
      final controller = _wholeSchoolTuesdayCourse();
      controller.currentRole = 'HOMESCHOOL_ADMIN';
      controller.courseLessons = [
        _lesson(id: 'l1', date: '2026-09-15', presenter: '리아'),
      ];

      await tester.pumpWidget(
        _mobileApp(
          CourseLessonSummary(
            controller: controller,
            courseId: 'c-qt',
            referenceDate: DateTime(2026, 9, 15),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('수업 내용'), findsOneWidget);
      expect(find.text('1회차'), findsOneWidget);
      expect(find.text('창세기 36장'), findsOneWidget);
      expect(find.text('담당 리아'), findsOneWidget);
      expect(find.text('회차별 내용 입력'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('모든 회차가 지났으면 (지난 회차)로 표시한다', (tester) async {
      await _setMobileSize(tester);
      final controller = _wholeSchoolTuesdayCourse();
      controller.currentRole = 'PARENT';
      controller.courseLessons = [
        _lesson(id: 'l1', date: '2026-09-08'),
        _lesson(id: 'l2', date: '2026-09-15'),
      ];

      await tester.pumpWidget(
        _mobileApp(
          CourseLessonSummary(
            controller: controller,
            courseId: 'c-qt',
            // 마지막 회차보다 두 달 뒤 — 다음 회차는 존재하지 않는다.
            referenceDate: DateTime(2026, 11, 24),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('(지난 회차)'), findsOneWidget);
      expect(find.text('(다음 회차)'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('기준일 이후 회차가 있으면 (다음 회차)로 표시한다', (tester) async {
      await _setMobileSize(tester);
      final controller = _wholeSchoolTuesdayCourse();
      controller.currentRole = 'PARENT';
      controller.courseLessons = [_lesson(id: 'l1', date: '2026-09-15')];

      await tester.pumpWidget(
        _mobileApp(
          CourseLessonSummary(
            controller: controller,
            courseId: 'c-qt',
            referenceDate: DateTime(2026, 9, 8),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('(다음 회차)'), findsOneWidget);
      expect(find.text('(지난 회차)'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('그 날짜의 회차면 아무 라벨도 붙지 않는다', (tester) async {
      await _setMobileSize(tester);
      final controller = _wholeSchoolTuesdayCourse();
      controller.currentRole = 'PARENT';
      controller.courseLessons = [_lesson(id: 'l1', date: '2026-09-15')];

      await tester.pumpWidget(
        _mobileApp(
          CourseLessonSummary(
            controller: controller,
            courseId: 'c-qt',
            referenceDate: DateTime(2026, 9, 15),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('(다음 회차)'), findsNothing);
      expect(find.text('(지난 회차)'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('학생·학부모에게는 읽기 전용 문구로 보인다', (tester) async {
      await _setMobileSize(tester);
      final controller = _wholeSchoolTuesdayCourse();
      controller.currentRole = 'PARENT';
      controller.courseLessons = [_lesson(id: 'l1', date: '2026-09-15')];

      await tester.pumpWidget(
        _mobileApp(
          CourseLessonSummary(controller: controller, courseId: 'c-qt'),
        ),
      );
      await tester.pump();

      expect(find.text('전체 진도표 보기'), findsOneWidget);
      expect(find.text('회차별 내용 입력'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('회차가 없으면 권한별 안내 문구가 다르다', (tester) async {
      await _setMobileSize(tester);
      final admin = _wholeSchoolTuesdayCourse();
      admin.currentRole = 'HOMESCHOOL_ADMIN';

      await tester.pumpWidget(
        _mobileApp(CourseLessonSummary(controller: admin, courseId: 'c-qt')),
      );
      await tester.pump();
      expect(find.text('아직 입력된 회차 내용이 없습니다.'), findsOneWidget);

      final parent = _wholeSchoolTuesdayCourse();
      parent.currentRole = 'PARENT';

      await tester.pumpWidget(
        _mobileApp(CourseLessonSummary(controller: parent, courseId: 'c-qt')),
      );
      await tester.pump();
      expect(find.text('아직 등록된 수업 내용이 없습니다.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('showCourseLessonSheet (모바일 폭)', () {
    /// 시트는 modal route 라 트리거 위젯을 태워서 띄운다.
    Future<void> openSheet(
      WidgetTester tester,
      NestController controller,
    ) async {
      await _setMobileSize(tester);
      await tester.pumpWidget(
        _mobileApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showCourseLessonSheet(
                context: context,
                controller: controller,
                courseId: 'c-qt',
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    }

    testWidgets('관리자에게는 빈 회차 자리까지 전부 보인다', (tester) async {
      final controller = _wholeSchoolTuesdayCourse();
      controller.currentRole = 'HOMESCHOOL_ADMIN';
      controller.courseLessons = [
        _lesson(id: 'l1', date: '2026-09-15', presenter: '리아'),
      ];

      await openSheet(tester, controller);

      expect(find.text('수업 회차 내용'), findsOneWidget);
      expect(find.text('전체 13회차 중 1회차 입력됨'), findsOneWidget);
      expect(find.text('다른 날짜로 회차 추가'), findsOneWidget);
      // 아직 비어 있는 자리도 줄로 보인다.
      expect(find.text('내용 없음'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('학생·학부모에게는 채워진 회차만 보인다', (tester) async {
      final controller = _wholeSchoolTuesdayCourse();
      controller.currentRole = 'PARENT';
      controller.courseLessons = [
        _lesson(id: 'l1', date: '2026-09-15', presenter: '리아'),
      ];

      await openSheet(tester, controller);

      expect(find.text('수업 회차 내용'), findsOneWidget);
      expect(find.text('1회차'), findsOneWidget);
      expect(find.text('창세기 36장'), findsOneWidget);
      // 빈 자리와 편집 진입점은 감춘다.
      expect(find.text('내용 없음'), findsNothing);
      expect(find.text('다른 날짜로 회차 추가'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('회차 자리는 있어도 내용이 없으면 읽기 전용은 안내 문구만 본다', (tester) async {
      final controller = _wholeSchoolTuesdayCourse();
      controller.currentRole = 'PARENT';

      await openSheet(tester, controller);

      expect(
        find.text('아직 등록된 수업 내용이 없습니다. 선생님이 입력하면 여기에 보입니다.'),
        findsOneWidget,
      );
      expect(find.text('내용 없음'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('showCourseLessonSheet 짧은 뷰포트 (회귀)', () {
    /// 가로모드 폰·낮은 브라우저 창. 목록 영역을 화면 높이의 고정 비율로 잡으면
    /// 고정 헤더와 합이 화면을 넘겨 오버플로가 났다(Flexible 로 고친 회귀 케이스).
    Future<void> openAt(WidgetTester tester, Size size) async {
      await _setViewSize(tester, size);
      final controller = _wholeSchoolTuesdayCourse();
      controller.currentRole = 'HOMESCHOOL_ADMIN';
      controller.courseLessons = [
        _lesson(id: 'l1', date: '2026-09-15', presenter: '리아'),
      ];

      await tester.pumpWidget(
        _mobileApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showCourseLessonSheet(
                context: context,
                controller: controller,
                courseId: 'c-qt',
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    }

    for (final size in const [
      Size(800, 390), // iPhone 가로
      Size(800, 400),
      Size(800, 480),
      Size(360, 430), // 좁고 낮은 창
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} 에서 오버플로가 없다', (
        tester,
      ) async {
        await openAt(tester, size);

        expect(find.text('수업 회차 내용'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('세로가 넉넉하면 시트가 화면을 다 먹지 않는다', (tester) async {
      await openAt(tester, const Size(360, 780));

      // Flexible 은 loose fit 이라 내용이 짧으면 그만큼만 차지해야 한다.
      final sheetHeight = tester.getSize(find.byType(SingleChildScrollView).first).height;
      expect(sheetHeight, lessThan(780));
      expect(tester.takeException(), isNull);
    });
  });

  group('courseLessonReferenceDate', () {
    test('슬롯이 없으면 null', () {
      final controller = _wholeSchoolTuesdayCourse();
      expect(courseLessonReferenceDate(controller, null), isNull);
    });

    test('학기 시작 전이면 학기 안 첫 수업 요일로 잡힌다', () {
      final controller = _wholeSchoolTuesdayCourse();
      // 학기(2026-09-01~11-30)는 이 테스트를 돌리는 현재 시각보다 과거일 수
      // 있으므로, 결과가 항상 만족해야 하는 성질만 검증한다.
      final date = courseLessonReferenceDate(
        controller,
        _slot(id: 'ts1', dayOfWeek: 2),
      );

      expect(date, isNotNull);
      // 학기 끝을 넘지 않는다.
      expect(date!.isAfter(DateTime(2026, 11, 30)), isFalse);
      // 학기 시작보다 이르지 않다.
      expect(date.isBefore(DateTime(2026, 9, 1)), isFalse);
    });
  });
}
