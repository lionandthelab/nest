import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/join_homeschool_page.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';

void main() {
  testWidgets('다른 홈스쿨 가입 화면은 참여 코드와 검색 가입을 함께 보여 준다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = SupabaseClient(
      'http://localhost',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final controller = NestController(repository: NestRepository(client));

    await tester.pumpWidget(
      MaterialApp(
        theme: NestTheme.light(),
        home: JoinHomeschoolPage(controller: controller),
      ),
    );
    await tester.pump();

    expect(find.text('다른 홈스쿨 가입'), findsOneWidget);
    expect(find.text('참여 코드로 합류하기'), findsOneWidget);
    expect(find.text('홈스쿨 검색 및 가입 요청'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
