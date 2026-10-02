import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/portfolio_pdf_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PortfolioPdfBuilder', () {
    test('StudentPortfolioBundle constructs properly', () {
      final bundle = StudentPortfolioBundle(
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
        attendedDays: 93,
        absentDays: 2,
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
        absenceRecords: [
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
        ],
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

      expect(bundle.child.name, '김기쁨');
      expect(bundle.totalSchoolDays, 95);
      expect(bundle.attendedDays, 93);
      expect(bundle.absentDays, 2);
      expect(bundle.courses.length, 2);
      expect(bundle.review?.teacherEvaluation, contains('호기심'));
    });

    test('PortfolioPdfBuilder generates valid PDF bytes starting with %PDF', () async {
      final bundle = StudentPortfolioBundle(
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
        attendedDays: 93,
        absentDays: 2,
        courses: const [
          Course(
            id: 'c-1',
            homeschoolId: 'hs-1',
            name: '국어',
            defaultDurationMin: 50,
          ),
        ],
      );

      const options = PortfolioExportOptions(
        includeCover: true,
        includeStudentProfile: true,
        includeAttendance: true,
        includeCurriculum: true,
        includeActivities: true,
        includeComprehensiveReview: true,
        includePhotos: false,
      );

      final pdfBytes = await PortfolioPdfBuilder.buildPdf(
        bundle: bundle,
        options: options,
      );

      expect(pdfBytes, isNotEmpty);
      // PDF 파일 시그니처: %PDF (0x25, 0x50, 0x44, 0x46)
      expect(pdfBytes[0], 0x25); // %
      expect(pdfBytes[1], 0x50); // P
      expect(pdfBytes[2], 0x44); // D
      expect(pdfBytes[3], 0x46); // F
    });
  });
}
