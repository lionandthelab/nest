// 시간표 주간판이 실제로 그려지는지.
//
// 이 화면은 위젯 테스트가 하나도 없었다. 그래서 격자 머리글 Row 에
// CrossAxisAlignment.stretch 를 넣어 "BoxConstraints forces an infinite height"
// 로 화면이 통째로 깨졌는데도 테스트 251개가 전부 통과했고, 시뮬레이터에
// 올려서야 발견했다. 레이아웃을 건드릴 때 그런 일이 다시 없도록 최소한의
// 렌더 보증을 둔다.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/models/child_class_bundle.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/tabs/parent_timetable_tab.dart';

const _termId = 't-fall';

NestController _controller() {
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final controller = NestController(repository: NestRepository(client));
  controller.currentRole = 'PARENT';
  controller.selectedHomeschoolId = 'hs-1';
  controller.selectedTermId = _termId;
  controller.terms = [
    Term.fromMap({
      'id': _termId,
      'homeschool_id': 'hs-1',
      'name': '2026 가을',
      'status': 'ACTIVE',
      'start_date': '2026-09-01',
      'end_date': '2026-12-18',
    }),
  ];
  controller.timeSlots = [
    for (var day = 1; day <= 5; day++)
      for (final row in [
        ['a', '09:00:00', '09:30:00'],
        ['b', '09:30:00', '10:00:00'],
      ])
        TimeSlot.fromMap({
          'id': 'ts-$day-${row[0]}',
          'term_id': _termId,
          'day_of_week': day,
          'start_time': row[1],
          'end_time': row[2],
        }),
  ];
  controller.courses = [
    Course.fromMap({
      'id': 'c-1',
      'homeschool_id': 'hs-1',
      'name': '독서(초6)',
      'default_duration_min': 30,
    }),
  ];
  controller.classGroups = [
    ClassGroup.fromMap({'id': 'cg-1', 'term_id': _termId, 'name': '초6'}),
  ];
  return controller;
}

Map<String, ChildClassBundle> _bundles() {
  final sessions = [
    for (var day = 1; day <= 5; day++)
      ClassSession.fromMap({
        'id': 'cs-$day',
        'class_group_id': 'cg-1',
        'course_id': 'c-1',
        'time_slot_id': 'ts-$day-a',
        'title': '',
        'source_type': 'MANUAL',
        'status': 'PLANNED',
        'location': '3,소망',
      }),
  ];
  return {
    'cg-1': ChildClassBundle(
      classGroup: ClassGroup.fromMap({
        'id': 'cg-1',
        'term_id': _termId,
        'name': '초6',
      }),
      sessions: sessions,
      assignments: const [],
      announcements: const [],
    ),
  };
}

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: NestTheme.light(),
      locale: const Locale('ko'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en')],
      home: Scaffold(
        body: ParentTimetableTab(
          controller: _controller(),
          selectedChildId: 'child-1',
          childClassBundles: _bundles(),
          isLoadingChildClasses: false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [
    Size(360, 780), // 좁은 안드로이드
    Size(393, 852), // iPhone 16
    Size(430, 932), // iPhone 16 Pro Max
  ]) {
    testWidgets('주간판이 ${size.width.toInt()}폭에서 예외 없이 그려진다', (tester) async {
      await _pump(tester, size);

      // 요일 머리글이 실제로 나와야 격자가 그려진 것이다.
      expect(find.textContaining('월'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
