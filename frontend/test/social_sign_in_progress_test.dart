import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

Session _session(String userId) {
  return Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-09-24T00:00:00Z',
    ),
  );
}

/// 테스트 바인딩은 모든 HTTP 를 400 으로 돌려 계정 로드가 예외로 끝난다.
/// 실패로 끝나도 로그인 중 표시는 반드시 풀려야 한다.
Future<void> _signIn(NestController controller, Session? session) async {
  try {
    await controller.handleExternalAuthSession(session);
  } on PostgrestException {
    // expected: no network in tests
  }
}

void main() {
  testWidgets('브라우저에서 돌아오면 바로 로그인 중 상태가 된다', (tester) async {
    final controller = _controller();
    var notified = 0;
    controller.addListener(() => notified++);

    controller.markSocialSignInReturned();

    expect(controller.isSigningIn, isTrue);
    expect(notified, greaterThan(0));
    await tester.pump(const Duration(seconds: 25));
  });

  testWidgets('세션이 끝내 오지 않으면 로그인 중 상태를 풀어 준다', (tester) async {
    final controller = _controller();
    controller.markSocialSignInReturned();

    await tester.pump(const Duration(seconds: 25));

    expect(controller.isSigningIn, isFalse);
  });

  testWidgets('로그아웃 상태에서 세션이 오면 계정을 읽는 동안 로그인 중이다', (tester) async {
    final controller = _controller();
    final seen = <bool>[];
    controller.addListener(() => seen.add(controller.isSigningIn));

    await _signIn(controller, _session('u-1'));

    expect(seen.first, isTrue, reason: '로드 전에 먼저 알려야 화면이 멈춰 보이지 않는다');
    expect(controller.isSigningIn, isFalse);
    expect(controller.isLoggedIn, isTrue);
  });

  testWidgets('이미 로그인된 상태의 토큰 갱신은 로그인 중으로 보지 않는다', (tester) async {
    final controller = _controller();
    await _signIn(controller, _session('u-1'));
    final seen = <bool>[];
    controller.addListener(() => seen.add(controller.isSigningIn));

    await _signIn(controller, _session('u-1'));

    expect(seen.where((value) => value), isEmpty);
  });

  testWidgets('로그아웃되면 로그인 중 상태도 끝난다', (tester) async {
    final controller = _controller();
    controller.markSocialSignInReturned();

    await controller.handleExternalAuthSession(null);

    expect(controller.isSigningIn, isFalse);
    await tester.pump(const Duration(seconds: 25));
  });
}
