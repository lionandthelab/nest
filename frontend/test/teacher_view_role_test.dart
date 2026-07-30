import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';

Membership _membership(String userId, String role, {String status = 'ACTIVE'}) =>
    Membership.fromMap({
      'user_id': userId,
      'homeschool_id': 's1',
      'role': role,
      'status': status,
    });

NestController _controller(List<Membership> memberships) {
  // 네트워크를 타지 않는 컨트롤러. hasTeacherViewRole 은 homeschoolMemberships
  // 캐시만 읽는다. autoRefreshToken 을 꺼야 GoTrue 타이머가 남지 않는다.
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final controller = NestController(repository: NestRepository(client));
  controller.homeschoolMemberships = memberships;
  return controller;
}

void main() {
  test('교사 프로필에 연결된 계정이 PARENT 뿐이면 교사 권한이 필요하다고 본다', () {
    final controller = _controller([_membership('u-sujin', 'PARENT')]);

    expect(controller.hasTeacherViewRole('u-sujin'), isFalse);
  });

  test('TEACHER·GUEST_TEACHER·관리자·스태프는 이미 교사 화면에 접근할 수 있다', () {
    final controller = _controller([
      _membership('u-teacher', 'TEACHER'),
      _membership('u-guest', 'GUEST_TEACHER'),
      _membership('u-admin', 'HOMESCHOOL_ADMIN'),
      _membership('u-staff', 'STAFF'),
    ]);

    expect(controller.hasTeacherViewRole('u-teacher'), isTrue);
    expect(controller.hasTeacherViewRole('u-guest'), isTrue);
    expect(controller.hasTeacherViewRole('u-admin'), isTrue);
    expect(controller.hasTeacherViewRole('u-staff'), isTrue);
  });

  test('비활성 멤버십이나 다른 사용자의 TEACHER 역할은 인정하지 않는다', () {
    final controller = _controller([
      _membership('u-left', 'TEACHER', status: 'INACTIVE'),
      _membership('u-other', 'TEACHER'),
    ]);

    expect(controller.hasTeacherViewRole('u-left'), isFalse);
    expect(controller.hasTeacherViewRole('u-unknown'), isFalse);
  });
}
