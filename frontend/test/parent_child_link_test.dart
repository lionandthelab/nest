import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';

// 네트워크를 타지 않는 컨트롤러. autoRefreshToken 을 꺼야 GoTrue 타이머가
// 남지 않는다.
NestController _controller() {
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return NestController(repository: NestRepository(client));
}

void main() {
  group('가정·보호자 데이터 로드 대상', () {
    // 학부모 헤더의 아이 선택기(myChildren)는 family_guardians 로 내 아이를
    // 찾는다. 학부모 뷰에서 이 데이터를 안 불러오면 아이가 하나도 안 보인다.
    test('학부모 뷰는 가정·보호자 데이터를 불러온다', () {
      final controller = _controller();
      controller.currentRole = 'PARENT';

      expect(controller.needsFamilyGuardianData, isTrue);
    });

    test('관리자·스태프 뷰는 가정·보호자 데이터를 불러온다', () {
      final controller = _controller();

      controller.currentRole = 'HOMESCHOOL_ADMIN';
      expect(controller.needsFamilyGuardianData, isTrue);

      controller.currentRole = 'STAFF';
      expect(controller.needsFamilyGuardianData, isTrue);
    });

    test('교사·학생 뷰는 가정·보호자 데이터가 필요 없다', () {
      final controller = _controller();

      controller.currentRole = 'TEACHER';
      expect(controller.needsFamilyGuardianData, isFalse);

      controller.currentRole = 'STUDENT';
      expect(controller.needsFamilyGuardianData, isFalse);
    });
  });
}
