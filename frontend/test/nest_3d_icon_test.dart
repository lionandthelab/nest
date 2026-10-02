import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/ui/widgets/nest_3d_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Nest3dIcon - 20종 에셋 생성자 무결성 검증', () {
    testWidgets('모든 3D 클레이 아이콘 생성자가 정상 렌더링된다', (tester) async {
      const icons = <Widget>[
        Nest3dIcon.home(),
        Nest3dIcon.community(),
        Nest3dIcon.termSetup(),
        Nest3dIcon.system(),
        Nest3dIcon.teacher(),
        Nest3dIcon.student(),
        Nest3dIcon.family(),
        Nest3dIcon.bell(),
        Nest3dIcon.pencil(),
        Nest3dIcon.chart(),
        Nest3dIcon.checkStamp(),
        Nest3dIcon.announcement(),
        Nest3dIcon.calendar(),
        Nest3dIcon.studyBooks(),
        Nest3dIcon.lightbulb(),
        Nest3dIcon.emptyNest(),
        Nest3dIcon.star(),
        Nest3dIcon.portfolio(),
        Nest3dIcon.camera(),
        Nest3dIcon.certificate(),
      ];

      for (final icon in icons) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(child: icon),
            ),
          ),
        );
        expect(find.byType(Image), findsOneWidget);
      }
    });

    testWidgets('Nest3dIcon.forTab이 라벨별로 알맞은 3D 아이콘과 투명도를 반환한다', (tester) async {
      final tabLabels = [
        '홈',
        '시간표',
        '자습',
        '학습 현황',
        '소식',
        'Teacher Hub',
        '학기 설정',
        '시스템',
        '커뮤니티',
        'Members',
        '앨범',
        '기타 미지정 탭',
      ];

      for (final label in tabLabels) {
        // Unselected (opacity applied)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Nest3dIcon.forTab(label, size: 24, selected: false),
            ),
          ),
        );
        expect(find.byType(Opacity), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);

        // Selected (no opacity wrap)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Nest3dIcon.forTab(label, size: 26, selected: true),
            ),
          ),
        );
        expect(find.byType(Image), findsOneWidget);
      }
    });
  });
}
