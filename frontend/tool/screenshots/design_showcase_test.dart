import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/login_page.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/tabs/members_tab.dart';
import 'package:nest_frontend/src/ui/tabs/parent_home_tab.dart';
import 'package:nest_frontend/src/ui/widgets/nest_motion.dart';

const _shotsDir = 'shots';

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final bytes = file.readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
}

Future<void> _loadFonts() async {
  await _loadFont('BlackHanSans', 'assets/fonts/BlackHanSans-Regular.ttf');
  await _loadFont('Jua', 'assets/fonts/Jua-Regular.ttf');
  await _loadFont('DoHyeon', 'assets/fonts/DoHyeon-Regular.ttf');

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final matFonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
    final iconFont = '$matFonts/MaterialIcons-Regular.otf';
    if (File(iconFont).existsSync()) {
      await _loadFont('MaterialIcons', iconFont);
    }
    final roboto = '$matFonts/Roboto-Regular.ttf';
    if (File(roboto).existsSync()) {
      await _loadFont('Roboto', roboto);
    }
  }
}

Future<void> _shoot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(_shotsDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('$_shotsDir/$name').writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

NestController _seedParent(SupabaseClient client) {
  final controller = NestController(repository: NestRepository(client));
  final hs = const Homeschool(
    id: 'joy',
    name: '자람 홈스쿨',
    timezone: 'Asia/Seoul',
    joinCode: 'JARAM26',
  );
  controller.memberships = [
    Membership(
      userId: 'u1',
      homeschoolId: 'joy',
      role: 'PARENT',
      status: 'ACTIVE',
      homeschool: hs,
    ),
  ];
  controller.selectedHomeschoolId = 'joy';
  controller.currentRole = 'PARENT';
  controller.terms = [
    Term(
      id: 't-1',
      homeschoolId: 'joy',
      name: '2026 가을학기',
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      endDate: DateTime.now().add(const Duration(days: 60)),
      status: 'ACTIVE',
    ),
  ];
  controller.selectedTermId = 't-1';
  controller.children = [
    ChildProfile(
      id: 'c-1',
      familyId: 'f-1',
      familyName: '민우네 가정',
      name: '민우',
      birthDate: DateTime(2017, 5, 10),
      profileNote: '',
      status: 'ACTIVE',
      createdAt: DateTime.now(),
    ),
  ];
  controller.announcements = [
    Announcement(
      id: 'a-1',
      homeschoolId: 'joy',
      classGroupId: null,
      authorUserId: 'u-1',
      title: '가을 숲 체험학습 및 준비물 안내 (필독)',
      body: '다음 주 수요일 야외 자연학습을 진행합니다. 편한 복장과 도시락을 지참해주세요.',
      pinned: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Announcement(
      id: 'a-2',
      homeschoolId: 'joy',
      classGroupId: null,
      authorUserId: 'u-1',
      title: '10월 학부모 독서모임 일정 공지',
      body: '이번 달 선정 도서는 [홈스쿨링 첫걸음] 입니다. 금요일 오후 2시에 만나요.',
      pinned: false,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
  return controller;
}

NestController _seedAdmin(SupabaseClient client) {
  final controller = NestController(repository: NestRepository(client));
  final hs = const Homeschool(
    id: 'joy',
    name: '자람 홈스쿨',
    timezone: 'Asia/Seoul',
    joinCode: 'JARAM26',
  );
  controller.memberships = [
    Membership(
      userId: 'admin',
      homeschoolId: 'joy',
      role: 'HOMESCHOOL_ADMIN',
      status: 'ACTIVE',
      homeschool: hs,
    ),
  ];
  controller.selectedHomeschoolId = 'joy';
  controller.currentRole = 'HOMESCHOOL_ADMIN';
  controller.families = const [
    Family(
      id: 'f1',
      homeschoolId: 'joy',
      familyName: '민우네 가정',
      note: '초등 3학년 민우',
      createdAt: null,
    ),
    Family(
      id: 'f2',
      homeschoolId: 'joy',
      familyName: '서연이네 가정',
      note: '초등 1학년 서연, 유치부 서준',
      createdAt: null,
    ),
  ];
  controller.joinRequests = [
    HomeschoolJoinRequest(
      id: 'r1',
      homeschoolId: 'joy',
      requesterUserId: 'u1',
      requesterEmail: 'yeseo.mom@example.com',
      requesterName: '김민지',
      requestNote: '예서 엄마예요 :) 가입 신청합니다.',
      status: 'PENDING',
      createdAt: DateTime(2026, 9, 27, 10, 20),
      requestedRole: 'PARENT',
    ),
  ];
  return controller;
}

class _LocalAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final file = File(key);
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      return ByteData.view(bytes.buffer);
    }
    final frontFile = File('frontend/$key');
    if (frontFile.existsSync()) {
      final bytes = await frontFile.readAsBytes();
      return ByteData.view(bytes.buffer);
    }
    return rootBundle.load(key);
  }
}

void main() {
  late SupabaseClient client;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
    try {
      await Supabase.initialize(
        url: 'https://avursvhmilcsssabqtkx.supabase.co',
        anonKey: 'anon-key-dummy',
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      );
    } catch (_) {
      // Already initialized
    }
    client = Supabase.instance.client;
  });

  final base = NestTheme.light();
  final theme = base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: const ['Roboto']),
  );

  Widget frame(GlobalKey key, Widget child, {Size size = const Size(400, 780)}) {
    return DefaultAssetBundle(
      bundle: _LocalAssetBundle(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        builder: (context, navChild) => RepaintBoundary(
          key: key,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: navChild!,
          ),
        ),
        home: Scaffold(
          backgroundColor: NestColors.creamyWhite,
          body: child,
        ),
      ),
    );
  }

  testWidgets('capture: 3D 브랜드 아이덴티티 및 파스텔 디자인 쇼케이스', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(440, 860);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();

    await tester.pumpWidget(frame(
      key,
      SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            Text(
              'Nest 3D Design System',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: NestColors.deepWood,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pastel Tone + Warm Radiant Palette',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: NestColors.clay,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            // 3D Mark & 3D App Icon row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: NestColors.dustyRose.withValues(alpha: 0.22),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        'assets/logo_3d_mark.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '3D Logo Mark',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: NestColors.deepWood,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Column(
                  children: [
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: NestColors.dustyRose.withValues(alpha: 0.22),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/logo_3d_app_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '3D App Icon',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: NestColors.deepWood,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Color Palette Chips
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Color Palette',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildColorChip('Dusty Rose', NestColors.dustyRose, '#F79D8E'),
                _buildColorChip('Rose Mist', NestColors.roseMist, '#FFF0EB'),
                _buildColorChip('Muted Sage', NestColors.mutedSage, '#90D5AF'),
                _buildColorChip('Clay Amber', NestColors.clay, '#D49A6A'),
                _buildColorChip('Pastel Sky', NestColors.pastelSky, '#B8E0F9'),
                _buildColorChip('Pastel Lavender', NestColors.pastelLavender, '#E4D7F5'),
                _buildColorChip('Pastel Butter', NestColors.pastelButter, '#FFF1C2'),
                _buildColorChip('Deep Wood', NestColors.deepWood, '#42342B', textColor: Colors.white),
              ],
            ),
            const SizedBox(height: 28),

            // Tactile Card Preview
            TactileCard(
              backgroundColor: Colors.white,
              borderRadius: 20,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [NestColors.dustyRose, NestColors.roseMist],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tactile Motion & Depth',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '0.975x 탭 스프링 반응 및 듀얼 레이어 파스텔 음영',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: NestColors.deepWood.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      size: const Size(440, 860),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await _shoot(tester, key, 'shot_branding_showcase.png');
  });

  testWidgets('capture: 첫 화면(스플래시) 3D 로고 및 브랜딩', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 840);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();

    await tester.pumpWidget(frame(
      key,
      const NestLoadingScreen(message: 'Nest를 준비하고 있습니다...'),
      size: const Size(420, 840),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await _shoot(tester, key, 'shot_splash_first_screen.png');
  });

  testWidgets('capture: 로그인 화면 3D 로고 및 파스텔 디자인', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 840);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = NestController(repository: NestRepository(client));
    final key = GlobalKey();

    await tester.pumpWidget(frame(
      key,
      LoginPage(controller: controller),
      size: const Size(420, 840),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await _shoot(tester, key, 'shot_login_screen.png');
  });

  testWidgets('capture: 회원가입 모드 전환 화면', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 840);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = NestController(repository: NestRepository(client));
    final key = GlobalKey();

    await tester.pumpWidget(frame(
      key,
      LoginPage(controller: controller),
      size: const Size(420, 840),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('회원가입').first);
    await tester.pump(const Duration(milliseconds: 300));

    await _shoot(tester, key, 'shot_signup_screen.png');
  });

  testWidgets('capture: 학부모 홈 화면 파스텔 디자인 및 카드 뎁스', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 840);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _seedParent(client);
    final key = GlobalKey();

    await tester.pumpWidget(frame(
      key,
      ParentHomeTab(
        controller: controller,
        selectedChildId: 'c-1',
        childClassBundles: const {},
        isLoadingChildClasses: false,
      ),
      size: const Size(420, 840),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await _shoot(tester, key, 'shot_parent_home.png');
  });

  testWidgets('capture: 멤버 관리 화면 파스텔 아바타 및 참여 코드', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 840);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _seedAdmin(client);
    final key = GlobalKey();

    await tester.pumpWidget(frame(
      key,
      MembersTab(controller: controller),
      size: const Size(420, 840),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await _shoot(tester, key, 'shot_members_tab.png');
  });

  testWidgets('capture: 3D 클레이모피즘 디자인 에셋 및 햅틱 UI 쇼케이스', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(440, 920);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();

    Widget buildAssetCard(String title, String subtitle, String tag) {
      return Container(
        width: 180,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: NestColors.roseMist.withValues(alpha: 0.8),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: NestColors.dustyRose.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              key: ValueKey('3d-slot-$tag'),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: NestColors.deepWood,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    await tester.pumpWidget(frame(
      key,
      SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'Nest 3D Claymorphism Suite',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: NestColors.deepWood,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '앱 전반에 확장 적용된 3D 촉각적 비주얼 시스템',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: NestColors.clay,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                buildAssetCard('공지사항 확성기', '공지 배너 & 소식', 'announcement'),
                buildAssetCard('학사 캘린더', '시간표 & 일정 뷰', 'calendar'),
                buildAssetCard('교과서 & 연필', '오늘 수업 & 진도', 'books'),
                buildAssetCard('홈스쿨 팁 전구', '오늘의 한 줄 & 가이드', 'lightbulb'),
                buildAssetCard('포근한 빈 둥지', '빈 상태(Empty State)', 'nest'),
                buildAssetCard('성취 골든 스타', '진도 완료 & 뱃지', 'star'),
              ],
            ),
            const SizedBox(height: 24),
            // Live 3D DockBar Preview
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '3D Clay Tactile Dock Bar',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: NestColors.dustyRose.withValues(alpha: 0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: NestDockBar(
                selectedIndex: 0,
                labels: const ['홈', '시간표', '소식', '앨범'],
                iconOf: (label, {required bool selected}) {
                  return switch (label) {
                    '홈' => Icon(selected ? Icons.home : Icons.home_outlined),
                    '시간표' => Icon(selected ? Icons.calendar_view_week : Icons.calendar_view_week_outlined),
                    '소식' => Icon(selected ? Icons.campaign : Icons.campaign_outlined),
                    '앨범' => Icon(selected ? Icons.photo_library : Icons.photo_library_outlined),
                    _ => const Icon(Icons.star),
                  };
                },
                onSelect: (_) {},
              ),
            ),
          ],
        ),
      ),
      size: const Size(440, 920),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await _shoot(tester, key, 'shot_3d_assets_showcase.png');
  });
}

Widget _buildColorChip(String label, Color color, String hex, {Color textColor = NestColors.deepWood}) {
  return Container(
    width: 95,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.black.withValues(alpha: 0.05),
        width: 1,
      ),
    ),
    child: Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          hex,
          style: TextStyle(
            fontSize: 10,
            color: textColor.withValues(alpha: 0.8),
          ),
        ),
      ],
    ),
  );
}
