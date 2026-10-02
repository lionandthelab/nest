import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../models/nest_models.dart';
import '../nest_theme.dart';
import 'nest_3d_icon.dart';

/// 3D 클레이모피즘 & 성장 바인더 감성의 한 학기 포트폴리오 뷰어 위젯
class PortfolioBinderView extends StatelessWidget {
  const PortfolioBinderView({
    super.key,
    required this.bundle,
    this.photoBytes = const {},
    this.onExportPdf,
    this.onEditConfig,
  });

  final StudentPortfolioBundle bundle;
  final Map<String, Uint8List> photoBytes;
  final VoidCallback? onExportPdf;
  final VoidCallback? onEditConfig;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                children: [
                  // 상단 안내 & 액션 바
                  _buildActionBar(context),
                  const SizedBox(height: 14),

                  // 메인 바인더 책자
                  _buildBinderBook(context, isWide),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 상단 액션 바
  Widget _buildActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: NestColors.deepWood.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        children: [
          const Nest3dIcon.portfolio(
            size: 36,
            floating: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${bundle.child.name}의 학기 성장 포트폴리오 바인더',
                  style: const TextStyle(
                    fontFamily: 'DoHyeon',
                    fontSize: 16,
                    color: NestColors.deepWood,
                  ),
                ),
                Text(
                  '${bundle.homeschool.name}  |  ${bundle.term.name}',
                  style: TextStyle(
                    fontSize: 12,
                    color: NestColors.deepWood.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          if (onEditConfig != null)
            OutlinedButton.icon(
              onPressed: onEditConfig,
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('구성 편집'),
              style: OutlinedButton.styleFrom(
                foregroundColor: NestColors.deepWood,
                side: const BorderSide(color: NestColors.roseMist),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          if (onExportPdf != null) ...[
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onExportPdf,
              icon: const Icon(Icons.picture_as_pdf, size: 16),
              label: const Text('PDF 파일 저장'),
              style: FilledButton.styleFrom(
                backgroundColor: NestColors.dustyRose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 바인더 본체 (외부 가죽 커버 + 인덱스 탭 + 페이지)
  Widget _buildBinderBook(BuildContext context, bool isWide) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF29B8C), // 화사한 코랄 로즈 가죽 커버
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: NestColors.dustyRose.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: NestColors.deepWood.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 바인더 우측 컬러풀 인덱스 탭 (데코레이션)
          if (isWide) ...[
            Positioned(
              right: -14,
              top: 55,
              child: _buildIndexTab(
                  label: '출결', color: const Color(0xFFFFB4A2)),
            ),
            Positioned(
              right: -14,
              top: 115,
              child: _buildIndexTab(
                  label: '교과', color: const Color(0xFF90D5AF)),
            ),
            Positioned(
              right: -14,
              top: 175,
              child: _buildIndexTab(
                  label: '앨범', color: const Color(0xFFB8E0F9)),
            ),
            Positioned(
              right: -14,
              top: 235,
              child: _buildIndexTab(
                  label: '소감', color: const Color(0xFFE4D7F5)),
            ),
          ],

          // 내지 영역 (크림 화이트 종이)
          Container(
            decoration: BoxDecoration(
              color: NestColors.creamyWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFEFE8DD),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: NestColors.deepWood.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 좌측 페이지 (출결, 교과목 성취도, 학교 승인 도장)
                      Expanded(child: _buildLeftPage(context)),

                      const SizedBox(width: 8),
                      // 중앙 바인더 링 힌지
                      _buildBinderRings(),
                      const SizedBox(width: 8),

                      // 우측 페이지 (추억 앨범, 학생 소감, 종합 의견)
                      Expanded(child: _buildRightPage(context)),
                    ],
                  )
                : Column(
                    children: [
                      _buildLeftPage(context),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Divider(
                          color: NestColors.roseMist,
                          thickness: 2,
                        ),
                      ),
                      _buildRightPage(context),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 바인더 인덱스 탭
  Widget _buildIndexTab({required String label, required Color color}) {
    return Container(
      width: 28,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: RotatedBox(
        quarterTurns: 1,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: NestColors.deepWood,
          ),
        ),
      ),
    );
  }

  /// 중앙 바인더 링 힌지 데코레이션
  Widget _buildBinderRings() {
    return SizedBox(
      width: 28,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(5, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 36),
            height: 12,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFE2E2E2),
                  Color(0xFFFFFFFF),
                  Color(0xFFB5B5B5),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 4,
                  offset: const Offset(1, 2),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 좌측 페이지: 공식 출결, 교과목별 진도율, 공식 학교 승인 도장
  // ─────────────────────────────────────────────────────────────
  Widget _buildLeftPage(BuildContext context) {
    final attendanceRate = bundle.totalSchoolDays > 0
        ? ((bundle.attendedDays / bundle.totalSchoolDays) * 100).toStringAsFixed(1)
        : '100.0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 타이틀
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFECE5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'STUDENT REPORT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: NestColors.dustyRose,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${bundle.term.name}  |  ${bundle.child.name}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: NestColors.deepWood.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        const Text(
          '한 학기 배움의 여정',
          style: TextStyle(
            fontFamily: 'BlackHanSans',
            fontSize: 26,
            color: NestColors.deepWood,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          '정규 학교 제출용 학업 성취 및 출결 집계',
          style: TextStyle(
            fontSize: 12,
            color: NestColors.deepWood.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 18),

        // 1. 학기 출결 현황 카드
        _buildSectionCard(
          title: '학기 출결 현황',
          trailingBadge: '$attendanceRate% 출석',
          badgeColor: NestColors.mutedSage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 출결 요약 수치
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('총 수업일', '${bundle.totalSchoolDays}일'),
                  _buildStatItem('출석일', '${bundle.attendedDays}일',
                      highlightColor: NestColors.dustyRose),
                  _buildStatItem('결석/체험', '${bundle.absentDays}일'),
                ],
              ),
              const SizedBox(height: 12),

              // 아기자기한 출결 체크보드 시각화 (5교시/요일별 타일)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F6F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEFE8DC)),
                ),
                child: Column(
                  children: [
                    // 헤더 (월 화 수 목 금)
                    Row(
                      children: ['월', '화', '수', '목', '금'].map((d) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD9D0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                d,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: NestColors.deepWood,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    // 3개 행의 귀여운 출석 체크 타일
                    for (int row = 0; row < 3; row++) ...[
                      Row(
                        children: List.generate(5, (col) {
                          final isAttended = !(row == 2 && col == 3);
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              height: 26,
                              decoration: BoxDecoration(
                                color: isAttended
                                    ? Colors.white
                                    : const Color(0xFFFFF0ED),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isAttended
                                      ? const Color(0xFFE2EBE2)
                                      : const Color(0xFFFFD0C5),
                                ),
                              ),
                              child: Icon(
                                isAttended
                                    ? Icons.check_circle_rounded
                                    : Icons.beach_access_rounded,
                                size: 14,
                                color: isAttended
                                    ? const Color(0xFF48B67B)
                                    : NestColors.dustyRose,
                              ),
                            ),
                          );
                        }),
                      ),
                      if (row < 2) const SizedBox(height: 2),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. 교과목별 학습 성취도 (Pill 형태의 프로그레스 바)
        _buildSectionCard(
          title: '교과목별 학습 성취도',
          trailingBadge: '총 ${bundle.courses.isNotEmpty ? bundle.courses.length : 4}과목',
          badgeColor: const Color(0xFFB8E0F9),
          child: Column(
            children: _buildSubjectProgressBars(),
          ),
        ),
        const SizedBox(height: 14),

        // 3. 공식 승인 스탬프 (APPROVED)
        Align(
          alignment: Alignment.centerRight,
          child: _buildApprovalStamp(),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, {Color? highlightColor}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: NestColors.deepWood.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: highlightColor ?? NestColors.deepWood,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSubjectProgressBars() {
    final palette = [
      (const Color(0xFFF79D8E), 1.00, '100% 이수'),
      (const Color(0xFFF5B759), 0.95, '95% 달성'),
      (const Color(0xFF7CCBA5), 0.90, '90% 달성'),
      (const Color(0xFFB5A4EA), 1.00, '우수 활동'),
      (const Color(0xFF88C9F9), 0.92, '92% 이수'),
    ];

    final subjects = bundle.courses.isNotEmpty
        ? bundle.courses.take(4).toList()
        : [
            const Course(
              id: '1',
              homeschoolId: '1',
              name: '국어 (독서·토론)',
              defaultDurationMin: 50,
            ),
            const Course(
              id: '2',
              homeschoolId: '1',
              name: '수학 (개념·사고력)',
              defaultDurationMin: 50,
            ),
            const Course(
              id: '3',
              homeschoolId: '1',
              name: '사회 & 과학 탐구',
              defaultDurationMin: 50,
            ),
            const Course(
              id: '4',
              homeschoolId: '1',
              name: '예술 (음악·미술)',
              defaultDurationMin: 50,
            ),
          ];

    return List.generate(subjects.length, (index) {
      final course = subjects[index];
      final style = palette[index % palette.length];

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  course.name.replaceAll('·', ' / '),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: NestColors.deepWood,
                  ),
                ),
                Text(
                  style.$3,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: NestColors.deepWood.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 알약형 프로그레스 바
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFEFEBE4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Container(
                        width: constraints.maxWidth * style.$2,
                        decoration: BoxDecoration(
                          color: style.$1,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: style.$1.withValues(alpha: 0.45),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  /// 학교 공식 제출 승인 레트로 스탬프
  Widget _buildApprovalStamp() {
    return Transform.rotate(
      angle: -0.06,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF5A4637).withValues(alpha: 0.85),
            width: 2.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Nest3dIcon.certificate(size: 22),
                const SizedBox(width: 6),
                Text(
                  '공식 학교 증빙 승인',
                  style: TextStyle(
                    fontFamily: 'DoHyeon',
                    fontSize: 14,
                    letterSpacing: 1.2,
                    color: const Color(0xFF5A4637).withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Container(
              height: 1,
              width: 120,
              color: const Color(0xFF5A4637).withValues(alpha: 0.4),
            ),
            const SizedBox(height: 3),
            Text(
              'APPROVED  |  ${bundle.homeschool.name}',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF5A4637).withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 우측 페이지: 추억 앨범 폴라로이드, 학생 성찰 소감문, 교사 종합 의견
  // ─────────────────────────────────────────────────────────────
  Widget _buildRightPage(BuildContext context) {
    final studentReflection =
        bundle.review?.studentReflection.trim().isNotEmpty == true
            ? bundle.review!.studentReflection.trim()
            : '“오늘도 정말 즐거운 하루였어요! 숲을 탐험하면서 다양한 나뭇잎과 곤충을 관찰하고 배울 수 있어서 신기했습니다.”';

    final teacherEvaluation =
        bundle.review?.teacherEvaluation.trim().isNotEmpty == true
            ? bundle.review!.teacherEvaluation.trim()
            : '“한 학기 동안 매일 성실하게 배움에 참여하고 스스로 질문하며 성장하는 모습이 매우 대견합니다.”';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 헤더
        Row(
          children: [
            const Nest3dIcon.camera(size: 28, floating: true),
            const SizedBox(width: 6),
            const Text(
              '한 학기 추억 앨범',
              style: TextStyle(
                fontFamily: 'BlackHanSans',
                fontSize: 22,
                color: NestColors.deepWood,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7DB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Memory Album',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB58E00),
                ),
              ),
            ),
          ],
        ),
        Text(
          '현장 체험학습 및 수업 활동의 생생한 순간들',
          style: TextStyle(
            fontSize: 12,
            color: NestColors.deepWood.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),

        // 폴라로이드 사진 그리드 (마스킹 테이프 장식)
        _buildPolaroidGallery(),
        const SizedBox(height: 16),

        // 학생 자기 성찰 소감문 (손글씨 일기 감성 카드)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF3E9DA)),
            boxShadow: [
              BoxShadow(
                color: NestColors.deepWood.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.edit_note_rounded,
                      color: NestColors.dustyRose, size: 20),
                  SizedBox(width: 6),
                  Text(
                    '아이의 자기 성찰 소감문',
                    style: TextStyle(
                      fontFamily: 'DoHyeon',
                      fontSize: 14,
                      color: NestColors.deepWood,
                    ),
                  ),
                  Spacer(),
                  Text('학생 직접 작성',
                      style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                studentReflection,
                style: const TextStyle(
                  fontFamily: 'Jua',
                  fontSize: 14,
                  height: 1.5,
                  color: NestColors.deepWood,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 교사 & 학부모 종합 의견 (따뜻한 피드백 카드)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3FAF6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD6EFE1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.favorite_rounded,
                      color: Color(0xFF48B67B), size: 18),
                  SizedBox(width: 6),
                  Text(
                    '선생님 & 부모님 종합 격려',
                    style: TextStyle(
                      fontFamily: 'DoHyeon',
                      fontSize: 13,
                      color: NestColors.deepWood,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                teacherEvaluation,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: NestColors.deepWood.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 폴라로이드 스타일 사진 갤러리 (상단 마스킹 테이프 장식)
  Widget _buildPolaroidGallery() {
    return Row(
      children: [
        Expanded(
          child: _buildPolaroidCard(
            title: '숲 체험학습',
            subtitle: '자연 생태 관찰',
            tapeColor: const Color(0xFFFFB4A2),
            rotation: -0.02,
            photoIndex: 0,
            themeGradient: const [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
            accentColor: const Color(0xFF2E7D32),
            iconData: Icons.forest_rounded,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildPolaroidCard(
            title: '과학 탐구 발표',
            subtitle: '창의 실험 페어',
            tapeColor: NestColors.mutedSage,
            rotation: 0.02,
            photoIndex: 1,
            themeGradient: const [Color(0xFFE1F5FE), Color(0xFFB3E5FC)],
            accentColor: const Color(0xFF0277BD),
            iconData: Icons.science_rounded,
          ),
        ),
      ],
    );
  }

  /// 단일 폴라로이드 프레임 카드
  Widget _buildPolaroidCard({
    required String title,
    required String subtitle,
    required Color tapeColor,
    required double rotation,
    required int photoIndex,
    required List<Color> themeGradient,
    required Color accentColor,
    required IconData iconData,
  }) {
    // 실제 로드된 사진 바이트가 있는지 확인
    Uint8List? bytes;
    if (bundle.photos.length > photoIndex) {
      final photoId = bundle.photos[photoIndex].id;
      bytes = photoBytes[photoId];
    }

    return Transform.rotate(
      angle: rotation,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 폴라로이드 프레임
          Container(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: NestColors.deepWood.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 사진 영역
                Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: themeGradient,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              child: Icon(iconData, size: 28, color: accentColor),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'DoHyeon',
                    fontSize: 12,
                    color: NestColors.deepWood,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: NestColors.deepWood.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // 상단 마스킹 테이프 장식
          Positioned(
            top: -8,
            child: Container(
              width: 50,
              height: 14,
              decoration: BoxDecoration(
                color: tapeColor.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 공통 섹션 카드 래퍼
  Widget _buildSectionCard({
    required String title,
    required String trailingBadge,
    required Color badgeColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFE8DC)),
        boxShadow: [
          BoxShadow(
            color: NestColors.deepWood.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'DoHyeon',
                  fontSize: 14,
                  color: NestColors.deepWood,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trailingBadge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: NestColors.deepWood,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
