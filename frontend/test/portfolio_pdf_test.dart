import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/portfolio_pdf_builder.dart';
import 'package:nest_frontend/src/ui/widgets/portfolio_binder_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  StudentPortfolioBundle buildSampleBundle({int absentDays = 2}) {
    return StudentPortfolioBundle(
      homeschool: const Homeschool(
        id: 'hs-1',
        name: '조이홈스쿨',
        timezone: 'Asia/Seoul',
      ),
      term: Term(
        id: 'term-1',
        homeschoolId: 'hs-1',
        name: '2026학년도 1학기',
        status: 'ACTIVE',
        startDate: DateTime(2026, 3, 2),
        endDate: DateTime(2026, 7, 17),
      ),
      child: ChildProfile(
        id: 'child-1',
        familyId: 'fam-1',
        familyName: '김',
        name: '김기쁨',
        birthDate: DateTime(2015, 5, 20),
        profileNote: '',
        status: 'ACTIVE',
        createdAt: DateTime(2026, 1, 1),
      ),
      totalSchoolDays: 95,
      attendedDays: 95 - absentDays,
      absentDays: absentDays,
      courses: const [
        Course(
          id: 'c-1',
          homeschoolId: 'hs-1',
          name: '국어',
          defaultDurationMin: 50,
        ),
        Course(
          id: 'c-2',
          homeschoolId: 'hs-1',
          name: '수학',
          defaultDurationMin: 50,
        ),
      ],
      courseLessons: [
        CourseLesson(
          id: 'les-1',
          courseId: 'c-1',
          lessonDate: DateTime(2026, 3, 10),
          title: '시와 이야기 읽기',
          subtitle: '동시 낭송 및 감상 나누기',
        ),
      ],
      absenceRecords: absentDays > 0
          ? [
              AbsenceReport(
                id: 'abs-1',
                classSessionId: 'sess-1',
                childId: 'child-1',
                occurrenceDate: DateTime(2026, 4, 10),
                reason: '가정체험학습',
                reportedByUserId: 'u-2',
                status: 'ACKNOWLEDGED',
                acknowledgedByUserId: 't-1',
                acknowledgedAt: DateTime(2026, 4, 11),
                notifiedAt: null,
                createdAt: DateTime(2026, 4, 9),
              ),
            ]
          : const [],
      academicEvents: [
        AcademicEvent(
          id: 'evt-1',
          homeschoolId: 'hs-1',
          termId: 'term-1',
          title: '봄 현장체험학습',
          description: '국립과천과학관 탐방',
          eventDate: DateTime(2026, 4, 25),
          kind: 'FIELD_TRIP',
        ),
      ],
      photos: [
        GalleryItem(
          id: 'photo-1',
          title: '과학관 로봇 체험',
          description: '친구들과 로봇 팔을 조작해 보았어요',
          mediaType: 'PHOTO',
          driveWebViewLink: 'https://example.com/1.jpg',
          storagePath: null,
          classGroupId: 'cg-1',
          capturedAt: DateTime(2026, 4, 25),
        ),
        GalleryItem(
          id: 'photo-2',
          title: '텃밭 가꾸기',
          description: '상추 모종 심기',
          mediaType: 'PHOTO',
          driveWebViewLink: 'https://example.com/2.jpg',
          storagePath: null,
          classGroupId: 'cg-1',
          capturedAt: DateTime(2026, 5, 12),
        ),
      ],
      review: const StudentSemesterReview(
        id: 'rev-1',
        homeschoolId: 'hs-1',
        termId: 'term-1',
        childId: 'child-1',
        teacherEvaluation: '호기심이 많고 질문을 적극적으로 합니다.',
        parentEvaluation: '책임감 있게 과제를 해내고 있습니다.',
        studentReflection: '역사 수업이 가장 흥미로웠습니다.',
        attendanceNote: '체험학습 1일 출석 인정',
      ),
    );
  }

  group('PortfolioPdfBuilder', () {
    test('StudentPortfolioBundle constructs properly', () {
      final bundle = buildSampleBundle();

      expect(bundle.child.name, '김기쁨');
      expect(bundle.totalSchoolDays, 95);
      expect(bundle.attendedDays, 93);
      expect(bundle.absentDays, 2);
      expect(bundle.courses.length, 2);
      expect(bundle.review?.teacherEvaluation, contains('호기심'));
    });

    test('PortfolioPdfBuilder generates valid PDF bytes starting with %PDF', () async {
      final bundle = buildSampleBundle();

      const options = PortfolioExportOptions(
        includeCover: true,
        includeStudentProfile: true,
        includeAttendance: true,
        includeCurriculum: true,
        includeActivities: true,
        includeComprehensiveReview: true,
        includePhotos: true,
      );

      final pdfBytes = await PortfolioPdfBuilder.buildPdf(
        bundle: bundle,
        options: options,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes[0], 0x25); // %
      expect(pdfBytes[1], 0x50); // P
      expect(pdfBytes[2], 0x44); // D
      expect(pdfBytes[3], 0x46); // F
    });

    test('PortfolioPdfBuilder falls back to cover page when all include options are false', () async {
      final bundle = buildSampleBundle();

      const options = PortfolioExportOptions(
        includeCover: false,
        includeStudentProfile: false,
        includeAttendance: false,
        includeCurriculum: false,
        includeActivities: false,
        includeComprehensiveReview: false,
        includePhotos: false,
      );

      final pdfBytes = await PortfolioPdfBuilder.buildPdf(
        bundle: bundle,
        options: options,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes[0], 0x25);
    });
  });

  group('PortfolioBinderView', () {
    testWidgets('renders binder spread with real lesson counts, custom evaluations, and selected photos', (tester) async {
      final bundle = buildSampleBundle(absentDays: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PortfolioBinderView(
                bundle: bundle,
                selectedPhotoIds: const {'photo-1'},
                customTeacherEvaluation: '실시간 수정된 교사 총평입니다.',
                customParentEvaluation: '실시간 수정된 가정 총평입니다.',
                customStudentReflection: '실시간 수정된 학생 소감문입니다.',
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('김기쁨의 학기 성장 포트폴리오 바인더'), findsOneWidget);
      expect(find.textContaining('1회 수업'), findsOneWidget);
      expect(find.text('과학관 로봇 체험'), findsWidgets);
      expect(find.text('텃밭 가꾸기'), findsNothing);
      expect(find.text('실시간 수정된 교사 총평입니다.'), findsOneWidget);
      expect(find.text('실시간 수정된 가정 총평입니다.'), findsOneWidget);
      expect(find.text('실시간 수정된 학생 소감문입니다.'), findsOneWidget);
    });
  });
}
