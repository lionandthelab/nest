import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nest_frontend/src/ui/widgets/nest_sheet.dart';

/// 지정한 화면 크기로 테스트 위젯을 띄운다.
Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  void Function(BuildContext context) onTap,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => onTap(context),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('좁은 화면에서는 전체 너비 바텀시트로 열린다', (tester) async {
    await _pumpAt(tester, const Size(390, 844), (context) {
      showNestSheet<void>(
        context: context,
        builder: (ctx) => const NestSheet(
          title: '가정 수정',
          child: Text('본문'),
        ),
      );
    });

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('가정 수정'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    final surface = tester.getSize(find.byKey(nestSheetSurfaceKey));
    expect(surface.width, 390, reason: '모바일에서는 좌우 여백 없이 전체 너비를 쓴다');

    final rect = tester.getRect(find.byKey(nestSheetSurfaceKey));
    expect(rect.bottom, 844, reason: '바텀시트는 화면 아래에 붙는다');
  });

  testWidgets('넓은 화면에서는 가운데 다이얼로그로 열린다', (tester) async {
    await _pumpAt(tester, const Size(1280, 900), (context) {
      showNestSheet<void>(
        context: context,
        maxWidth: 640,
        builder: (ctx) => const NestSheet(
          title: '가정 수정',
          child: Text('본문'),
        ),
      );
    });

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    final surface = tester.getSize(find.byKey(nestSheetSurfaceKey));
    expect(surface.width, lessThanOrEqualTo(640));
  });

  testWidgets('시트 본문이 길어도 액션 버튼은 항상 보인다', (tester) async {
    await _pumpAt(tester, const Size(390, 844), (context) {
      showNestSheet<void>(
        context: context,
        builder: (ctx) => NestSheet(
          title: '긴 본문',
          actions: [
            FilledButton(onPressed: () {}, child: const Text('저장')),
          ],
          child: Column(
            children: List<Widget>.generate(
              60,
              (index) => SizedBox(height: 40, child: Text('행 $index')),
            ),
          ),
        ),
      );
    });

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('저장'), findsOneWidget);
    final sheetRect = tester.getRect(find.byKey(nestSheetSurfaceKey));
    expect(sheetRect.height, lessThanOrEqualTo(844));
    expect(find.text('행 0'), findsOneWidget);
  });

  testWidgets('긴 제목은 말줄임 대신 두 줄로 감싼다', (tester) async {
    await _pumpAt(tester, const Size(360, 780), (context) {
      showNestSheet<void>(
        context: context,
        builder: (ctx) => const NestSheet(
          title: '2026 가을학기 수학 심화반 수업 시간 수정하기',
          child: Text('본문'),
        ),
      );
    });

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.text('2026 가을학기 수학 심화반 수업 시간 수정하기'),
    );
    expect(title.overflow, isNot(TextOverflow.ellipsis));
    expect(title.maxLines, greaterThan(1));
  });

  testWidgets('확인 시트는 취소/확인 결과를 돌려준다', (tester) async {
    bool? result;
    await _pumpAt(tester, const Size(390, 844), (context) async {
      result = await showNestConfirm(
        context: context,
        title: '가정 삭제',
        message: '정말 삭제할까요?',
        confirmLabel: '삭제',
        destructive: true,
      );
    });

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
