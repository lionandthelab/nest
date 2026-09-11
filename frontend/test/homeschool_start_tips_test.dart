import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/ui/models/homeschool_start_tips.dart';
import 'package:nest_frontend/src/ui/widgets/homeschool_tips_card.dart';

void main() {
  test('tipOfTheDay is stable for the same calendar day', () {
    final morning = HomeschoolStartTips.tipOfTheDay(DateTime(2026, 9, 11, 8));
    final evening = HomeschoolStartTips.tipOfTheDay(DateTime(2026, 9, 11, 21));
    expect(morning.id, evening.id);
  });

  test('tipOfTheDay rotates across days', () {
    final first = HomeschoolStartTips.tipOfTheDay(DateTime(2026, 9, 11));
    final second = HomeschoolStartTips.tipOfTheDay(DateTime(2026, 9, 12));
    expect(first.id, isNot(second.id));
  });

  test('moreTips excludes the featured tip', () {
    final now = DateTime(2026, 9, 11);
    final featured = HomeschoolStartTips.tipOfTheDay(now);
    final rest = HomeschoolStartTips.moreTips(now);
    expect(rest, hasLength(HomeschoolStartTips.all.length - 1));
    expect(rest.any((tip) => tip.id == featured.id), isFalse);
  });

  test('tips stay short, practical and avoid legal framing', () {
    for (final tip in HomeschoolStartTips.all) {
      expect(tip.title, isNotEmpty);
      expect(tip.body, isNotEmpty);
      expect(tip.body.length, lessThan(80));
      expect(tip.body.toLowerCase(), isNot(contains('법령')));
      expect(tip.body, isNot(contains('학력 인정')));
      expect(tip.body, isNot(contains('신고')));
    }
  });

  test('suggested homeschool name prefers a short family name', () {
    expect(HomeschoolStartDefaults.nameFromProfile(), '우리집 홈스쿨');
    expect(
      HomeschoolStartDefaults.nameFromProfile(realName: '민지'),
      '민지네 집',
    );
    expect(
      HomeschoolStartDefaults.nameFromProfile(nickname: '우리집 홈스쿨'),
      '우리집 홈스쿨',
    );
  });

  test('suggested term name follows the season', () {
    expect(
      HomeschoolStartDefaults.termName(DateTime(2026, 9, 12)),
      '2026 가을 학기',
    );
    expect(
      HomeschoolStartDefaults.termName(DateTime(2026, 3, 2)),
      '2026 봄 학기',
    );
  });

  testWidgets('온보딩 팁 카드가 짧은 제목을 보여 준다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeschoolTipsCard(now: DateTime(2026, 9, 11))),
      ),
    );

    final featured = HomeschoolStartTips.tipOfTheDay(DateTime(2026, 9, 11));
    expect(find.text('우리집 홈스쿨, 이렇게 시작해요'), findsOneWidget);
    expect(find.text(featured.title), findsOneWidget);
    expect(find.text('다른 이야기'), findsOneWidget);
  });
}
