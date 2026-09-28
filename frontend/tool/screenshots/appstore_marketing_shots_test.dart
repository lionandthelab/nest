import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/album_organizer.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/models/child_class_bundle.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/tabs/album/album_tab.dart';
import 'package:nest_frontend/src/ui/tabs/members_tab.dart';
import 'package:nest_frontend/src/ui/tabs/parent_home_tab.dart';
import 'package:nest_frontend/src/ui/tabs/parent_timetable_tab.dart';
import 'package:nest_frontend/src/ui/widgets/nest_motion.dart';

const _shotsDir = 'shots/appstore_ui';

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
    final image = await boundary.toImage(pixelRatio: 2.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(_shotsDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('$_shotsDir/$name').writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
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

NestController _createSeedController(SupabaseClient client) {
  final controller = NestController(repository: NestRepository(client));
  final now = DateTime.now();

  const hs = Homeschool(
    id: 'hs-jaram',
    name: '자람 홈스쿨',
    timezone: 'Asia/Seoul',
    joinCode: 'JARAM26',
  );

  controller.selectedHomeschoolId = hs.id;
  controller.currentRole = 'PARENT';
  controller.memberships = [
    const Membership(
      userId: 'user-parent',
      homeschoolId: 'hs-jaram',
      role: 'PARENT',
      status: 'ACTIVE',
      homeschool: hs,
    ),
  ];

  final term = Term(
    id: 'term-fall',
    homeschoolId: hs.id,
    name: '2026 가을학기',
    startDate: now.subtract(const Duration(days: 20)),
    endDate: now.add(const Duration(days: 70)),
    status: 'ACTIVE',
  );
  controller.terms = [term];
  controller.selectedTermId = term.id;

  controller.children = [
    ChildProfile(
      id: 'child-minwoo',
      familyId: 'family-1',
      familyName: '민우네 가정',
      name: '민우',
      birthDate: DateTime(2017, 5, 10),
      profileNote: '초등 3학년',
      status: 'ACTIVE',
      createdAt: now,
    ),
  ];

  final classGroup = ClassGroup.fromMap({
    'id': 'cg-sunflower',
    'term_id': term.id,
    'name': '해바라기반',
  });
  controller.classGroups = [classGroup];

  final courseKorean = Course.fromMap({
    'id': 'c-kor',
    'homeschool_id': hs.id,
    'name': '국어',
    'color': '#F79D8E',
  });
  final courseMath = Course.fromMap({
    'id': 'c-math',
    'homeschool_id': hs.id,
    'name': '수학',
    'color': '#90D5AF',
  });
  final courseEng = Course.fromMap({
    'id': 'c-eng',
    'homeschool_id': hs.id,
    'name': '영어',
    'color': '#B8E0F9',
  });
  final courseSci = Course.fromMap({
    'id': 'c-sci',
    'homeschool_id': hs.id,
    'name': '과학',
    'color': '#D49A6A',
  });
  final courseArt = Course.fromMap({
    'id': 'c-art',
    'homeschool_id': hs.id,
    'name': '미술',
    'color': '#E8B4B8',
  });

  controller.courses = [courseKorean, courseMath, courseEng, courseSci, courseArt];

  final timeSlots = <TimeSlot>[];
  final sessions = <ClassSession>[];

  final slotTimes = [
    ('1교시', '09:00:00', '09:50:00'),
    ('2교시', '10:00:00', '10:50:00'),
    ('3교시', '13:00:00', '13:50:00'),
    ('4교시', '17:00:00', '17:50:00'),
  ];

  final weeklyPlan = [
    [courseKorean, courseMath, courseEng, courseSci],
    [courseMath, courseKorean, courseArt, courseSci],
    [courseEng, courseKorean, courseMath, courseArt],
    [courseSci, courseArt, courseKorean, courseEng],
    [courseMath, courseEng, courseSci, courseKorean],
  ];

  for (var day = 1; day <= 5; day++) {
    for (var sIdx = 0; sIdx < slotTimes.length; sIdx++) {
      final slotId = 'ts-$day-$sIdx';
      final st = slotTimes[sIdx];
      timeSlots.add(
        TimeSlot(
          id: slotId,
          termId: term.id,
          dayOfWeek: day,
          startTime: st.$2,
          endTime: st.$3,
        ),
      );

      final course = weeklyPlan[day - 1][sIdx];
      sessions.add(
        ClassSession(
          id: 'cs-$day-$sIdx',
          classGroupId: classGroup.id,
          courseId: course.id,
          timeSlotId: slotId,
          title: course.name,
          sourceType: 'MANUAL',
          status: 'PLANNED',
          location: '1층 배움터',
        ),
      );
    }
  }

  controller.timeSlots = timeSlots;
  controller.allTermSessions = sessions;
  controller.allTermSessionTeacherAssignments = [
    for (final s in sessions)
      SessionTeacherAssignment(
        id: 'sta-${s.id}',
        classSessionId: s.id,
        teacherProfileId: 'tp-1',
        assignmentRole: 'MAIN',
      ),
  ];

  controller.personalEvents = [
    PersonalEvent(
      id: 'ps-1',
      homeschoolId: hs.id,
      ownerUserId: 'user-parent',
      childId: 'child-minwoo',
      title: '바이올린 레슨 (14:30)',
      startsAt: DateTime(now.year, now.month, now.day, 14, 30),
      endsAt: DateTime(now.year, now.month, now.day, 15, 30),
      notes: '교재 지참',
    ),
    PersonalEvent(
      id: 'ps-2',
      homeschoolId: hs.id,
      ownerUserId: 'user-parent',
      childId: 'child-minwoo',
      title: '태권도 품새 심사 (16:00)',
      startsAt: DateTime(now.year, now.month, now.day, 16, 0),
      endsAt: DateTime(now.year, now.month, now.day, 17, 0),
      notes: '도복 착용',
    ),
  ];

  controller.announcements = [
    Announcement(
      id: 'a-1',
      homeschoolId: hs.id,
      classGroupId: null,
      authorUserId: 'u-admin',
      title: '가을 숲 생태 체험학습 및 준비물 안내 (필독)',
      body: '다음 주 수요일 자연학습을 진행합니다. 편한 복장과 수첩, 도시락을 챙겨주세요.',
      pinned: true,
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
  ];

  controller.academicEvents = [
    AcademicEvent(
      id: 'ae-1',
      homeschoolId: hs.id,
      termId: term.id,
      title: '개천절 휴강',
      description: '공휴일 가정학습',
      eventDate: now.add(const Duration(days: 3)),
    ),
    AcademicEvent(
      id: 'ae-2',
      homeschoolId: hs.id,
      termId: term.id,
      title: '한글날 기념 특별 글짓기 수업',
      description: '한글의 소중함을 배우는 시간',
      eventDate: now.add(const Duration(days: 9)),
    ),
    AcademicEvent(
      id: 'ae-3',
      homeschoolId: hs.id,
      termId: term.id,
      title: '가을 숲 생태 탐방의 날',
      description: '자연 관찰 및 낙엽 책갈피 제작',
      eventDate: now.add(const Duration(days: 15)),
    ),
  ];

  controller.driveIntegration = const DriveIntegration(
    id: 'd-1',
    homeschoolId: 'hs-jaram',
    status: 'CONNECTED',
    googleEmail: 'jaram.admin@gmail.com',
  );

  controller.albumSummaries = [
    AlbumSummary(
      scope: 'CLASS_GROUP',
      scopeId: classGroup.id,
      scopeName: '해바라기반',
      itemCount: 48,
      photoCount: 45,
      videoCount: 3,
    ),
    AlbumSummary(
      scope: 'FOLDER',
      scopeId: 'f-1',
      scopeName: '가을 숲 소풍',
      itemCount: 32,
      photoCount: 32,
      videoCount: 0,
    ),
    AlbumSummary(
      scope: 'FOLDER',
      scopeId: 'f-2',
      scopeName: '사이언스 데이',
      itemCount: 26,
      photoCount: 24,
      videoCount: 2,
    ),
    AlbumSummary(
      scope: 'FOLDER',
      scopeId: 'f-3',
      scopeName: '창의 코딩 드론 실습',
      itemCount: 18,
      photoCount: 16,
      videoCount: 2,
    ),
  ];

  controller.galleryItems = List.generate(6, (i) {
    return GalleryItem.fromMap({
      'id': 'g-$i',
      'title': [
        '가을 숲 생태 탐방 낙엽 책갈피',
        '사이언스 데이 로봇 만들기',
        '도자기 물레 공예 체험',
        '어린이 동화 구연 발표회',
        '창의 코딩 드론 실습',
        '사과 농장 수확 체험'
      ][i],
      'media_type': 'PHOTO',
      'storage_path': 'hs-jaram/2026-09/photo-$i.jpg',
      'captured_at': now.subtract(Duration(days: i * 2)).toIso8601String(),
    });
  });

  controller.families = [
    Family(id: 'f1', homeschoolId: 'hs-jaram', familyName: '민우네 가정', note: '초등 3학년 민우', createdAt: now),
    Family(id: 'f2', homeschoolId: 'hs-jaram', familyName: '서연이네 가정', note: '초등 1학년 서연, 유치부 서준', createdAt: now),
    Family(id: 'f3', homeschoolId: 'hs-jaram', familyName: '하은이네 가정', note: '초등 4학년 하은', createdAt: now),
  ];


  controller.joinRequests = [
    HomeschoolJoinRequest(
      id: 'r1',
      homeschoolId: 'hs-jaram',
      requesterUserId: 'u-join',
      requesterEmail: 'yeseo.mom@example.com',
      requesterName: '김민지',
      requestNote: '예서 엄마예요 :) 가입 신청합니다.',
      status: 'PENDING',
      createdAt: now.subtract(const Duration(hours: 4)),
      requestedRole: 'PARENT',
    ),
  ];

  return controller;
}

Map<String, ChildClassBundle> _createSeedBundles(NestController controller) {
  final map = <String, ChildClassBundle>{};
  for (final cg in controller.classGroups) {
    final sessions = controller.allTermSessions.where((s) => s.classGroupId == cg.id).toList();
    final sessionIds = sessions.map((s) => s.id).toSet();
    final assignments = controller.allTermSessionTeacherAssignments
        .where((a) => sessionIds.contains(a.classSessionId))
        .toList();
    map[cg.id] = ChildClassBundle(
      classGroup: cg,
      sessions: sessions,
      assignments: assignments,
      announcements: controller.announcements
          .where((a) => a.classGroupId == cg.id || a.classGroupId == null)
          .toList(),
    );
  }
  return map;
}

void main() {
  late SupabaseClient client;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'nest.cache.user-parent._albumViewMode': 'folder',
    });
    await _loadFonts();
    try {
      await Supabase.initialize(
        url: 'https://avursvhmilcsssabqtkx.supabase.co',
        anonKey: 'anon-key-dummy',
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      );
    } catch (_) {}
    client = Supabase.instance.client;
  });

  final base = NestTheme.light();
  final theme = base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: const ['Roboto']),
  );

  Widget buildTopPhoneBar(NestController controller) {
    return Container(
      color: NestColors.creamyWhite,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '9:41',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              Container(
                width: 90,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Row(
                children: const [
                  Icon(Icons.signal_cellular_4_bar, size: 14, color: Colors.black87),
                  SizedBox(width: 4),
                  Icon(Icons.wifi, size: 14, color: Colors.black87),
                  SizedBox(width: 4),
                  Icon(Icons.battery_full, size: 16, color: Colors.black87),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: NestColors.roseMist.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home_rounded, size: 15, color: NestColors.clay),
                    const SizedBox(width: 4),
                    Text(
                      '자람 홈스쿨',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: NestColors.deepWood,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.expand_more, size: 15, color: NestColors.clay),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: NestColors.roseMist),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.child_friendly_rounded, size: 15, color: Colors.black87),
                    SizedBox(width: 4),
                    Text(
                      '민우 (초등 3학년)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: NestColors.roseMist),
                ),
                child: const Icon(Icons.notifications_none_rounded, size: 18, color: Colors.black87),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget phoneWrapper(GlobalKey key, Widget child, {required NestController controller, int dockIndex = 0}) {
    return DefaultAssetBundle(
      bundle: _LocalAssetBundle(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, navChild) => RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 412,
            height: 892,
            child: navChild!,
          ),
        ),
        home: Scaffold(
          backgroundColor: NestColors.creamyWhite,
          body: Stack(
            children: [
              Positioned.fill(
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      buildTopPhoneBar(controller),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: NestColors.dustyRose.withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: NestDockBar(
                    selectedIndex: dockIndex,
                    labels: const ['홈', '시간표', '소식', '앨범'],
                    iconOf: (label, {required bool selected}) {
                      return switch (label) {
                        '홈' => Icon(selected ? Icons.home_rounded : Icons.home_outlined),
                        '시간표' => Icon(selected ? Icons.calendar_view_week_rounded : Icons.calendar_view_week_outlined),
                        '소식' => Icon(selected ? Icons.campaign_rounded : Icons.campaign_outlined),
                        '앨범' => Icon(selected ? Icons.photo_library_rounded : Icons.photo_library_outlined),
                        _ => const Icon(Icons.star_rounded),
                      };
                    },
                    onSelect: (_) {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('appstore: 01 홈 대시보드 화면 캡처', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 892);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _createSeedController(client);
    final bundles = _createSeedBundles(controller);
    final key = GlobalKey();

    await tester.pumpWidget(phoneWrapper(
      key,
      ParentHomeTab(
        controller: controller,
        selectedChildId: 'child-minwoo',
        childClassBundles: bundles,
        isLoadingChildClasses: false,
      ),
      controller: controller,
      dockIndex: 0,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await _shoot(tester, key, 'raw_01_home.png');
  });

  testWidgets('appstore: 02 시간표 화면 캡처', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 892);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _createSeedController(client);
    final bundles = _createSeedBundles(controller);
    final key = GlobalKey();

    await tester.pumpWidget(phoneWrapper(
      key,
      ParentTimetableTab(
        controller: controller,
        selectedChildId: 'child-minwoo',
        childClassBundles: bundles,
        isLoadingChildClasses: false,
      ),
      controller: controller,
      dockIndex: 1,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await _shoot(tester, key, 'raw_02_timetable.png');
  });

  testWidgets('appstore: 03 활동 앨범 화면 캡처', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 892);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _createSeedController(client);
    final key = GlobalKey();

    await tester.pumpWidget(phoneWrapper(
      key,
      AlbumTab(
        controller: controller,
        initialMode: AlbumViewMode.folder,
      ),
      controller: controller,
      dockIndex: 3,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await _shoot(tester, key, 'raw_03_album.png');
  });

  testWidgets('appstore: 04 멤버 및 반 관리 화면 캡처', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 892);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _createSeedController(client);
    controller.currentRole = 'HOMESCHOOL_ADMIN';
    final key = GlobalKey();

    await tester.pumpWidget(phoneWrapper(
      key,
      MembersTab(controller: controller),
      controller: controller,
      dockIndex: 0,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await _shoot(tester, key, 'raw_04_members.png');
  });

  testWidgets('appstore: 05 홈스쿨 팁 & 포트폴리오 화면 캡처', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 892);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _createSeedController(client);
    final bundles = _createSeedBundles(controller);
    final key = GlobalKey();

    await tester.pumpWidget(phoneWrapper(
      key,
      ParentHomeTab(
        controller: controller,
        selectedChildId: 'child-minwoo',
        childClassBundles: bundles,
        isLoadingChildClasses: false,
      ),
      controller: controller,
      dockIndex: 0,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Scroll down to reveal 3D tips and academic events
    await tester.drag(find.byType(ParentHomeTab), const Offset(0, -950));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await _shoot(tester, key, 'raw_05_tips.png');
  });
}
