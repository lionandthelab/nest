import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/widgets/entity_visuals.dart';
import 'package:nest_frontend/src/ui/widgets/search_select_field.dart';

const _longTitle = '2026 가을학기 초등 통합반 목요일 오후 심화 프로젝트';
const _longSubtitle = '담당 김선생님 · 목요일 3~4교시 · 2층 창가 교실 · 정원 12명 중 9명 배정 완료';

Future<void> _pumpNarrow(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: NestTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

int? _maxLinesOf(WidgetTester tester, String data) =>
    tester.widget<Text>(find.text(data)).maxLines;

void main() {
  testWidgets('LabeledEntityTile 제목은 좁은 화면에서 두 줄까지 풀어 쓴다', (tester) async {
    await _pumpNarrow(
      tester,
      const LabeledEntityTile(title: _longTitle, subtitle: _longSubtitle),
    );

    expect(tester.takeException(), isNull);
    expect(_maxLinesOf(tester, _longTitle), greaterThanOrEqualTo(2));
    expect(_maxLinesOf(tester, _longSubtitle), greaterThanOrEqualTo(2));
  });

  testWidgets('LabeledEntityTile compact도 제목 한 줄로 자르지 않는다', (tester) async {
    await _pumpNarrow(
      tester,
      const LabeledEntityTile(
        title: _longTitle,
        subtitle: _longSubtitle,
        compact: true,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(_maxLinesOf(tester, _longTitle), greaterThanOrEqualTo(2));
  });

  testWidgets('SelectFieldCard 값과 도움말이 잘리지 않고 이어진다', (tester) async {
    await _pumpNarrow(
      tester,
      SelectFieldCard(
        label: '담당 선생님',
        hintText: '선생님을 선택하세요',
        icon: Icons.person_outline,
        enabled: true,
        onTap: () {},
        value: _longTitle,
        helpText: _longSubtitle,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(_maxLinesOf(tester, _longTitle), greaterThanOrEqualTo(2));
  });
}
