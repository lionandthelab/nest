import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/ui/widgets/nest_motion.dart';

void main() {
  testWidgets('NestPressable calls onPressed on tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NestPressable(
            onPressed: () => taps += 1,
            child: const Text('눌러보세요'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('눌러보세요'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('NestAppear keeps the child in the tree from the first frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: NestAppear(index: 2, child: Text('오늘의 꿀팁'))),
      ),
    );

    expect(find.text('오늘의 꿀팁'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('오늘의 꿀팁'), findsOneWidget);
  });

  testWidgets('NestDockBar shows labels and reports a tap', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: NestDockBar(
            selectedIndex: 0,
            labels: const ['홈', '시간표'],
            iconOf: (label, {required bool selected}) =>
                Icon(selected ? Icons.home : Icons.home_outlined),
            onSelect: (index) => selected = index,
          ),
        ),
      ),
    );

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('시간표'), findsOneWidget);
    await tester.tap(find.text('시간표'));
    await tester.pump();
    expect(selected, 1);
  });

  testWidgets('NestBusyOverlay shows the progress message when visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: NestBusyOverlay(visible: true, message: '우리집 홈스쿨을 만드는 중...'),
          ),
        ),
      ),
    );

    expect(find.text('우리집 홈스쿨을 만드는 중...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
