import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/nest_models.dart';

/// 포트폴리오 PDF 생성 옵션
class PortfolioExportOptions {
  const PortfolioExportOptions({
    this.includeCover = true,
    this.includeStudentProfile = true,
    this.includeAttendance = true,
    this.includeCurriculum = true,
    this.includeActivities = true,
    this.includeComprehensiveReview = true,
    this.includePhotos = true,
    this.selectedPhotoIds = const {},
    this.photoImageBytes = const {},
    this.customTeacherEvaluation,
    this.customParentEvaluation,
    this.customStudentReflection,
    this.customAttendanceNote,
  });

  final bool includeCover;
  final bool includeStudentProfile;
  final bool includeAttendance;
  final bool includeCurriculum;
  final bool includeActivities;
  final bool includeComprehensiveReview;
  final bool includePhotos;
  final Set<String> selectedPhotoIds;
  final Map<String, Uint8List> photoImageBytes;

  final String? customTeacherEvaluation;
  final String? customParentEvaluation;
  final String? customStudentReflection;
  final String? customAttendanceNote;
}

/// 한국 학교/교육청 제출 및 가정 보관용 한 학기 학습 포트폴리오 PDF 생성기
class PortfolioPdfBuilder {
  static const PdfColor colorPrimary = PdfColor.fromInt(0xFF8A5A44); // 딥 더스티 로즈
  static const PdfColor colorSecondary = PdfColor.fromInt(0xFF5A4637); // 딥 우드
  static const PdfColor colorAccent = PdfColor.fromInt(0xFF8A9A84); // 세이지
  static const PdfColor colorLightBg = PdfColor.fromInt(0xFFFAF7F3); // 크리미 화이트
  static const PdfColor colorMist = PdfColor.fromInt(0xFFF4ECE6); // 로즈 미스트
  static const PdfColor colorBorder = PdfColor.fromInt(0xFFE2D9D0);
  static const PdfColor colorTextDark = PdfColor.fromInt(0xFF2E2620);
  static const PdfColor colorTextMuted = PdfColor.fromInt(0xFF7A6D63);

