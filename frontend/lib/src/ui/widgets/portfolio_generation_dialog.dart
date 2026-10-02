import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/nest_models.dart';
import '../../services/download_helper.dart';
import '../../services/portfolio_pdf_builder.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import 'entity_visuals.dart';
import 'nest_3d_icon.dart';
import 'nest_skeleton.dart';
import 'portfolio_binder_view.dart';

/// 포트폴리오 생성 다이얼로그 호출 함수
Future<void> showPortfolioGenerationDialog(
  BuildContext context, {
  required NestController controller,
  String? initialTermId,
  String? initialChildId,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _PortfolioGenerationDialog(
      controller: controller,
      initialTermId: initialTermId,
      initialChildId: initialChildId,
    ),
  );
}

class _PortfolioGenerationDialog extends StatefulWidget {
  const _PortfolioGenerationDialog({
    required this.controller,
    this.initialTermId,
    this.initialChildId,
  });

  final NestController controller;
  final String? initialTermId;
  final String? initialChildId;

  @override
  State<_PortfolioGenerationDialog> createState() =>
      _PortfolioGenerationDialogState();
}

class _PortfolioGenerationDialogState extends State<_PortfolioGenerationDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late String _selectedTermId;
  late String _selectedChildId;

  bool _isLoading = true;
  StudentPortfolioBundle? _bundle;

  // 섹션 포함 여부
  bool _includeCover = true;
  bool _includeStudentProfile = true;
  bool _includeAttendance = true;
  bool _includeCurriculum = true;
  bool _includeActivities = true;
  bool _includeComprehensiveReview = true;
  bool _includePhotos = true;

  // 선택된 사진 ID 목록
  final Set<String> _selectedPhotoIds = {};
  final Map<String, Uint8List> _loadedPhotoBytes = {};

  // 종합의견 입력 컨트롤러
  final TextEditingController _teacherCommentCtrl = TextEditingController();
  final TextEditingController _parentCommentCtrl = TextEditingController();
  final TextEditingController _studentReflectionCtrl = TextEditingController();
  final TextEditingController _attendanceNoteCtrl = TextEditingController();

  bool _isSavingReview = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _selectedTermId = widget.initialTermId ??
        widget.controller.selectedTermId ??
        (widget.controller.terms.isNotEmpty
            ? widget.controller.terms.first.id
            : '');

    _selectedChildId = widget.initialChildId ??
        (widget.controller.children.isNotEmpty
            ? widget.controller.children.first.id
            : '');

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _teacherCommentCtrl.dispose();
    _parentCommentCtrl.dispose();
    _studentReflectionCtrl.dispose();
    _attendanceNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_selectedTermId.isEmpty || _selectedChildId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bundle = await widget.controller.compilePortfolioBundle(
        termId: _selectedTermId,
        childId: _selectedChildId,
      );

      _bundle = bundle;

      // 리뷰 텍스트 필드 초기화
      if (bundle.review != null) {
        _teacherCommentCtrl.text = bundle.review!.teacherEvaluation;
        _parentCommentCtrl.text = bundle.review!.parentEvaluation;
        _studentReflectionCtrl.text = bundle.review!.studentReflection;
        _attendanceNoteCtrl.text = bundle.review!.attendanceNote;
      } else {
        _teacherCommentCtrl.text = '';
        _parentCommentCtrl.text = '';
        _studentReflectionCtrl.text = '';
        _attendanceNoteCtrl.text = '';
      }

      // 기본 사진 선택: 최대 4장 자동 선택
      _selectedPhotoIds.clear();
      for (final photo in bundle.photos.take(4)) {
        _selectedPhotoIds.add(photo.id);
      }

      // 선택된 사진 바이트 비동기 프리로드
      _preloadPhotoBytes(bundle.photos);
    } catch (e) {
      debugPrint('[Portfolio] load error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _preloadPhotoBytes(List<GalleryItem> photos) async {
    for (final photo in photos) {
      if (_loadedPhotoBytes.containsKey(photo.id)) continue;

      final thumb = photo.thumbnailPath;
      final path = (thumb != null && thumb.isNotEmpty)
          ? thumb
          : photo.storagePath;

      if (path != null && path.isNotEmpty) {
        try {
          final bytes = await widget.controller
              .downloadMediaBytes(storagePath: path);
          if (mounted) {
            setState(() {
              _loadedPhotoBytes[photo.id] = bytes;
            });
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _handleSaveReview() async {
    if (_bundle == null) return;

    setState(() => _isSavingReview = true);
    try {
      final review = StudentSemesterReview(
        id: _bundle?.review?.id ?? '',
        homeschoolId: _bundle!.homeschool.id,
        termId: _selectedTermId,
        childId: _selectedChildId,
        teacherEvaluation: _teacherCommentCtrl.text.trim(),
        parentEvaluation: _parentCommentCtrl.text.trim(),
        studentReflection: _studentReflectionCtrl.text.trim(),
        attendanceNote: _attendanceNoteCtrl.text.trim(),
      );

      await widget.controller.saveSemesterReview(review);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('종합의견이 안전하게 저장되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingReview = false);
      }
    }
  }

  PortfolioExportOptions _currentOptions() {
    return PortfolioExportOptions(
      includeCover: _includeCover,
      includeStudentProfile: _includeStudentProfile,
      includeAttendance: _includeAttendance,
      includeCurriculum: _includeCurriculum,
      includeActivities: _includeActivities,
      includeComprehensiveReview: _includeComprehensiveReview,
      includePhotos: _includePhotos,
      selectedPhotoIds: _selectedPhotoIds,
      photoImageBytes: _loadedPhotoBytes,
      customTeacherEvaluation: _teacherCommentCtrl.text.trim().isNotEmpty
          ? _teacherCommentCtrl.text.trim()
          : null,
      customParentEvaluation: _parentCommentCtrl.text.trim().isNotEmpty
          ? _parentCommentCtrl.text.trim()
          : null,
      customStudentReflection: _studentReflectionCtrl.text.trim().isNotEmpty
          ? _studentReflectionCtrl.text.trim()
          : null,
      customAttendanceNote: _attendanceNoteCtrl.text.trim().isNotEmpty
          ? _attendanceNoteCtrl.text.trim()
          : null,
    );
  }

  Future<Uint8List> _generatePdfBytes() async {
    if (_bundle == null) return Uint8List(0);
    return PortfolioPdfBuilder.buildPdf(
      bundle: _bundle!,
      options: _currentOptions(),
    );
  }

  Future<void> _handleDownloadPdf() async {
    if (_bundle == null) return;

    final bytes = await _generatePdfBytes();
    final filename =
        '${_bundle!.child.name}_${_bundle!.term.name}_학습포트폴리오.pdf';

    final helper = createDownloadHelper();
    if (helper.isSupported) {
      helper.downloadBytes(
        bytes: bytes,
        filename: filename,
        mimeType: 'application/pdf',
      );
    } else {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$filename 파일 저장을 시작했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isWide = media.size.width > 800;
    final dialogWidth = isWide ? 1040.0 : media.size.width * 0.95;
    final dialogHeight = isWide ? 820.0 : media.size.height * 0.92;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: NestColors.creamyWhite,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // 다이얼로그 헤더
            _buildDialogHeader(context),

            // 탭바
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: NestColors.dustyRose,
                labelColor: NestColors.deepWood,
                unselectedLabelColor:
                    NestColors.deepWood.withValues(alpha: 0.54),
                tabs: const [
                  Tab(icon: Icon(Icons.auto_stories), text: '성장 바인더'),
                  Tab(icon: Icon(Icons.tune), text: '포트폴리오 구성 & 작성'),
                  Tab(icon: Icon(Icons.picture_as_pdf), text: 'PDF 미리보기 & 내보내기'),
                ],
              ),
            ),

            // 내용
            Expanded(
              child: _isLoading
                  ? const Center(child: NestSkeletonCard())
                  : _bundle == null
                      ? const Center(child: Text('학기 또는 학생 정보를 찾을 수 없습니다.'))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            PortfolioBinderView(
                              bundle: _bundle!,
                              photoBytes: _loadedPhotoBytes,
                              onExportPdf: _handleDownloadPdf,
                              onEditConfig: () => _tabController.animateTo(1),
                            ),
                            _buildConfigTab(isWide),
                            _buildPreviewTab(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: NestColors.roseMist)),
      ),
      child: Row(
        children: [
          const Nest3dIcon.portfolio(
            size: 38,
            floating: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '학기별 학습 포트폴리오 생성',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: NestColors.deepWood,
                      ),
                ),
                Text(
                  '한국 학교 제출 및 소장용 생활기록부 & 성장 포트폴리오 PDF',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.65),
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '닫기',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigTab(bool isWide) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 1. 학기 및 학생 선택 카드
        _buildSelectionCard(),
        const SizedBox(height: 16),

        // 2. 포함 섹션 체크리스트
        _buildSectionTogglesCard(),
        const SizedBox(height: 16),

        // 3. 종합의견 및 성찰 입력 카드
        _buildComprehensiveReviewCard(),
        const SizedBox(height: 16),

        // 4. 사진 선택 카드
        _buildPhotoSelectorCard(),
        const SizedBox(height: 24),

        // 하단 이동 버튼들
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _tabController.animateTo(0);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: NestColors.deepWood,
                  side: const BorderSide(color: NestColors.roseMist),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.auto_stories),
                label: const Text(
                  '성장 바인더 보기',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  _tabController.animateTo(2);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: NestColors.dustyRose,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text(
                  'PDF 미리보기 확인',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 18, color: NestColors.dustyRose),
              const SizedBox(width: 8),
              Text(
                '대상 학기 및 학생 선택',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: NestColors.deepWood,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // 학기 선택
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '학기',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTermId.isNotEmpty ? _selectedTermId : null,
                      isExpanded: true,
                      items: widget.controller.terms.map((term) {
                        return DropdownMenuItem(
                          value: term.id,
                          child: Text(term.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _selectedTermId) {
                          setState(() => _selectedTermId = val);
                          _loadData();
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // 학생 선택
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '학생(자녀)',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value:
                          _selectedChildId.isNotEmpty ? _selectedChildId : null,
                      isExpanded: true,
                      items: widget.controller.children.map((child) {
                        return DropdownMenuItem(
                          value: child.id,
                          child: Row(
                            children: [
                              EntityAvatar(label: child.name, size: 20),
                              const SizedBox(width: 8),
                              Text(child.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _selectedChildId) {
                          setState(() => _selectedChildId = val);
                          _loadData();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTogglesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist, size: 18, color: NestColors.dustyRose),
              const SizedBox(width: 8),
              Text(
                '포함할 포트폴리오 항목',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: NestColors.deepWood,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('표지'),
                selected: _includeCover,
                onSelected: (v) => setState(() => _includeCover = v),
              ),
              FilterChip(
                label: const Text('인적·학적 사항'),
                selected: _includeStudentProfile,
                onSelected: (v) => setState(() => _includeStudentProfile = v),
              ),
              FilterChip(
                label: const Text('출결 상황 총괄'),
                selected: _includeAttendance,
                onSelected: (v) => setState(() => _includeAttendance = v),
              ),
              FilterChip(
                label: const Text('교과학습 발달상황'),
                selected: _includeCurriculum,
                onSelected: (v) => setState(() => _includeCurriculum = v),
              ),
              FilterChip(
                label: const Text('체험활동 및 자율학습'),
                selected: _includeActivities,
                onSelected: (v) => setState(() => _includeActivities = v),
              ),
              FilterChip(
                label: const Text('행동특성 및 종합의견'),
                selected: _includeComprehensiveReview,
                onSelected: (v) =>
                    setState(() => _includeComprehensiveReview = v),
              ),
              FilterChip(
                label: const Text('활동 사진 갤러리'),
                selected: _includePhotos,
                onSelected: (v) => setState(() => _includePhotos = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComprehensiveReviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.rate_review_outlined,
                      size: 18, color: NestColors.dustyRose),
                  const SizedBox(width: 8),
                  Text(
                    '한 학기 종합의견 및 성찰',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: NestColors.deepWood,
                        ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _isSavingReview ? null : _handleSaveReview,
                icon: _isSavingReview
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: const Text('의견 저장'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _teacherCommentCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '담임(지도) 교사 종합의견',
              hintText:
                  '수업 태도, 대인관계, 성취도, 발전된 점 등 종합 평가 (미입력 시 추천 문안 자동 적용)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _parentCommentCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '학부모 가정학습 관찰 총평',
              hintText:
                  '가정 내 자율 학습, 독서 습관, 생활 태도 및 인성 성장 소견',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _studentReflectionCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '학생 본인 성찰 소감문',
              hintText:
                  '한 학기 동안 성장한 점, 기억에 남는 배움, 앞으로의 다짐',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _attendanceNoteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '출결 특기사항 (선택)',
              hintText:
                  '출석 인정 사유, 장기 현장체험학습 등 공식 소명 특기사항',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSelectorCard() {
    final photos = _bundle?.photos ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.photo_library_outlined,
                      size: 18, color: NestColors.dustyRose),
                  const SizedBox(width: 8),
                  Text(
                    '포트폴리오 수록 사진 (${_selectedPhotoIds.length}/${photos.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: NestColors.deepWood,
                        ),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedPhotoIds.clear();
                        for (final p in photos) {
                          _selectedPhotoIds.add(p.id);
                        }
                      });
                    },
                    child: const Text('전체 선택'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedPhotoIds.clear());
                    },
                    child: const Text('선택 해제'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (photos.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: Text(
                '해당 학기에 등록된 앨범 사진이 없습니다.',
                style: TextStyle(
                  color: NestColors.deepWood.withValues(alpha: 0.6),
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  final isSelected = _selectedPhotoIds.contains(photo.id);
                  final bytes = _loadedPhotoBytes[photo.id];

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedPhotoIds.remove(photo.id);
                        } else {
                          _selectedPhotoIds.add(photo.id);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? NestColors.dustyRose
                                  : NestColors.roseMist,
                              width: isSelected ? 2.5 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: bytes != null
                              ? Image.memory(bytes, fit: BoxFit.cover)
                              : Container(
                                  color: NestColors.roseMist,
                                  child: const Center(
                                    child: Icon(Icons.image,
                                        color: NestColors.dustyRose),
                                  ),
                                ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? NestColors.dustyRose
                                  : Colors.white70,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              isSelected ? Icons.check : Icons.circle_outlined,
                              size: 16,
                              color: isSelected ? Colors.white : Colors.black45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewTab() {
    return Column(
      children: [
        // 상단 다운로드/인쇄 바
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_bundle?.child.name ?? "학생"} · ${_bundle?.term.name ?? "학기"}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _handleDownloadPdf,
                    style: FilledButton.styleFrom(
                      backgroundColor: NestColors.dustyRose,
                    ),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('PDF 파일 저장'),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 실시간 PDF 뷰어
        Expanded(
          child: PdfPreview(
            build: (format) => _generatePdfBytes(),
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            pdfFileName:
                '${_bundle?.child.name}_${_bundle?.term.name}_학습포트폴리오.pdf',
            actions: [
              PdfPreviewAction(
                icon: const Icon(Icons.download),
                onPressed: (ctx, build, pageFormat) async {
                  await _handleDownloadPdf();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
