import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/widgets/term_select_chip.dart';

Term _term(String id, String name, String start, String end) => Term.fromMap({
      'id': id,
      'homeschool_id': 's1',
      'name': name,
      'status': 'DRAFT',
      'start_date': start,
      'end_date': end,
    });

NestController _controller({required List<Term> terms, String? selectedId}) {
  // 네트워크를 타지 않는 위젯 테스트용 컨트롤러. 칩은 terms/selectedTermId만
  // 읽고, 선택 콜백은 위젯 파라미터(onSelectTerm)로 전달되므로 안전하다.
  // autoRefreshToken을 꺼야 GoTrue의 10초 주기 타이머가 생기지 않아
  // flutter_test의 pending-timer 검증을 통과한다(dispose는 행이 걸려 부적합).
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final controller = NestController(repository: NestRepository(client));
  controller.terms = terms;
  controller.selectedTermId = selectedId;
  return controller;
}

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  final spring = _term('t-spring', '2026-봄', '2026-03-02', '2026-06-30');
  final summer = _term('t-summer', '2026-여름', '2026-07-01', '2026-08-31');
  final fall = _term('t-fall', '2026-가을', '2026-09-01', '2026-11-30');

  testWidgets('선택된 학기 이름과 시간 단계 배지를 표시한다', (tester) async {
    // 칩의 phase 계산이 실제 시계를 쓰므로, '오늘'이 언제든 배지가 하나는 뜨는
    // 것을 검증한다(지난/현재/예정 중 하나).
    final controller =
        _controller(terms: [spring, summer], selectedId: 't-summer');
    await tester.pumpWidget(
      _wrap(TermSelectChip(controller: controller, onSelectTerm: (_) async {})),
    );

    expect(find.text('2026-여름'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && const ['지난', '현재', '예정'].contains(w.data),
      ),
      findsOneWidget,
    );
  });

  testWidgets('탭하면 학기 목록 시트가 시작일 순으로 열린다', (tester) async {
    final controller =
        _controller(terms: [fall, spring, summer], selectedId: 't-summer');
    await tester.pumpWidget(
      _wrap(TermSelectChip(controller: controller, onSelectTerm: (_) async {})),
    );

    await tester.tap(find.byType(TermSelectChip));
    await tester.pumpAndSettle();

    expect(find.text('학기 선택'), findsOneWidget);
    final springY = tester.getTopLeft(find.text('2026-봄').last).dy;
    final summerY = tester.getTopLeft(find.text('2026-여름').last).dy;
    final fallY = tester.getTopLeft(find.text('2026-가을').last).dy;
    expect(springY, lessThan(summerY));
    expect(summerY, lessThan(fallY));
  });

  testWidgets('다른 학기를 고르면 onSelectTerm이 그 학기 id로 호출된다', (tester) async {
    final controller =
        _controller(terms: [spring, summer], selectedId: 't-summer');
    String? picked;
    await tester.pumpWidget(
      _wrap(
        TermSelectChip(
          controller: controller,
          onSelectTerm: (id) async => picked = id,
        ),
      ),
    );

    await tester.tap(find.byType(TermSelectChip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-봄').last);
    await tester.pumpAndSettle();

    expect(picked, 't-spring');
  });

  testWidgets('이미 선택된 학기를 다시 골라도 onSelectTerm을 부르지 않는다', (tester) async {
    final controller =
        _controller(terms: [spring, summer], selectedId: 't-summer');
    var called = false;
    await tester.pumpWidget(
      _wrap(
        TermSelectChip(
          controller: controller,
          onSelectTerm: (_) async => called = true,
        ),
      ),
    );

    await tester.tap(find.byType(TermSelectChip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-여름').last);
    await tester.pumpAndSettle();

    expect(called, isFalse);
  });

  testWidgets('학기가 없으면 칩이 비활성으로 표시되고 시트가 열리지 않는다', (tester) async {
    final controller = _controller(terms: const [], selectedId: null);
    await tester.pumpWidget(
      _wrap(TermSelectChip(controller: controller, onSelectTerm: (_) async {})),
    );

    expect(find.text('학기 선택'), findsOneWidget); // 칩 라벨(플레이스홀더)
    await tester.tap(find.byType(TermSelectChip));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('좁은 폭에서도 오버플로 없이 렌더된다', (tester) async {
    final controller = _controller(
      terms: [_term('t1', '아주아주 긴 이름의 여름 학기', '2026-07-01', '2026-08-31')],
      selectedId: 't1',
    );
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 90,
          child: TermSelectChip(
            controller: controller,
            onSelectTerm: (_) async {},
          ),
        ),
      ),
    );
    // 오버플로가 있으면 flutter_test가 예외로 실패한다.
    expect(tester.takeException(), isNull);
  });
}
