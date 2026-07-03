import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../nest_theme.dart';
import 'legal_markdown.dart';

/// 법무 문서 종류.
enum LegalDocument {
  privacy(
    title: '개인정보처리방침',
    asset: 'assets/legal/privacy.md',
  ),
  terms(
    title: '이용약관',
    asset: 'assets/legal/terms.md',
  );

  const LegalDocument({required this.title, required this.asset});

  final String title;
  final String asset;
}

/// 마크다운 자산을 로드해 렌더하는 인앱 법무 페이지.
/// (웹/Android/iOS 공통, 오프라인 동작)
///
/// 웹 배포 시 OAuth 콘솔에 제출할 정적 URL은
/// scripts/render_legal.mjs 가 같은 마크다운에서 생성한다.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.document});

  final LegalDocument document;

  /// 설정 등에서 손쉽게 열기 위한 헬퍼.
  static Future<void> open(BuildContext context, LegalDocument document) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalPage(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NestColors.creamyWhite,
      appBar: AppBar(
        title: Text(document.title),
        backgroundColor: NestColors.creamyWhite,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(document.asset),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '문서를 불러오지 못했습니다.',
                  style: TextStyle(
                    color: NestColors.deepWood.withValues(alpha: 0.7),
                  ),
                ),
              ),
            );
          }
          return Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: LegalMarkdown(snapshot.data!),
              ),
            ),
          );
        },
      ),
    );
  }
}