  /// 포트폴리오 PDF 바이트 생성
  static Future<Uint8List> buildPdf({
    required StudentPortfolioBundle bundle,
    required PortfolioExportOptions options,
  }) async {
    // 번들 한글 폰트 로드
    final juaData = await rootBundle.load('assets/fonts/Jua-Regular.ttf');
    final doHyeonData =
        await rootBundle.load('assets/fonts/DoHyeon-Regular.ttf');

    final fontBase = pw.Font.ttf(juaData);
    final fontBold = pw.Font.ttf(doHyeonData);

    // 로고 이미지 로드 (있을 시)
    Uint8List? logoBytes;
    try {
      final logoData = await rootBundle.load('assets/logo_square.png');
      logoBytes = logoData.buffer.asUint8List();
    } catch (_) {}

    final doc = pw.Document(
      title: '${bundle.child.name}_${bundle.term.name}_학습포트폴리오',
      author: bundle.homeschool.name,
      creator: 'Nest Homeschool Platform',
      theme: pw.ThemeData.withFont(
        base: fontBase,
        bold: fontBold,
      ),
    );

    final termStartStr = bundle.term.startDate != null
        ? DateFormat('yyyy.MM.dd').format(bundle.term.startDate!)
        : '-';
    final termEndStr = bundle.term.endDate != null
        ? DateFormat('yyyy.MM.dd').format(bundle.term.endDate!)
        : '-';

    // ─────────────────────────────────────────────────────────────
    // 1. 표지 (Cover Page)
    // ─────────────────────────────────────────────────────────────
    if (options.includeCover) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: colorPrimary, width: 2),
                borderRadius: pw.BorderRadius.circular(16),
              ),
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // 상단 기관 및 배지
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: colorMist,
                          borderRadius: pw.BorderRadius.circular(20),
                        ),
                        child: pw.Text(
                          '${bundle.term.name} · 공식 포트폴리오',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 12,
                            color: colorPrimary,
                          ),
                        ),
                      ),
                      if (logoBytes != null)
                        pw.Image(
                          pw.MemoryImage(logoBytes),
                          width: 42,
                          height: 42,
                        ),
                    ],
                  ),

                  // 중앙 제목
                  pw.Column(
                    children: [
                      pw.Text(
                        '학 습 포 트 폴 리 오',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 32,
                          color: colorSecondary,
                          letterSpacing: 4,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Student Learning & Growth Portfolio',
                        style: pw.TextStyle(
                          fontSize: 13,
                          color: colorTextMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.SizedBox(height: 24),
                      pw.Container(
                        width: 140,
                        height: 2,
                        color: colorPrimary,
                      ),
                      pw.SizedBox(height: 20),
                      pw.Text(
                        '한 학기 교육과정 이수 및 활동 성취 종합 보고서',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: colorTextDark,
                        ),
                      ),
                    ],
                  ),

                  // 학생 및 학기 정보 카드
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: colorLightBg,
                      borderRadius: pw.BorderRadius.circular(12),
                      border: pw.Border.all(color: colorBorder),
                    ),
                    child: pw.Column(
                      children: [
                        _buildCoverInfoRow('학 생 성 명', bundle.child.name,
                            fontBold, fontBase),
                        pw.SizedBox(height: 10),
                        _buildCoverInfoRow(
                          '생 년 월 일',
                          bundle.child.birthDate != null
                              ? DateFormat('yyyy년 MM월 dd일')
                                  .format(bundle.child.birthDate!)
                              : '생일 미기재',
                          fontBold,
                          fontBase,
                        ),
                        pw.SizedBox(height: 10),
                        _buildCoverInfoRow(
                          '소 속 기 관',
                          bundle.homeschool.name,
                          fontBold,
                          fontBase,
                        ),
                        pw.SizedBox(height: 10),
                        _buildCoverInfoRow(
                          '학 급 (반)',
                          bundle.classGroup?.name ?? '홈스쿨 통합과정',
                          fontBold,
                          fontBase,
                        ),
                        pw.SizedBox(height: 10),
                        _buildCoverInfoRow(
                          '담 임 교 사',
                          bundle.mainTeacher?.displayName ??
                              (bundle.child.familyName.isNotEmpty
                                  ? '${bundle.child.familyName} 지도교사'
                                  : '지도교사'),
                          fontBold,
                          fontBase,
                        ),
                        pw.SizedBox(height: 10),
                        _buildCoverInfoRow(
                          '학 기 기 간',
                          '$termStartStr ~ $termEndStr',
                          fontBold,
                          fontBase,
                        ),
                      ],
                    ),
                  ),

                  // 하단 서명란
                  pw.Column(
                    children: [
                      pw.Text(
                        DateFormat('yyyy년 MM월 dd일 발급').format(DateTime.now()),
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: colorTextMuted,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            bundle.homeschool.name,
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 18,
                              color: colorSecondary,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Container(
                            width: 52,
                            height: 52,
                            decoration: pw.BoxDecoration(
                              border:
                                  pw.Border.all(color: colorPrimary, width: 1.5),
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              '직인\n생략',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 10,
                                color: colorPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────
    // 2. 인적·학적 사항 및 출결 상황 총괄표
    // ─────────────────────────────────────────────────────────────
    if (options.includeStudentProfile || options.includeAttendance) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPageHeader('1. 인적·학적 사항 및 2. 출결 상황', fontBold),
                pw.SizedBox(height: 16),

                if (options.includeStudentProfile) ...[
                  _buildSectionTitle('1. 인적 및 학적 사항', fontBold),
                  pw.SizedBox(height: 8),
                  _buildStudentInfoTable(bundle, fontBold, fontBase),
                  pw.SizedBox(height: 24),
                ],

                if (options.includeAttendance) ...[
                  _buildSectionTitle('2. 출결 상황 총괄', fontBold),
                  pw.SizedBox(height: 8),
                  _buildAttendanceSummaryTable(bundle, fontBold, fontBase),
                  pw.SizedBox(height: 14),

                  _buildSubSectionTitle('■ 결석 및 출결 특기사항', fontBold),
                  pw.SizedBox(height: 6),
                  _buildAbsenceDetailsSection(
                    bundle,
                    options.customAttendanceNote,
                    fontBold,
                    fontBase,
                  ),
                ],

                pw.Spacer(),
                _buildPageFooter(context.pageNumber, fontBase),
              ],
            );
          },
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────
    // 3. 교과학습 발달상황 (과목별 진도 및 수업 활동)
    // ─────────────────────────────────────────────────────────────
    if (options.includeCurriculum) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPageHeader('3. 교과학습 발달상황', fontBold),
                pw.SizedBox(height: 16),

                _buildSectionTitle('3. 교과목별 이수 및 학습 진도', fontBold),
                pw.SizedBox(height: 8),
                _buildCoursesTable(bundle, fontBold, fontBase),
                pw.SizedBox(height: 20),

                _buildSectionTitle('■ 수업 관찰 및 과제 활동 기록', fontBold),
                pw.SizedBox(height: 8),
                _buildActivityLogsSummary(bundle, fontBold, fontBase),

                pw.Spacer(),
                _buildPageFooter(context.pageNumber, fontBase),
              ],
            );
          },
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────
    // 4. 창의적 체험활동 & 자기주도학습
    // ─────────────────────────────────────────────────────────────
    if (options.includeActivities) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPageHeader('4. 창의적 체험활동 및 자율학습', fontBold),
                pw.SizedBox(height: 16),

                _buildSectionTitle('4. 학사 행사 및 현장체험학습', fontBold),
                pw.SizedBox(height: 8),
                _buildAcademicEventsTable(bundle, fontBold, fontBase),
                pw.SizedBox(height: 20),

                _buildSectionTitle('■ 자기주도학습 및 특별활동', fontBold),
                pw.SizedBox(height: 8),
                _buildSelfStudyPlansSection(bundle, fontBold, fontBase),

                pw.Spacer(),
                _buildPageFooter(context.pageNumber, fontBase),
              ],
            );
          },
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────
    // 5. 행동특성 및 종합의견 (교사/학부모/학생 성찰 & 직인)
    // ─────────────────────────────────────────────────────────────
    if (options.includeComprehensiveReview) {
      final teacherEval = options.customTeacherEvaluation ??
          bundle.review?.teacherEvaluation ??
          _generateDefaultTeacherComment(bundle);
      final parentEval = options.customParentEvaluation ??
          bundle.review?.parentEvaluation ??
          _generateDefaultParentComment(bundle);
      final studentReflect = options.customStudentReflection ??
          bundle.review?.studentReflection ??
          '이번 학기 동안 다양한 교과와 체험을 통해 배움의 즐거움을 알게 되었고, 계획을 스스로 세우고 지켜나가는 방법을 배웠습니다.';

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPageHeader('5. 행동특성 및 종합의견', fontBold),
                pw.SizedBox(height: 14),

                _buildSectionTitle('5. 한 학기 돌아보기 종합 평가', fontBold),
                pw.SizedBox(height: 10),

                // 담임 교사 종합의견
                _buildCommentBox(
                  title: '담임(지도) 교사 종합의견',
                  author: bundle.mainTeacher?.displayName ?? '지도교사',
                  content: teacherEval,
                  fontBold: fontBold,
                  fontBase: fontBase,
                ),
                pw.SizedBox(height: 12),

                // 학부모 관찰 총평
                _buildCommentBox(
                  title: '학부모 가정학습 관찰 총평',
                  author: '보호자',
                  content: parentEval,
                  fontBold: fontBold,
                  fontBase: fontBase,
                ),
                pw.SizedBox(height: 12),

                // 학생 한 학기 돌아보기
                _buildCommentBox(
                  title: '학생 본인 성찰 및 소감문',
                  author: bundle.child.name,
                  content: studentReflect,
                  fontBold: fontBold,
                  fontBase: fontBase,
                ),
                pw.SizedBox(height: 18),

                // 최종 확인 및 직인 날인란
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: colorLightBg,
                    border: pw.Border.all(color: colorBorder),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        '위 학생의 ${bundle.term.name} 교육과정 이수 및 활동 포트폴리오 기재 내용이 사실임을 확인합니다.',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 11.5,
                          color: colorTextDark,
                        ),
                      ),
                      pw.SizedBox(height: 14),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            DateFormat('yyyy년 MM월 dd일').format(DateTime.now()),
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: colorTextMuted,
                            ),
                          ),
                          pw.Row(
                            children: [
                              pw.Text(
                                '담임 교사: ${bundle.mainTeacher?.displayName ?? "지도교사"}  (서명/인)',
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 11,
                                  color: colorSecondary,
                                ),
                              ),
                            ],
                          ),
                          pw.Row(
                            children: [
                              pw.Text(
                                '${bundle.homeschool.name} 대표  (직인)',
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 11,
                                  color: colorSecondary,
                                ),
                              ),
                              pw.SizedBox(width: 6),
                              pw.Container(
                                width: 28,
                                height: 28,
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(
                                      color: colorPrimary, width: 1.2),
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                                alignment: pw.Alignment.center,
                                child: pw.Text(
                                  '인',
                                  style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 9,
                                    color: colorPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),
                _buildPageFooter(context.pageNumber, fontBase),
              ],
            );
          },
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────
    // 6. 활동 사진 포트폴리오 (추억 앨범 & 활동 증빙)
    // ─────────────────────────────────────────────────────────────
    if (options.includePhotos) {
      // 선택된 사진 필터링
      final targetPhotos = bundle.photos.where((p) {
        if (options.selectedPhotoIds.isNotEmpty) {
          return options.selectedPhotoIds.contains(p.id);
        }
        return true;
      }).toList();

      // 한 페이지당 4장(2x2)씩 배치
      const photosPerPage = 4;
      final pageCount = math.max(1, (targetPhotos.length / photosPerPage).ceil());

      for (var pageIdx = 0; pageIdx < pageCount; pageIdx++) {
        final start = pageIdx * photosPerPage;
        final currentPhotos = targetPhotos.skip(start).take(photosPerPage).toList();

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(36),
            build: (context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildPageHeader(
                    '6. 활동 사진 포트폴리오 (${pageIdx + 1}/$pageCount)',
                    fontBold,
                  ),
                  pw.SizedBox(height: 14),

                  if (currentPhotos.isEmpty)
                    pw.Expanded(
                      child: pw.Center(
                        child: pw.Text(
                          '등록된 학기 활동 사진이 없습니다.',
                          style: pw.TextStyle(
                            fontSize: 13,
                            color: colorTextMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    pw.Expanded(
                      child: pw.GridView(
                        crossAxisCount: 2,
                        childAspectRatio: 0.88,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        children: currentPhotos.map((item) {
                          final bytes = options.photoImageBytes[item.id];
                          final dateStr = item.capturedAt != null
                              ? DateFormat('yyyy.MM.dd').format(item.capturedAt!)
                              : '';

                          return pw.Container(
                            decoration: pw.BoxDecoration(
                              color: colorLightBg,
                              border: pw.Border.all(color: colorBorder),
                              borderRadius: pw.BorderRadius.circular(10),
                            ),
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Expanded(
                                  child: pw.ClipRRect(
                                    horizontalRadius: 8,
                                    verticalRadius: 8,
                                    child: bytes != null
                                        ? pw.Image(
                                            pw.MemoryImage(bytes),
                                            fit: pw.BoxFit.cover,
                                            width: double.infinity,
                                          )
                                        : pw.Container(
                                            color: colorMist,
                                            alignment: pw.Alignment.center,
                                            child: pw.Text(
                                              '사진 미리보기',
                                              style: pw.TextStyle(
                                                fontSize: 11,
                                                color: colorTextMuted,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                pw.SizedBox(height: 6),
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Expanded(
                                      child: pw.Text(
                                        item.title.isNotEmpty
                                            ? item.title
                                            : '활동 기록',
                                        maxLines: 1,
                                        style: pw.TextStyle(
                                          font: fontBold,
                                          fontSize: 11,
                                          color: colorSecondary,
                                        ),
                                      ),
                                    ),
                                    if (dateStr.isNotEmpty)
                                      pw.Text(
                                        dateStr,
                                        style: pw.TextStyle(
                                          fontSize: 9,
                                          color: colorTextMuted,
                                        ),
                                      ),
                                  ],
                                ),
                                if (item.description.isNotEmpty) ...[
                                  pw.SizedBox(height: 3),
                                  pw.Text(
                                    item.description,
                                    maxLines: 2,
                                    style: pw.TextStyle(
                                      fontSize: 9.5,
                                      color: colorTextDark,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  pw.SizedBox(height: 10),
                  _buildPageFooter(context.pageNumber, fontBase),
                ],
              );
            },
          ),
        );
      }
    }

    return doc.save();
  }

  // ─────────────────────────────────────────────────────────────
  // 보조 위젯 및 테이블 렌더러
  // ─────────────────────────────────────────────────────────────

  static pw.Widget _buildPageHeader(String title, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: colorPrimary, width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 14,
              color: colorSecondary,
            ),
          ),
          pw.Text(
            'Nest Learning Portfolio',
            style: pw.TextStyle(
              fontSize: 10,
              color: colorTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title, pw.Font fontBold) {
    return pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 14,
          color: colorPrimary,
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          title,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 13,
            color: colorSecondary,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSubSectionTitle(String title, pw.Font fontBold) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        font: fontBold,
        fontSize: 11,
        color: colorSecondary,
      ),
    );
  }

  static pw.Widget _buildPageFooter(int pageNumber, pw.Font fontBase) {
    return pw.Center(
      child: pw.Text(
        '- $pageNumber -',
        style: pw.TextStyle(
          font: fontBase,
          fontSize: 10,
          color: colorTextMuted,
        ),
      ),
    );
  }

  static pw.Widget _buildCoverInfoRow(
    String label,
    String value,
    pw.Font fontBold,
    pw.Font fontBase,
  ) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 12,
              color: colorTextMuted,
            ),
          ),
        ),
        pw.Text(
          ':  ',
          style: pw.TextStyle(fontSize: 12, color: colorTextMuted),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 13,
              color: colorSecondary,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildStudentInfoTable(
    StudentPortfolioBundle bundle,
    pw.Font fontBold,
    pw.Font fontBase,
  ) {
    final birth = bundle.child.birthDate;
    final birthStr =
        birth != null ? DateFormat('yyyy.MM.dd').format(birth) : '생일 미기재';
    final ageStr =
        birth != null ? ' (만 ${DateTime.now().year - birth.year}세)' : '';

    return pw.Table(
      border: pw.TableBorder.all(color: colorBorder, width: 0.8),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: colorMist),
          children: [
            _tableHeaderCell('성 명', fontBold),
            _tableValueCell(bundle.child.name, fontBold),
            _tableHeaderCell('생년월일', fontBold),
            _tableValueCell('$birthStr$ageStr', fontBase),
          ],
        ),
        pw.TableRow(
          children: [
            _tableHeaderCell('소속 학급', fontBold),
            _tableValueCell(bundle.classGroup?.name ?? '통합반', fontBase),
            _tableHeaderCell('담임 교사', fontBold),
            _tableValueCell(bundle.mainTeacher?.displayName ?? '지도교사', fontBase),
          ],
        ),
        pw.TableRow(
          children: [
            _tableHeaderCell('보호자(가족)', fontBold),
            _tableValueCell(
              bundle.child.familyName.isNotEmpty
                  ? '${bundle.child.familyName} 가정'
                  : '등록 보호자',
              fontBase,
            ),
            _tableHeaderCell('소속 홈스쿨', fontBold),
            _tableValueCell(bundle.homeschool.name, fontBase),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildAttendanceSummaryTable(
    StudentPortfolioBundle bundle,
    pw.Font fontBold,
    pw.Font fontBase,
  ) {
    final rate = bundle.totalSchoolDays > 0
        ? ((bundle.attendedDays / bundle.totalSchoolDays) * 100).toStringAsFixed(1)
        : '100.0';

    return pw.Table(
      border: pw.TableBorder.all(color: colorBorder, width: 0.8),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: colorMist),
          children: [
            _tableHeaderCell('수업 일수', fontBold),
            _tableHeaderCell('출석 일수', fontBold),
            _tableHeaderCell('결석 일수', fontBold),
            _tableHeaderCell('출석률', fontBold),
            _tableHeaderCell('결석 신고 건수', fontBold),
          ],
        ),
        pw.TableRow(
          children: [
            _tableCenteredCell('${bundle.totalSchoolDays}일', fontBase),
            _tableCenteredCell('${bundle.attendedDays}일', fontBold),
            _tableCenteredCell('${bundle.absentDays}일', fontBase),
            _tableCenteredCell('$rate%', fontBold),
            _tableCenteredCell('${bundle.absenceRecords.length}건', fontBase),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildAbsenceDetailsSection(
    StudentPortfolioBundle bundle,
    String? customNote,
    pw.Font fontBold,
    pw.Font fontBase,
  ) {
    if (bundle.absenceRecords.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: colorLightBg,
          border: pw.Border.all(color: colorBorder),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          customNote?.isNotEmpty == true
              ? customNote!
              : '해당 학기 전일 출석하였으며, 특이 결석 사유가 없습니다.',
          style: pw.TextStyle(
            fontSize: 10.5,
            color: colorTextDark,
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: colorBorder, width: 0.8),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(4),
            2: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: colorMist),
              children: [
                _tableHeaderCell('결석 일자', fontBold),
                _tableHeaderCell('사 유', fontBold),
                _tableHeaderCell('처리 상태', fontBold),
              ],
            ),
            ...bundle.absenceRecords.take(5).map((record) {
              final d = DateFormat('yyyy.MM.dd').format(record.occurrenceDate);
              final statusStr = record.isAcknowledged ? '교사확인(인정)' : '신고접수';
              return pw.TableRow(
                children: [
                  _tableCenteredCell(d, fontBase),
                  _tableValueCell(
                    record.reason.isNotEmpty ? record.reason : '개인 사유',
                    fontBase,
                  ),
                  _tableCenteredCell(statusStr, fontBase),
                ],
              );
            }),
          ],
        ),
        if (customNote != null && customNote.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            '※ 특기사항: $customNote',
            style: pw.TextStyle(fontSize: 10, color: colorTextMuted),
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildCoursesTable(
    StudentPortfolioBundle bundle,
    pw.Font fontBold,
    pw.Font fontBase,
  ) {
    if (bundle.courses.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: colorLightBg,
          border: pw.Border.all(color: colorBorder),
        ),
        child: pw.Text('등록된 교과목 정보가 없습니다.',
            style: pw.TextStyle(fontSize: 11, color: colorTextMuted)),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: colorBorder, width: 0.8),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(1.8),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(5.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: colorMist),
          children: [
            _tableHeaderCell('교 과 목', fontBold),
            _tableHeaderCell('담당 교사', fontBold),
            _tableHeaderCell('수업 시수', fontBold),
            _tableHeaderCell('주요 학습 주제 및 성취 내용', fontBold),
          ],
        ),
        ...bundle.courses.take(8).map((course) {
          final courseLessons = bundle.courseLessons
              .where((l) => l.courseId == course.id)
              .take(3)
              .map((l) => l.headline)
              .where((s) => s.isNotEmpty)
              .toList();

          final lessonSummary = courseLessons.isNotEmpty
              ? courseLessons.join(' / ')
              : '기초 개념 이해 및 실습 활동 참여';

          return pw.TableRow(
            children: [
              _tableValueCell(course.name, fontBold),
              _tableCenteredCell(
                bundle.mainTeacher?.displayName ?? '과목교사',
                fontBase,
              ),
              _tableCenteredCell('${course.defaultDurationMin}분', fontBase),
              _tableValueCell(lessonSummary, fontBase),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildActivityLogsSummary(
    StudentPortfolioBundle bundle,
    pw.Font fontBold,
    pw.Font fontBase,
  ) {
    final nonAttendanceLogs = bundle.activityLogs
        .where((l) => l.activityType != 'ATTENDANCE')
        .take(5)
        .toList();

    if (nonAttendanceLogs.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: colorLightBg,
          border: pw.Border.all(color: colorBorder),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          '학기 중 과제 및 관찰 평가를 성실히 이행하였습니다.',
          style: pw.TextStyle(fontSize: 10.5, color: colorTextDark),
        ),
      );
    }

    return pw.Column(
      children: nonAttendanceLogs.map((log) {
        final dateStr = log.recordedAt != null
            ? DateFormat('yyyy.MM.dd').format(log.recordedAt!)
            : '';
        final typeLabel = log.activityType == 'ASSIGNMENT' ? '과제' : '관찰';

        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            color: colorLightBg,
            border: pw.Border.all(color: colorBorder),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: colorMist,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  typeLabel,
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 9.5, color: colorPrimary),
                ),
              ),
              pw.SizedBox(width: 8),
              if (dateStr.isNotEmpty) ...[
                pw.Text(
                  dateStr,
                  style: pw.TextStyle(fontSize: 9.5, color: colorTextMuted),
                ),
                pw.SizedBox(width: 8),
              ],
              pw.Expanded(
                child: pw.Text(
                  log.content,
                  style: pw.TextStyle(fontSize: 10, color: colorTextDark),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildAcademicEventsTable(
    StudentPortfolioBundle bundle,
    pw.Font fontBold,
    pw.Font fontBase,
  ) {
    if (bundle.academicEvents.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: colorLightBg,
          border: pw.Border.all(color: colorBorder),
        ),
        child: pw.Text('해당 학기 등록된 학사 행사가 없습니다.',
            style: pw.TextStyle(fontSize: 11, color: colorTextMuted)),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: colorBorder, width: 0.8),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1.8),
        2: pw.FlexColumnWidth(3),
        3: pw.FlexColumnWidth(4.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: colorMist),
          children: [
            _tableHeaderCell('일 자', fontBold),
            _tableHeaderCell('구 분', fontBold),
            _tableHeaderCell('행 사 명', fontBold),
            _tableHeaderCell('활동 내용 및 성과', fontBold),
          ],
        ),
        ...bundle.academicEvents.take(6).map((e) {
          final d = DateFormat('yyyy.MM.dd').format(e.eventDate);
          final kindLabel = switch (e.kind) {
            'FIELD_TRIP' => '현장체험',
            'CEREMONY' => '입학/수료',
            'HOLIDAY' => '공휴일',
            'BREAK' => '방학',
            _ => '학사행사',
          };

          return pw.TableRow(
            children: [
              _tableCenteredCell(d, fontBase),
              _tableCenteredCell(kindLabel, fontBase),
              _tableValueCell(e.title, fontBold),
              _tableValueCell(
                e.description.isNotEmpty ? e.description : '학교 공동체 참여 활동',
                fontBase,
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildSelfStudyPlansSection(
    StudentPortfolioBundle bundle,
    pw.Font fontBold,
    pw.Font fontBase,
  ) {
    if (bundle.selfStudyPlans.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: colorLightBg,
          border: pw.Border.all(color: colorBorder),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          '자기주도 학습 계획에 맞춰 독서, 자율 과제 및 프로젝트 탐구를 꾸준히 실천하였습니다.',
          style: pw.TextStyle(fontSize: 10.5, color: colorTextDark),
        ),
      );
    }

    return pw.Column(
      children: bundle.selfStudyPlans.take(3).map((plan) {
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: colorLightBg,
            border: pw.Border.all(color: colorBorder),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      plan.name,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 11,
                        color: colorSecondary,
                      ),
                    ),
                    if (plan.note.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        plan.note,
                        style: pw.TextStyle(fontSize: 10, color: colorTextDark),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Text(
                '${plan.windowStart} ~ ${plan.windowEnd}',
                style: pw.TextStyle(fontSize: 10, color: colorTextMuted),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildCommentBox({
    required String title,
    required String author,
    required String content,
    required pw.Font fontBold,
    required pw.Font fontBase,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: colorLightBg,
        border: pw.Border.all(color: colorBorder),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '■ $title',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 11.5,
                  color: colorSecondary,
                ),
              ),
              pw.Text(
                '작성: $author',
                style: pw.TextStyle(fontSize: 9.5, color: colorTextMuted),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            content,
            style: pw.TextStyle(
              fontSize: 10.5,
              color: colorTextDark,
              lineSpacing: 2.5,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableHeaderCell(String text, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Center(
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 10,
            color: colorSecondary,
          ),
        ),
      ),
    );
  }

  static pw.Widget _tableValueCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 9.5,
          color: colorTextDark,
        ),
      ),
    );
  }

  static pw.Widget _tableCenteredCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Center(
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: font,
            fontSize: 9.5,
            color: colorTextDark,
          ),
        ),
      ),
    );
  }

  static String _generateDefaultTeacherComment(StudentPortfolioBundle bundle) {
    final observations = bundle.activityLogs
        .where((l) => l.activityType == 'OBSERVATION')
        .take(2)
        .map((l) => l.content)
        .join(' 또한, ');

    if (observations.isNotEmpty) {
      return '$observations 한 학기 동안 주도적으로 학습에 참여하며 긍정적인 성장을 보여주었습니다.';
    }

    return '매 수업에 적극적인 자세로 성실하게 임하였으며, 친구들과 협력하는 태도가 매우 우수합니다. '
        '배운 내용을 깊이 있게 이해하고 스스로 탐구하려는 호기심과 실천력이 돋보였습니다.';
  }

  static String _generateDefaultParentComment(StudentPortfolioBundle bundle) {
    return '가정에서도 정해진 시간에 스스로 학습하고 독서하는 습관을 훌륭하게 실천하였습니다. '
        '가족과의 대화에 적극적이고, 학기 중 진행된 홈스쿨 활동을 기쁨으로 나누며 건강하고 바르게 성장하고 있습니다.';
  }
}
