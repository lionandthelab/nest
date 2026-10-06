import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/widgets/child_unlinked_chip.dart';

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

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('아이 미연동 칩', () {
    testWidgets('라벨을 보여 주고 탭하면 연결 안내와 등록 요청 시트가 열린다', (tester) async {
      await _pump(tester, ChildUnlinkedChip(controller: _controller()));

      expect(find.text('아이 미연동'), findsOneWidget);

      await tester.tap(find.text('아이 미연동'));
      await tester.pumpAndSettle();

      expect(find.text('내 아이 등록 요청'), findsOneWidget);
      expect(find.textContaining('연결된 아이가 없어요'), findsOneWidget);
      expect(find.widgetWithText(TextField, '아이 이름'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '요청 보내기'), findsOneWidget);
    });

    testWidgets('라벨을 바꿀 수 있다', (tester) async {
      await _pump(
        tester,
        ChildUnlinkedChip(controller: _controller(), label: '내 아이 미연동'),
      );

      expect(find.text('내 아이 미연동'), findsOneWidget);
    });

    testWidgets('이름을 비운 채 요청하면 시트를 닫지 않고 안내한다', (tester) async {
      await _pump(tester, ChildUnlinkedChip(controller: _controller()));

      await tester.tap(find.text('아이 미연동'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '요청 보내기'));
      await tester.pumpAndSettle();

      expect(find.text('내 아이 등록 요청'), findsOneWidget);
      expect(find.text('가정 이름과 아이 이름을 입력하세요.'), findsOneWidget);
    });
  });
}
