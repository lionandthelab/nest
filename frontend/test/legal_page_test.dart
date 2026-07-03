import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/ui/legal/legal_markdown.dart';
import 'package:nest_frontend/src/ui/legal/legal_page.dart';

void main() {
  testWidgets('LegalMarkdown이 제목/문단/불릿/표/굵게를 렌더한다', (tester) async {
    const md = '''
# 개인정보처리방침

**시행일: 2026년 7월 3일**

## 1. 수집 항목

서비스 제공을 위해 다음을 수집합니다.

- 이메일 주소
- 닉네임

## 5. 위탁

| 수탁자 | 업무 |
|---|---|
| Supabase | 백엔드 |

<!-- 이 주석은 렌더되지 않아야 한다 -->
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: LegalMarkdown(md)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('개인정보처리방침'), findsOneWidget);
    expect(find.text('1. 수집 항목'), findsOneWidget);
    expect(find.text('이메일 주소'), findsOneWidget);
    expect(find.text('Supabase'), findsOneWidget);
    // 주석은 렌더되지 않음
    expect(find.textContaining('렌더되지 않아야'), findsNothing);
  });

  testWidgets('LegalDocument 자산 경로가 pubspec에 등록되어 로드된다', (tester) async {
    // 자산 로드 → 제목 렌더 (자산 미등록 시 에러 문구가 뜬다)
    await tester.pumpWidget(
      const MaterialApp(home: LegalPage(document: LegalDocument.privacy)),
    );
    await tester.pumpAndSettle();

    expect(find.text('개인정보처리방침'), findsWidgets); // AppBar + 본문 제목
    expect(find.textContaining('불러오지 못했습니다'), findsNothing);
  });

  testWidgets('이용약관 자산도 로드된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LegalPage(document: LegalDocument.terms)),
    );
    await tester.pumpAndSettle();

    expect(find.text('이용약관'), findsWidgets);
    expect(find.textContaining('제1조 (목적)'), findsOneWidget);
  });
}
