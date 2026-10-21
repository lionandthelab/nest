import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/course_schedule_quick_adder.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/widgets/course_schedule_quick_sheet.dart';
import 'package:nest_frontend/src/ui/widgets/spouse_invite_sheet.dart';

NestController _testController() {
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final controller = NestController(repository: NestRepository(client));
  controller.currentRole = 'HOMESCHOOL_ADMIN';
  controller.selectedHomeschoolId = 'hs-1';
  controller.selectedTermId = 't-1';
  controller.memberships = [
    Membership.fromMap({
      'user_id': 'u-1',
      'homeschool_id': 'hs-1',
      'role': 'HOMESCHOOL_ADMIN',
      'status': 'ACTIVE',
      'homeschools': {
        'id': 'hs-1',
        'name': '우리집 홈스쿨',
        'timezone': 'Asia/Seoul',
        'join_code': 'AB12CD',
      },
    }),
  ];
  return controller;
}

void main() {
  test('새 학기 틀을 만들 때 교실 "집"이 하나 들어간다', () {
    final rows = NestRepository.bootstrapClassroomRows(termId: 't-1');
    expect(rows, hasLength(1));
    expect(rows.single['term_id'], 't-1');
    expect(rows.single['name'], '집');
  });

  test('기본 타임슬롯은 평일(월~금) 09:00~18:00 (50분 수업, 10분 쉬는시간) 9교시×5일=45개로 생성된다', () {
    expect(NestRepository.defaultTimeSlotPeriods, hasLength(9));
    expect(NestRepository.defaultTimeSlotPeriods.first, ('09:00', '09:50'));
    expect(NestRepository.defaultTimeSlotPeriods.last, ('17:00', '17:50'));

    final rows = NestRepository.bootstrapTimeSlotRows(termId: 't-1');
    expect(rows, hasLength(45));
    expect(rows.first['term_id'], 't-1');
    expect(rows.first['day_of_week'], 1);
    expect(rows.first['start_time'], '09:00');
    expect(rows.first['end_time'], '09:50');
    expect(rows.last['day_of_week'], 5);
    expect(rows.last['start_time'], '17:00');
    expect(rows.last['end_time'], '17:50');
  });

  test('자연어 문장으로 과목과 시간표 배치를 파싱하고 예시 문장이 모두 정상 해석된다', () {
    expect(kCourseScheduleTemplates.length, greaterThanOrEqualTo(6));
    expect(kCourseScheduleExampleSentences, isNotEmpty);

    for (final example in kCourseScheduleExampleSentences) {
      final parsed = parseCourseScheduleSentence(example.sentence);
      expect(parsed.courses, isNotEmpty);
    }
    expect(
      parseCourseScheduleSentence(
        kCourseScheduleExampleSentences.first.sentence,
      ).placements,
      isNotEmpty,
    );

    final custom = parseCourseScheduleSentence(
      '월수금 9시 국어, 10시 수학 / 화목 오후 2시 미술 60분',
    );
    expect(
      custom.courses.map((c) => c.name).toList(),
      containsAll(['국어', '수학', '미술']),
    );
    final artCourse = custom.courses.firstWhere((c) => c.name == '미술');
    expect(artCourse.defaultDurationMin, 60);

    // 월수금 9시 국어(3) + 월수금 10시 수학(3) + 화목 14시 미술(2) = 8개 시간표 배치
    expect(custom.placements, hasLength(8));

    final slots = NestRepository.bootstrapTimeSlotRows(termId: 't-1')
        .asMap()
        .entries
        .map(
          (entry) => TimeSlot(
            id: 'slot-${entry.key}',
            termId: 't-1',
            dayOfWeek: entry.value['day_of_week'] as int,
            startTime: entry.value['start_time'] as String,
            endTime: entry.value['end_time'] as String,
          ),
        )
        .toList();

    final artThu = custom.placements.firstWhere(
      (p) => p.courseName == '미술' && p.dayOfWeek == 4,
    );
    final matchedArtThu = matchTimeSlotForPlacement(
      timeSlots: slots,
      dayOfWeek: artThu.dayOfWeek,
      startTime: artThu.startTime,
    );
    expect(matchedArtThu, isNotNull);
    expect(matchedArtThu!.startTime, '14:00');
  });

  testWidgets('엄마·아빠 초대 배너 및 시트, 템플릿·문장 수업 추가 시트가 렌더링된다', (tester) async {
    final controller = _testController();
    await tester.pumpWidget(
      MaterialApp(
        theme: NestTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SpouseInviteBannerCard(controller: controller),
                CourseScheduleQuickBanner(controller: controller),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('엄마면 아빠, 아빠면 엄마를 초대해'), findsOneWidget);
    expect(find.textContaining('템플릿·문장으로 수업 한 번에 추가'), findsOneWidget);

    await tester.tap(find.text('문장으로 수업 추가'));
    await tester.pumpAndSettle();

    expect(find.text('예시 문장 (누르면 입력창에 바로 채워져요)'), findsOneWidget);
    expect(
      find.text(kCourseScheduleExampleSentences.first.label),
      findsOneWidget,
    );
  });
}

