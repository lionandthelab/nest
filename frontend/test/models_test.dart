import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/models/nest_models.dart';

void main() {
  group('model helpers', () {
    test('parseBool supports common string/number values', () {
      expect(parseBool(true), isTrue);
      expect(parseBool('true'), isTrue);
      expect(parseBool('1'), isTrue);
      expect(parseBool(1), isTrue);
      expect(parseBool('false'), isFalse);
      expect(parseBool('0'), isFalse);
      expect(parseBool(0), isFalse);
      expect(parseBool('unknown', fallback: true), isTrue);
    });

    test('HomeschoolInvite.fromMap parses nested homeschool payload', () {
      final invite = HomeschoolInvite.fromMap({
        'id': 'inv-1',
        'homeschool_id': 'school-1',
        'invite_email': 'parent@example.com',
        'role': 'PARENT',
        'status': 'PENDING',
        'invite_token': 'token-1',
        'expires_at': DateTime.now()
            .add(const Duration(days: 2))
            .toUtc()
            .toIso8601String(),
        'created_at': DateTime.now()
            .subtract(const Duration(days: 1))
            .toUtc()
            .toIso8601String(),
        'homeschools': {'id': 'school-1', 'name': 'Warm Nest'},
      });

      expect(invite.id, 'inv-1');
      expect(invite.homeschoolId, 'school-1');
      expect(invite.homeschoolName, 'Warm Nest');
      expect(invite.role, 'PARENT');
      expect(invite.isPending, isTrue);
      expect(invite.canAccept, isTrue);
      expect(invite.isExpired, isFalse);
    });

    test('HomeschoolInvite.canAccept is false when invite is expired', () {
      final invite = HomeschoolInvite.fromMap({
        'id': 'inv-2',
        'homeschool_id': 'school-2',
        'homeschool_name': 'Warm Nest 2',
        'invite_email': 'teacher@example.com',
        'role': 'TEACHER',
        'status': 'PENDING',
        'invite_token': 'token-2',
        'expires_at': DateTime.now()
            .subtract(const Duration(hours: 3))
            .toUtc()
            .toIso8601String(),
      });

      expect(invite.isPending, isTrue);
      expect(invite.isExpired, isTrue);
      expect(invite.canAccept, isFalse);
      expect(invite.homeschoolName, 'Warm Nest 2');
    });

    test('ChildProfile.fromMap reads nested family fields', () {
      final child = ChildProfile.fromMap({
        'id': 'child-1',
        'family_id': 'fam-1',
        'name': 'Mina',
        'birth_date': '2019-05-12',
        'profile_note': 'likes reading',
        'status': 'ACTIVE',
        'families': {'family_name': 'Kim Family', 'homeschool_id': 'school-1'},
      });

      expect(child.id, 'child-1');
      expect(child.familyId, 'fam-1');
      expect(child.familyName, 'Kim Family');
      expect(child.name, 'Mina');
      expect(child.status, 'ACTIVE');
    });

    test('TeacherProfile.fromMap supports parent-teacher type', () {
      final profile = TeacherProfile.fromMap({
        'id': 'teacher-1',
        'homeschool_id': 'school-1',
        'user_id': 'user-1',
        'display_name': 'Teacher Lee',
        'teacher_type': 'PARENT_TEACHER',
        'specialties': ['math', 'science'],
      });

      expect(profile.id, 'teacher-1');
      expect(profile.isParentTeacher, isTrue);
      expect(profile.specialties, hasLength(2));
      expect(profile.displayName, 'Teacher Lee');
    });

    test('HomeschoolMemberDirectoryEntry.fromMap parses label and roles', () {
      final entry = HomeschoolMemberDirectoryEntry.fromMap({
        'user_id': 'user-2',
        'email': 'teacher@example.com',
        'full_name': 'Teacher Kim',
        'roles': ['TEACHER', 'PARENT'],
      });

      expect(entry.userId, 'user-2');
      expect(entry.email, 'teacher@example.com');
      expect(entry.fullName, 'Teacher Kim');
      expect(entry.roles, containsAll(['TEACHER', 'PARENT']));
      expect(entry.displayLabel, 'Teacher Kim <teacher@example.com>');
    });

    test('HomeschoolDirectoryEntry.fromMap parses search payload fields', () {
      final entry = HomeschoolDirectoryEntry.fromMap({
        'id': 'school-3',
        'name': 'Nest Warm Home',
        'timezone': 'Asia/Seoul',
        'active_member_count': 17,
        'has_pending_request': true,
      });

      expect(entry.id, 'school-3');
      expect(entry.name, 'Nest Warm Home');
      expect(entry.activeMemberCount, 17);
      expect(entry.hasPendingRequest, isTrue);
    });
  });

  group('Term.phaseAt', () {
    Term term({String start = '2026-03-01', String end = '2026-07-31'}) {
      return Term.fromMap({
        'id': 't1',
        'homeschool_id': 's1',
        'name': '2026-1',
        'status': 'ACTIVE',
        'start_date': start,
        'end_date': end,
      });
    }

    test('before start date is upcoming', () {
      expect(term().phaseAt(DateTime(2026, 2, 15)), TermPhase.upcoming);
    });

    test('after end date is past', () {
      expect(term().phaseAt(DateTime(2026, 8, 15)), TermPhase.past);
    });

    test('within the range is current', () {
      expect(term().phaseAt(DateTime(2026, 5, 10)), TermPhase.current);
    });

    test('boundary days (start/end) are inclusive → current', () {
      expect(term().phaseAt(DateTime(2026, 3, 1)), TermPhase.current);
      expect(term().phaseAt(DateTime(2026, 7, 31)), TermPhase.current);
      // 하루 단위 비교이므로 종료일 당일 늦은 시각도 현재로 취급.
      expect(term().phaseAt(DateTime(2026, 7, 31, 23, 59)), TermPhase.current);
    });

    test('null dates fall back to current', () {
      final t = Term.fromMap({
        'id': 't2',
        'homeschool_id': 's1',
        'name': '미정',
        'status': 'DRAFT',
        'start_date': null,
        'end_date': null,
      });
      expect(t.phaseAt(DateTime(2026, 5, 10)), TermPhase.current);
    });

    test('isArchived reflects status', () {
      expect(term().isArchived, isFalse);
      expect(term(start: '2025-01-01', end: '2025-06-30').isArchived, isFalse);
      final archived = Term.fromMap({
        'id': 't3',
        'homeschool_id': 's1',
        'name': '보관',
        'status': 'ARCHIVED',
        'start_date': '2025-01-01',
        'end_date': '2025-06-30',
      });
      expect(archived.isArchived, isTrue);
    });
  });
}
