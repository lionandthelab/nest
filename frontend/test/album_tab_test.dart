import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/tabs/album/album_selection_bar.dart';
import 'package:nest_frontend/src/ui/tabs/album/album_tab.dart';
import 'package:nest_frontend/src/ui/tabs/album/album_tile.dart';

GalleryItem _item(String id, {bool video = false, String title = ''}) {
  return GalleryItem.fromMap({
    'id': id,
    'title': title,
    'media_type': video ? 'VIDEO' : 'PHOTO',
    'storage_path': 'hs-1/2026-09/$id.jpg',
    'captured_at': '2026-09-2${id.length % 9}T02:00:00.000Z',
  });
}

NestController _controller({
  required String role,
  List<GalleryItem> items = const [],
}) {
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final controller = NestController(repository: NestRepository(client));
  controller.currentRole = role;
  controller.selectedHomeschoolId = 'hs-1';
  controller.galleryItems = items;
  return controller;
}

Future<void> _pumpAlbum(WidgetTester tester, NestController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: NestTheme.light(),
      home: AlbumTab(controller: controller),
    ),
  );
  // 목록 로드는 localhost로 나가 실패한다. 실패해도 이미 들고 있던 항목은
  // 유지되어야 하고, 화면은 그 항목으로 그려져야 한다.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('올릴 수 있는 역할에는 업로드 버튼이 보인다', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = _controller(role: 'TEACHER', items: [_item('a')]);
    await _pumpAlbum(tester, controller);

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('학생 계정에는 업로드 버튼이 없다', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = _controller(role: 'STUDENT', items: [_item('a')]);
    await _pumpAlbum(tester, controller);

    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('네트워크가 실패해도 이미 받아 둔 사진은 격자에 남는다', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = _controller(
      role: 'PARENT',
      items: [_item('a'), _item('b'), _item('c')],
    );
    await _pumpAlbum(tester, controller);

    expect(find.byType(AlbumTile), findsNWidgets(3));
    expect(find.byType(AlbumSelectionBar), findsNothing);
  });

  testWidgets('길게 누르면 선택 모드로 들어가고 하단 바가 뜬다', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = _controller(
      role: 'TEACHER',
      items: [_item('a'), _item('b')],
    );
    await _pumpAlbum(tester, controller);

    await tester.longPress(find.byType(AlbumTile).first);
    await tester.pump();

    expect(controller.albumSelectedIds, {'a'});
    expect(find.byType(AlbumSelectionBar), findsOneWidget);
    expect(find.text('1개 선택'), findsOneWidget);

    // 선택 중에는 업로드 버튼이 물러난다(스케일 0).
    final fab = tester.widget<AnimatedScale>(
      find
          .ancestor(
            of: find.byType(FloatingActionButton),
            matching: find.byType(AnimatedScale),
          )
          .first,
    );
    expect(fab.scale, 0);
  });

  testWidgets('선택을 해제하면 하단 바가 사라진다', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = _controller(role: 'TEACHER', items: [_item('a')]);
    await _pumpAlbum(tester, controller);

    await tester.longPress(find.byType(AlbumTile).first);
    await tester.pump();
    expect(find.byType(AlbumSelectionBar), findsOneWidget);

    // 같은 타일을 다시 누르면 선택이 풀린다.
    await tester.tap(find.byType(AlbumTile).first);
    await tester.pump();

    expect(controller.albumSelectedIds, isEmpty);
    expect(find.byType(AlbumSelectionBar), findsNothing);
  });

  testWidgets('360폭에서 헤더가 가로로 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = _controller(role: 'HOMESCHOOL_ADMIN', items: [_item('a')]);
    controller.classGroups = [
      ClassGroup.fromMap({'id': 'cg-1', 'term_id': 't-1', 'name': '해바라기반'}),
      ClassGroup.fromMap({'id': 'cg-2', 'term_id': 't-1', 'name': '민들레반'}),
    ];
    await _pumpAlbum(tester, controller);

    expect(tester.takeException(), isNull);
  });
}
