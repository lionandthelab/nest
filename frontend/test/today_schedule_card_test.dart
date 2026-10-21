import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/schedule_occurrence.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/widgets/today_schedule_card.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko');
  });

  final date = DateTime(2026, 9, 8);
  final occurrences = [
    ResolvedOccurrence(
      session: const ClassSession(
        id: 's-1',
        classGroupId: 'g-1',
        courseId: 'c-math',
        timeSlotId: 't-1',
        title: '',
        sourceType: 'MANUAL',
        status: 'PLANNED',
        location: '2층',
      ),
      slot: const TimeSlot(
        id: 't-1',
        termId: 'term',
        dayOfWeek: 2,
        startTime: '10:00:00',
        endTime: '11:00:00',
      ),
      date: date,
    ),
    ResolvedOccurrence(
      session: const ClassSession(
        id: 's-2',
        classGroupId: 'g-1',
        courseId: 'c-eng',
        timeSlotId: 't-2',
        title: '',
        sourceType: 'MANUAL',
        status: 'PLANNED',
        location: '3층',
      ),
      slot: const TimeSlot(
        id: 't-2',
        termId: 'term',
        dayOfWeek: 2,
        startTime: '13:00:00',
        endTime: '14:00:00',
      ),
      date: date,
    ),
  ];

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: NestTheme.light(),
      locale: const Locale('ko'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en')],
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  testWidgets('다음 수업 제목과 남은 수업을 보여 준다', (tester) async {
    await tester.pumpWidget(
      wrap(
        TodayScheduleCard(
          now: DateTime(2026, 9, 8, 9, 0),
          occurrences: occurrences,
          courseNameOf: (id) => id == 'c-math' ? '수학' : '영어',
          classNameOf: (_) => '2반',
        ),
      ),
    );

    expect(find.text('다음 수업'), findsOneWidget);
    expect(find.text('수학'), findsOneWidget);
    expect(find.text('오늘 남은 수업 1개'), findsOneWidget);
    expect(find.textContaining('영어'), findsOneWidget);
  });

  testWidgets('멀티 위젯 스타일 전환(포커스·타임라인·심플목록·체크카드)과 전체 시간표 보기 액션이 동작한다', (
    tester,
  ) async {
    var expanded = false;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => wrap(
          TodayScheduleCard(
            now: DateTime(2026, 9, 8, 9, 0),
            occurrences: occurrences,
            courseNameOf: (id) => id == 'c-math' ? '수학' : '영어',
            classNameOf: (_) => '2반',
            teacherNameOf: (_) => '김선생',
            lessonLabelOf: (row) =>
                row.session.courseId == 'c-math' ? '분수의 덧셈' : '파닉스 기초',
            titleLabel: '하준이의 오늘 수업',
            enableStyleSwitcher: true,
            isFullTimetableExpanded: expanded,
            onToggleFullTimetable: () => setState(() => expanded = !expanded),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('하준이의 오늘 수업'), findsOneWidget);
    expect(find.text('오늘 2교시'), findsOneWidget);
    expect(find.text('전체 시간표 보기'), findsOneWidget);

    // 1. 타임라인 위젯으로 전환
    await tester.tap(find.text('타임라인'));
    await tester.pumpAndSettle();
    expect(find.text('진도: 분수의 덧셈'), findsOneWidget);
    expect(find.text('진도: 파닉스 기초'), findsOneWidget);

    // 2. 심플목록 위젯으로 전환
    await tester.tap(find.text('심플목록'));
    await tester.pumpAndSettle();
    expect(find.text('10:00–11:00'), findsOneWidget);
    expect(find.text('13:00–14:00'), findsOneWidget);

    // 3. 체크카드 위젯으로 전환 및 수업 완료 체크
    await tester.tap(find.text('체크카드'));
    await tester.pumpAndSettle();
    expect(find.text('수업 체크 완료 0 / 2'), findsOneWidget);
    await tester.tap(find.text('수학'));
    await tester.pumpAndSettle();
    expect(find.text('수업 체크 완료 1 / 2'), findsOneWidget);

    // 4. 전체 시간표 보기 버튼 클릭 시 확장 상태 토글
    await tester.tap(find.text('전체 시간표 보기'));
    await tester.pumpAndSettle();
    expect(expanded, isTrue);
    expect(find.text('전체 시간표 접기'), findsOneWidget);
  });
}
