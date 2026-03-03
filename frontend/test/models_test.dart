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
  });
}
