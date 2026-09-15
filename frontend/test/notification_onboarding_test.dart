// 알림 온보딩 — 언제 띄우고, 무엇을 남기는가.
//
// 이 판정이 헐거우면 두 방향으로 다 나쁘다. 너무 자주 뜨면 앱 열 때마다 막아서
// 짜증나고, 너무 안 뜨면 알림을 한 번도 안 켜 본 채로 남는다.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/widgets/notification_onboarding.dart';

Widget _app(Widget child) => MaterialApp(
  theme: NestTheme.light(),
  locale: const Locale('ko'),
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('ko'), Locale('en')],
  home: child,
);

void main() {
  group('needsNotifOnboarding', () {
    test('아직 안 본 사람에게는 띄운다', () {
      expect(const NotificationPrefs().needsNotifOnboarding, isTrue);
    });

    test('한 번 본 사람에게는 다시 띄우지 않는다', () {
      final seen = NotificationPrefs(notifOnboardedAt: DateTime(2026, 9, 16));
      expect(seen.needsNotifOnboarding, isFalse);
    });

    test('건너뛴 사람도 본 것으로 친다', () {
      // 건너뛰기도 표시 시각을 남긴다. 안내는 한 번이면 충분하고, 그 뒤로는
      // 알림이 꺼져 있을 때만 홈 배너로 가볍게 권한다.
      final skipped = NotificationPrefs(
        pushEnabled: false,
        notifOnboardedAt: DateTime(2026, 9, 16),
      );
      expect(skipped.needsNotifOnboarding, isFalse);
    });
  });

  group('needsNotifNudge', () {
    test('온보딩을 아직 안 봤으면 배너는 띄우지 않는다', () {
      // 전체화면이 뜰 차례라 배너까지 겹치면 시끄럽다.
      expect(const NotificationPrefs().needsNotifNudge, isFalse);
    });

    test('온보딩을 봤는데 알림이 하나도 없으면 배너로 다시 권한다', () {
      final off = NotificationPrefs(
        pushEnabled: false,
        notifOnboardedAt: DateTime(2026, 9, 16),
      );
      expect(off.needsNotifNudge, isTrue);
    });

    test('알림을 받고 있으면 배너는 뜨지 않는다', () {
      final on = NotificationPrefs(notifOnboardedAt: DateTime(2026, 9, 16));
      expect(on.needsNotifNudge, isFalse);
    });

    test('푸시는 켰지만 종류를 다 껐으면 배너를 띄운다', () {
      final none = NotificationPrefs(
        morningDigestEnabled: false,
        classReminderEnabled: false,
        notifOnboardedAt: DateTime(2026, 9, 16),
      );
      expect(none.needsNotifNudge, isTrue);
    });
  });

  group('NotificationOnboardingSheet', () {
    Future<NotificationPrefs?> pumpAndTap(
      WidgetTester tester,
      String buttonLabel, {
      NotificationPrefs initial = const NotificationPrefs(),
    }) async {
      NotificationPrefs? saved;
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          NotificationOnboardingSheet(
            initial: initial,
            onDone: (prefs) => saved = prefs,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(buttonLabel));
      await tester.pumpAndSettle();
      return saved;
    }

    testWidgets('기본값이 켜진 채로 시작한다', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          NotificationOnboardingSheet(
            initial: const NotificationPrefs(),
            onDone: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 켜는 쪽이 기본이어야 "그냥 시작"만 눌러도 알림을 받는다.
      expect(find.text('수업 전 알림'), findsOneWidget);
      expect(find.text('30분'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('이대로 시작하면 설정이 그대로 저장된다', (tester) async {
      final saved = await pumpAndTap(tester, '이대로 시작하기');
      expect(saved, isNotNull);
      expect(saved!.pushEnabled, isTrue);
      expect(saved.classReminderLeadMin, 30);
      // 다시 뜨지 않도록 본 시각을 남긴다.
      expect(saved.notifOnboardedAt, isNotNull);
    });

    testWidgets('건너뛰어도 본 시각은 남는다', (tester) async {
      final saved = await pumpAndTap(tester, '나중에 할게요');
      expect(saved, isNotNull);
      expect(saved!.notifOnboardedAt, isNotNull);
      // 건너뛰기는 알림을 켜지 않는다.
      expect(saved.pushEnabled, isFalse);
    });

    testWidgets('리드타임을 바꿔서 시작할 수 있다', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      NotificationPrefs? saved;
      await tester.pumpWidget(
        _app(
          NotificationOnboardingSheet(
            initial: const NotificationPrefs(),
            onDone: (prefs) => saved = prefs,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('10분'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이대로 시작하기'));
      await tester.pumpAndSettle();

      expect(saved!.classReminderLeadMin, 10);
    });

    for (final size in const [Size(360, 640), Size(393, 852)]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} 에서 넘치지 않는다', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _app(
            NotificationOnboardingSheet(
              initial: const NotificationPrefs(),
              onDone: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
