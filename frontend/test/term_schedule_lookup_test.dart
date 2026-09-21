import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';

NestController _controller() {
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return NestController(repository: NestRepository(client));
}

ClassSession _session({
  required String id,
  required String classGroupId,
}) => ClassSession.fromMap({
  'id': id,
  'class_group_id': classGroupId,
  'course_id': 'c1',
  'time_slot_id': 'ts1',
  'title': '',
  'source_type': 'MANUAL',
  'status': 'PLANNED',
});

SessionTeacherAssignment _assignment({
  required String sessionId,
  required String teacherId,
}) => SessionTeacherAssignment.fromMap({
  'id': '$sessionId-$teacherId',
  'class_session_id': sessionId,
  'teacher_profile_id': teacherId,
  'assignment_role': 'MAIN',
});

void main() {
  test('sessionsInClassGroup filters the term pack without extra fetches', () {
    final controller = _controller();
    controller.allTermSessions = [
      _session(id: 's-a', classGroupId: 'g-a'),
      _session(id: 's-b', classGroupId: 'g-b'),
      _session(id: 's-a2', classGroupId: 'g-a'),
    ];

    expect(
      controller.sessionsInClassGroup('g-a').map((row) => row.id),
      ['s-a', 's-a2'],
    );
    expect(controller.sessionsInClassGroup('g-missing'), isEmpty);
    expect(controller.hasTermSchedulePack, isTrue);
  });

  test('assignments and plans stay on the already-loaded term pack', () {
    final controller = _controller();
    controller.allTermSessions = [
      _session(id: 's-a', classGroupId: 'g-a'),
      _session(id: 's-b', classGroupId: 'g-b'),
    ];
    controller.allTermSessionTeacherAssignments = [
      _assignment(sessionId: 's-a', teacherId: 't-1'),
      _assignment(sessionId: 's-b', teacherId: 't-2'),
    ];
    controller.teachingPlans = [
      TeachingPlan.fromMap({
        'id': 'p-a',
        'class_session_id': 's-a',
        'teacher_profile_id': 't-1',
        'objectives': '목표',
      }),
      TeachingPlan.fromMap({
        'id': 'p-b',
        'class_session_id': 's-b',
        'teacher_profile_id': 't-2',
        'objectives': '다른 반',
      }),
    ];

    expect(
      controller.assignmentsForSessionIds(['s-a']).single.teacherProfileId,
      't-1',
    );
    expect(controller.teachingPlansForSessionIds(['s-a']).single.id, 'p-a');
    expect(controller.assignmentsForSessionIds(const []), isEmpty);
  });
}
