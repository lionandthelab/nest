import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/schedule_occurrence.dart';
import 'package:nest_frontend/src/ui/widgets/today_schedule_card.dart';

void main() {
  testWidgets('다음 수업 제목과 남은 수업을 보여 준다', (tester) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayScheduleCard(
            now: DateTime(2026, 9, 8, 9, 0),
            occurrences: occurrences,
            courseNameOf: (id) => id == 'c-math' ? '수학' : '영어',
            classNameOf: (_) => '2반',
          ),
        ),
      ),
    );

    expect(find.text('다음 수업'), findsOneWidget);
    expect(find.text('수학'), findsOneWidget);
    expect(find.text('오늘 남은 수업 1개'), findsOneWidget);
    expect(find.textContaining('영어'), findsOneWidget);
  });
}
