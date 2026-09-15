// 알림 온보딩을 띄울지 판단하는 컨트롤러 상태.
//
// 설정을 아직 못 읽어온 사이에 판단하면, 이미 온보딩을 끝낸 사람에게도 기본값
// (notifOnboardedAt = null)이 보여서 전체화면이 다시 뜬다. 앱을 열 때마다
// 알림 안내가 막아서는 꼴이라 반드시 "읽어왔는지"를 같이 봐야 한다.

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

void main() {
  test('알림 설정을 읽기 전에는 온보딩을 띄우지 않는다', () {
    final controller = _controller();
    expect(controller.notificationPrefsLoaded, isFalse);
    expect(controller.needsNotifOnboarding, isFalse);
  });

  test('읽어왔고 아직 안 본 사람이면 온보딩을 띄운다', () async {
    final controller = _controller();
    // 로그인 전 호출은 기본값으로 떨어지지만 "읽어왔다"로 친다.
    await controller.loadNotificationPrefs();
    expect(controller.notificationPrefsLoaded, isTrue);
    expect(controller.needsNotifOnboarding, isTrue);
  });

  test('이미 본 사람이면 온보딩을 띄우지 않는다', () async {
    final controller = _controller();
    await controller.loadNotificationPrefs();
    controller.notificationPrefs = NotificationPrefs(
      notifOnboardedAt: DateTime(2026, 9, 16),
    );
    expect(controller.needsNotifOnboarding, isFalse);
  });

  group('홈 배너', () {
    test('온보딩을 봤고 알림이 하나도 없으면 띄운다', () async {
      final controller = _controller();
      await controller.loadNotificationPrefs();
      controller.notificationPrefs = NotificationPrefs(
        pushEnabled: false,
        notifOnboardedAt: DateTime(2026, 9, 16),
      );
      expect(controller.showsNotifNudge, isTrue);
    });

    test('닫으면 이번 세션에는 다시 뜨지 않는다', () async {
      final controller = _controller();
      await controller.loadNotificationPrefs();
      controller.notificationPrefs = NotificationPrefs(
        pushEnabled: false,
        notifOnboardedAt: DateTime(2026, 9, 16),
      );

      controller.dismissNotifNudge();
      expect(controller.showsNotifNudge, isFalse);
    });

    test('알림을 받고 있으면 띄우지 않는다', () async {
      final controller = _controller();
      await controller.loadNotificationPrefs();
      controller.notificationPrefs = NotificationPrefs(
        notifOnboardedAt: DateTime(2026, 9, 16),
      );
      expect(controller.showsNotifNudge, isFalse);
    });
  });
}
