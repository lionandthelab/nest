import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/widgets/portfolio_binder_view.dart';

const _shotsDir = 'tool/screenshots/shots';
const _artifactsDir =
    '/Users/mac/.gemini/antigravity/brain/456d46f0-e1f7-4edd-ae43-a4e72ebedbd0';

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
  }
}

Future<void> _shoot(WidgetTester tester, GlobalKey key, String filename) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = data!.buffer.asUint8List();

    // 1. shots 폴더 저장
    final dir = Directory(_shotsDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('$_shotsDir/$filename').writeAsBytesSync(bytes);

    // 2. artifacts 폴더에도 저장
    final artDir = Directory(_artifactsDir);
    if (artDir.existsSync()) {
      File('$_artifactsDir/$filename').writeAsBytesSync(bytes);
    }

    image.dispose();
  });
}

StudentPortfolioBundle _buildSampleBundle() {
  final now = DateTime(2026, 7, 17);
  return StudentPortfolioBundle(
    homeschool: const Homeschool(
      id: 'hs-joy',
      name: '조이홈스쿨',
      timezone: 'Asia/Seoul',
    ),
    term: Term(
      id: 'term-2026-1',
      homeschoolId: 'hs-joy',
      name: '2026학년도 1학기',
      status: 'ACTIVE',
      startDate: DateTime(2026, 3, 2),
      endDate: now,
    ),
    child: ChildProfile(
      id: 'child-joy-1',
      familyId: 'fam-joy',
      familyName: '김',
      name: '김기쁨',
      birthDate: DateTime(2015, 5, 20),
      profileNote: '초등학교 4학년 과정',
      status: 'ACTIVE',
      createdAt: DateTime(2026, 1, 1),
    ),
    totalSchoolDays: 95,
    attendedDays: 93,
    absentDays: 2,
    courses: const [
      Course(id: 'c1', homeschoolId: 'hs-joy', name: '국어 (독서/토론)', defaultDurationMin: 50),
      Course(id: 'c2', homeschoolId: 'hs-joy', name: '수학 (개념/사고력)', defaultDurationMin: 50),
      Course(id: 'c3', homeschoolId: 'hs-joy', name: '사회 & 과학 탐구', defaultDurationMin: 50),
      Course(id: 'c4', homeschoolId: 'hs-joy', name: '예술 (음악/미술)', defaultDurationMin: 50),
    ],
    photos: [
      GalleryItem(
        id: 'p1',
        title: '숲 체험학습',
        description: '자연 생태 탐구',
        mediaType: 'IMAGE',
        driveWebViewLink: '',
        storagePath: 'assets/3d/study_books_3d.png',
        classGroupId: 'cg1',
        capturedAt: now,
      ),
      GalleryItem(
        id: 'p2',
        title: '과학 탐구 발표',
        description: '창의 실험 페어',
        mediaType: 'IMAGE',
        driveWebViewLink: '',
        storagePath: 'assets/3d/achievement_star_3d.png',
        classGroupId: 'cg1',
        capturedAt: now,
      ),
    ],
    review: const StudentSemesterReview(
      id: 'rev-1',
      homeschoolId: 'hs-joy',
      termId: 'term-2026-1',
      childId: 'child-joy-1',
      teacherEvaluation:
          '한 학기 동안 매일 성실하게 배움에 참여하고 스스로 질문하며 탐구하는 모습이 매우 대견합니다.',
      parentEvaluation:
          '가정 안에서 스스로 학습 계획을 세우고 실천하는 자율성과 집중력이 크게 향상되었습니다.',
      studentReflection:
          '오늘도 정말 즐거운 하루였어요! 숲을 탐험하면서 다양한 나뭇잎과 나무를 관찰하고 배울 수 있어서 신기했습니다.',
      attendanceNote: '정규 수업 93일 성실 출석 및 가정체험학습 2일 참여 완료',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
  });

  testWidgets('Capture Portfolio Binder View (Desktop/Tablet & Mobile)',
      (tester) async {
    final key = GlobalKey();
    final bundle = _buildSampleBundle();

    // 1. 태블릿/와이드 바인더 뷰 캡처 (1080 x 860)
    tester.view.physicalSize = const Size(1080, 860);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: NestColors.creamyWhite,
          colorSchemeSeed: NestColors.dustyRose,
          fontFamily: 'DoHyeon',
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFFFBF8F2),
          body: RepaintBoundary(
            key: key,
            child: Container(
              color: const Color(0xFFFBF8F2),
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: PortfolioBinderView(
                bundle: bundle,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _shoot(tester, key, 'portfolio_binder_captured_ko.png');

    // 2. 모바일 뷰 캡처 (440 x 920)
    final mobileKey = GlobalKey();
    tester.view.physicalSize = const Size(440, 920);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: NestColors.creamyWhite,
          colorSchemeSeed: NestColors.dustyRose,
          fontFamily: 'DoHyeon',
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFFFBF8F2),
          body: RepaintBoundary(
            key: mobileKey,
            child: Container(
              color: const Color(0xFFFBF8F2),
              alignment: Alignment.topCenter,
              child: PortfolioBinderView(
                bundle: bundle,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _shoot(tester, mobileKey, 'portfolio_binder_mobile_ko.png');

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
