// 알림 설정 패널.
//
// 설정 화면과 온보딩이 같은 패널을 쓴다. 두 군데서 다른 문구·다른 선택지가
// 나오면 온보딩에서 켠 것과 설정에서 보는 것이 어긋나 보인다.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/widgets/notification_settings_panel.dart';

Widget _app(Widget child) => MaterialApp(
  theme: NestTheme.light(),
  locale: const Locale('ko'),
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('ko'), Locale('en')],
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> _pump(
  WidgetTester tester, {
  NotificationPrefs prefs = const NotificationPrefs(),
  ValueChanged<NotificationPrefs>? onChanged,
  Size size = const Size(360, 780),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(
      NotificationSettingsPanel(
        prefs: prefs,
        onChanged: onChanged ?? (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('세 가지 알림 스위치가 모두 보인다', (tester) async {
    await _pump(tester);
    expect(find.text('푸시 알림'), findsOneWidget);
    expect(find.text('아침 오늘 일정'), findsOneWidget);
    expect(find.text('수업 전 알림'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 사용자가 "어떤 알림이 오는지" 모르면 켤 이유를 못 느낀다.
  testWidgets('각 알림이 실제로 어떻게 오는지 예시를 보여준다', (tester) async {
    await _pump(tester);
    expect(find.textContaining('오늘 수업 3개'), findsWidgets);
    expect(find.textContaining('분 전'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('아침 알림을 켜면 시각을 고를 수 있다', (tester) async {
    await _pump(tester);
    for (final at in NotificationPrefs.morningMinChoices) {
      final label = NotificationPrefs(
        morningDigestMin: at,
      ).morningDigestLabel;
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  // 4개가 3+1 로 접히면 어정쩡하게 한 줄을 더 먹고, 온보딩에서는 그만큼 아래
  // 항목이 화면 밖으로 밀린다. 좁은 폰에서도 한 줄에 들어가야 한다.
  for (final width in const [360.0, 393.0]) {
    testWidgets('${width.toInt()}폭에서 아침 시각 칩이 한 줄에 놓인다', (tester) async {
      await _pump(tester, size: Size(width, 900));

      final tops = NotificationPrefs.morningMinChoices
          .map(
            (at) => tester
                .getTopLeft(
                  find.text(
                    NotificationPrefs(morningDigestMin: at).morningDigestLabel,
                  ),
                )
                .dy,
          )
          .toSet();
      expect(tops, hasLength(1), reason: '칩이 여러 줄로 접혔다');
    });
  }

  testWidgets('아침 알림을 끄면 시각 선택은 감춘다', (tester) async {
    await _pump(
      tester,
      prefs: const NotificationPrefs(morningDigestEnabled: false),
    );
    expect(find.text('7:30'), findsNothing);
  });

  testWidgets('아침 시각을 고르면 그 값으로 콜백이 온다', (tester) async {
    NotificationPrefs? saved;
    await _pump(tester, onChanged: (value) => saved = value);

    await tester.tap(find.text('6:30'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.morningDigestMin, 390);
  });

  testWidgets('아침 알림 설명이 고른 시각을 따라간다', (tester) async {
    await _pump(
      tester,
      prefs: const NotificationPrefs(morningDigestMin: 480),
    );
    // "매일 아침 7시 30분" 처럼 굳어 있으면 고른 값과 어긋나 보인다.
    expect(find.textContaining('8:00'), findsWidgets);
  });

  testWidgets('수업 전 알림을 켜면 리드타임을 고를 수 있다', (tester) async {
    await _pump(tester);
    for (final lead in NotificationPrefs.leadMinChoices) {
      expect(find.text('$lead분'), findsOneWidget);
    }
  });

  testWidgets('수업 전 알림을 끄면 리드타임 선택은 감춘다', (tester) async {
    await _pump(
      tester,
      prefs: const NotificationPrefs(classReminderEnabled: false),
    );
    expect(find.text('30분'), findsNothing);
  });

  testWidgets('리드타임을 고르면 그 값으로 콜백이 온다', (tester) async {
    NotificationPrefs? saved;
    await _pump(tester, onChanged: (value) => saved = value);

    await tester.tap(find.text('10분'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.classReminderLeadMin, 10);
  });

  testWidgets('푸시를 끄면 나머지 알림 설정은 비활성이 된다', (tester) async {
    await _pump(tester, prefs: const NotificationPrefs(pushEnabled: false));

    final morning = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('아침 오늘 일정'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(morning.onChanged, isNull);
  });

  testWidgets('푸시가 꺼져 있으면 아무 알림도 안 온다고 알려준다', (tester) async {
    await _pump(tester, prefs: const NotificationPrefs(pushEnabled: false));
    expect(find.textContaining('알림이 오지 않습니다'), findsOneWidget);
  });

  testWidgets('조용한 시간을 켜고 끌 수 있다', (tester) async {
    NotificationPrefs? saved;
    await _pump(tester, onChanged: (value) => saved = value);

    expect(find.text('조용한 시간'), findsOneWidget);
    await tester.tap(
      find.ancestor(
        of: find.text('조용한 시간'),
        matching: find.byType(SwitchListTile),
      ),
    );
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.hasQuietHours, isTrue);
  });

  testWidgets('조용한 시간이 켜져 있으면 시간대를 보여준다', (tester) async {
    await _pump(
      tester,
      prefs: const NotificationPrefs(
        quietHoursStart: '22:00',
        quietHoursEnd: '07:00',
      ),
    );
    expect(find.textContaining('22:00'), findsWidgets);
    expect(find.textContaining('07:00'), findsWidgets);
  });

  // "켰는데 안 오는" 게 가장 흔한 고장이라, 직접 받아볼 수 있어야 신뢰한다.
  testWidgets('테스트 알림 버튼을 주면 보인다', (tester) async {
    var tapped = 0;
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        NotificationSettingsPanel(
          prefs: const NotificationPrefs(),
          onChanged: (_) {},
          onSendTest: () => tapped += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('테스트 알림 보내기'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });

  testWidgets('테스트 알림 콜백이 없으면 버튼도 없다', (tester) async {
    // 온보딩에서는 아직 저장 전이라 보낼 수 없다.
    await _pump(tester);
    expect(find.text('테스트 알림 보내기'), findsNothing);
  });

  testWidgets('푸시가 꺼져 있으면 테스트 알림을 누를 수 없다', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        NotificationSettingsPanel(
          prefs: const NotificationPrefs(pushEnabled: false),
          onChanged: (_) {},
          onSendTest: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('테스트 알림 보내기'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  for (final size in const [Size(360, 780), Size(393, 852)]) {
    testWidgets('${size.width.toInt()}폭에서 넘치지 않는다', (tester) async {
      await _pump(tester, size: size);
      expect(tester.takeException(), isNull);
    });
  }
}
