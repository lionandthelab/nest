// 섹션 카드 안에 들어가는 빈 상태는 전체 화면용보다 작아야 한다.
//
// 실기기(iPhone 16, 393x852)에서 교사 홈의 "결석 신고" 카드가 한 줄짜리
// "접수된 결석 신고가 없습니다."를 띄우려고 세로 200pt 넘게 먹었다. 화면 3분의
// 1이 빈 카드였다. 전체 화면 빈 상태(커뮤니티 탭 등)는 그 크기가 맞으므로
// 기본값은 그대로 두고, 카드 안에서만 줄여 쓴다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/widgets/nest_empty_state.dart';

/// 섹션 카드 안에 놓인 상황을 흉내낸다. 세로가 열려 있어야 빈 상태가 실제로
/// 자리를 얼마나 먹는지(= 카드가 얼마나 커지는지) 잴 수 있다.
Widget _app(Widget child) => MaterialApp(
  theme: NestTheme.light(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Column(children: [Card(child: child)]),
    ),
  ),
);

Future<double> _heightOf(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(widget));
  await tester.pumpAndSettle();
  return tester.getSize(find.byType(NestEmptyState)).height;
}

void main() {
  testWidgets('기본 빈 상태 크기는 그대로다 (전체 화면용)', (tester) async {
    final height = await _heightOf(
      tester,
      const NestEmptyState(icon: Icons.school_outlined, title: '접수된 결석 신고가 없습니다.'),
    );
    expect(height, greaterThan(180));
  });

  testWidgets('compact 빈 상태는 카드 안에 들어갈 만큼 낮다', (tester) async {
    final height = await _heightOf(
      tester,
      const NestEmptyState(
        icon: Icons.school_outlined,
        title: '접수된 결석 신고가 없습니다.',
        compact: true,
      ),
    );
    expect(height, lessThan(120));
  });

  testWidgets('compact 여도 아이콘과 문구는 그대로 보인다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        const NestEmptyState(
          icon: Icons.school_outlined,
          title: '접수된 결석 신고가 없습니다.',
          compact: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('접수된 결석 신고가 없습니다.'), findsOneWidget);
    expect(find.byIcon(Icons.school_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
