import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lion_auth/lion_auth.dart';
import 'package:nest_frontend/src/ui/widgets/brand_marks.dart';
import 'package:nest_frontend/src/ui/widgets/nest_social_login_buttons.dart';

/// 소셜 버튼은 각 사 로고를 그대로 써야 한다. 글자(G·카·N)는 브랜드
/// 가이드 위반이고, 사용자도 무슨 버튼인지 덜 알아본다.
void main() {
  Future<void> pump(WidgetTester tester, List<LionAuthProviderId> ids) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NestSocialLoginButtons(
            providers: ids,
            onSelect: (_) async {},
          ),
        ),
      ),
    );
  }

  testWidgets('구글·카카오·네이버 버튼이 각 사 로고를 그린다', (tester) async {
    await pump(tester, const [
      LionAuthProviderId.google,
      LionAuthProviderId.kakao,
      LionAuthProviderId.naver,
    ]);

    expect(find.byType(GoogleMark), findsOneWidget);
    expect(find.byType(KakaoMark), findsOneWidget);
    expect(find.byType(NaverMark), findsOneWidget);
  });

  testWidgets('로고를 글자로 대신하지 않는다', (tester) async {
    await pump(tester, const [
      LionAuthProviderId.google,
      LionAuthProviderId.kakao,
      LionAuthProviderId.naver,
    ]);

    for (final glyph in ['G', '카', 'N']) {
      expect(find.text(glyph), findsNothing, reason: '$glyph 글자가 남아 있다');
    }
  });

  testWidgets('버튼을 누르면 해당 공급자가 전달된다', (tester) async {
    final tapped = <LionAuthProviderId>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NestSocialLoginButtons(
            providers: const [LionAuthProviderId.kakao],
            onSelect: (id) async => tapped.add(id),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(KakaoMark));
    await tester.pumpAndSettle();
    expect(tapped, [LionAuthProviderId.kakao]);
  });

  testWidgets('접근성 레이블은 한국어로 남는다', (tester) async {
    await pump(tester, const [LionAuthProviderId.naver]);
    expect(find.bySemanticsLabel('네이버로 로그인'), findsOneWidget);
  });
}
