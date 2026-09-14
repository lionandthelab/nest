// 빈 상태 카드 일관성.
//
// 실기기(iPhone 16)에서 보니 개인 일정 섹션만 내용이 없을 때 맨 텍스트로 배경에
// 얹혀 있었다. 같은 화면의 다른 블록은 전부 카드 안이고, 이 섹션도 일정이 생기면
// 카드로 바뀐다. 비어 있을 때만 카드 밖이라 화면이 덜 정돈돼 보인다.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/widgets/today_personal_events.dart';

Widget _app(Widget child) => MaterialApp(
  theme: NestTheme.light(),
  locale: const Locale('ko'),
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('ko'), Locale('en')],
  home: Scaffold(body: Padding(padding: const EdgeInsets.all(10), child: child)),
);

void main() {
  testWidgets('오늘 개인 일정이 비어 있어도 안내가 카드 안에 들어간다', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(TodayPersonalEvents(events: const [], onAdd: () {})),
    );
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.textContaining('아직 없어요'),
      matching: find.byType(Card),
    );
    expect(card, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('빈 상태 카드도 폭을 채운다', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(TodayPersonalEvents(events: const [], onAdd: () {})),
    );
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.textContaining('아직 없어요'),
      matching: find.byType(Card),
    );
    final sectionWidth = tester
        .getSize(find.byType(TodayPersonalEvents))
        .width;
    expect(tester.getSize(card).width, greaterThan(sectionWidth - 10));
  });
}
