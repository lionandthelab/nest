import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/nest_models.dart';
import '../../../services/album_organizer.dart';
import '../../../services/nest_cache.dart';
import '../../../state/nest_controller.dart';
import '../../nest_theme.dart';
import '../../widgets/nest_3d_icon.dart';
import '../../widgets/nest_empty_state.dart';
import '../../widgets/nest_motion.dart';
import '../../widgets/nest_refresh.dart';
import '../../widgets/nest_sheet.dart';
import '../../widgets/nest_skeleton.dart';
import 'album_drive_connect_sheet.dart';
import 'album_messages.dart';
import 'album_selection_bar.dart';
import 'album_slivers.dart';
import 'album_upload_sheet.dart';
import 'album_view_mode.dart';
import 'album_viewer_page.dart';

/// 앨범을 독립 화면으로 여는 래퍼(학부모 홈의 '앨범 열기' 등).
class AlbumPage extends StatelessWidget {
  const AlbumPage({super.key, required this.controller, this.title = '앨범'});

  final NestController controller;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: AlbumTab(controller: controller)),
    );
  }
}

/// 학기·수업별 사진첩.
class AlbumTab extends StatefulWidget {
  const AlbumTab({
    super.key,
    required this.controller,
    this.onSelectTerm,
    this.initialMode,
  });

  final NestController controller;

  /// 폴더 뷰에서 다른 학기 카드를 열 때 셸의 학기 선택을 함께 옮긴다.
  final Future<void> Function(String? termId)? onSelectTerm;

  /// 초기 표시 모드 (지정하지 않으면 캐시된 모드 또는 기본 grid).
  final AlbumViewMode? initialMode;

  @override
  State<AlbumTab> createState() => _AlbumTabState();
}

class _AlbumTabState extends State<AlbumTab> {
  final _scrollController = ScrollController();

  AlbumViewMode _mode = AlbumViewMode.grid;
  AlbumSummary? _openAlbum;
  bool _downloading = false;

  /// 바닥에서 이만큼 남았을 때 다음 페이지를 부른다. 180pt 타일 기준 대여섯
  /// 줄 여유라, 사용자가 로딩을 의식하지 못한 채로 이어진다.
  static const double _loadMoreRunway = 1200;

  @override
  void initState() {
    super.initState();
    if (widget.initialMode != null) {
      _mode = widget.initialMode!;
    } else {
      _restoreViewMode();
    }
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(widget.controller.ensureAlbumLoaded());
      unawaited(widget.controller.loadAlbumSummaries());
      unawaited(widget.controller.loadAlbumFolders());

      // 연결 상태는 이 탭이 직접 챙긴다. 모든 구성원이 드라이브 연동에 따른
      // 앨범 활성화 여부를 즉시 파악할 수 있도록 항상 상태를 조회한다.
      unawaited(widget.controller.loadDriveIntegration());
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _restoreViewMode() {
    final userId = widget.controller.user?.id;
    if (userId == null) return;
    final saved = NestCache.loadAlbumViewMode(userId: userId);
    if (saved != null) {
      _mode = albumViewModeFromKey(saved);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > _loadMoreRunway) return;
    unawaited(widget.controller.loadAlbumPage());
  }

  Future<void> _setMode(AlbumViewMode mode) async {
    setState(() => _mode = mode);

    final userId = widget.controller.user?.id;
    if (userId != null) {
      unawaited(
        NestCache.saveAlbumViewMode(userId: userId, mode: mode.storageKey),
      );
    }

    if (mode == AlbumViewMode.folder) {
      unawaited(widget.controller.loadAlbumSummaries());
    }
  }

  Future<void> _pickMode() async {
    final picked = await showAlbumViewModeSheet(
      context: context,
      current: _mode,
    );
    if (picked != null && mounted) {
      await _setMode(picked);
    }
  }

  Future<void> _openDriveSetup() async {
    await showDriveConnectSheet(
      context: context,
      controller: widget.controller,
    );
  }

  Future<void> _refresh() async {
    await widget.controller.loadAlbumPage(reset: true);
    unawaited(widget.controller.loadAlbumSummaries());
    unawaited(widget.controller.loadAlbumFolders());
  }

  Future<void> _openUploadSheet() async {
    final controller = widget.controller;
    // 원본은 관리자 Drive로 간다. 관리자가 아직 연결하지 않았다면 사진을 올리기
    // 전이 알려 줄 마지막 기회다 — 연결 없이 올리면 Nest 용량에 쌓인다.
    if (!controller.isAlbumActive) {
      if (controller.isAdminLike) {
        final connected = await showDriveConnectSheet(
          context: context,
          controller: controller,
        );
        if (!mounted || connected != true) return;
      } else {
        _toast('관리자가 Google Drive를 연동해야 사진을 올릴 수 있습니다.');
        return;
      }
    }

    final draft = await showAlbumUploadSheet(
      context: context,
      controller: widget.controller,
    );
    if (draft == null || !mounted) return;

    try {
      await widget.controller.uploadAlbumMedia(
        files: draft.files,
        classGroupId: draft.classGroupId,
        courseId: draft.courseId,
        albumFolderId: draft.albumFolderId,
        capturedAt: draft.capturedAt,
        description: draft.description,
      );
      if (mounted) {
        NestHaptics.success();
        _toast(widget.controller.statusMessage);
      }
    } on StateError catch (error) {
      _toast(error.message);
    } catch (_) {
      _toast(widget.controller.statusMessage);
    }
  }

  void _openViewer(GalleryItem item) {
    final items = widget.controller.galleryItems;
    final index = items.indexWhere((candidate) => candidate.id == item.id);
    if (index < 0) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AlbumViewerPage(
          controller: widget.controller,
          items: items,
          initialIndex: index,
        ),
      ),
    );
  }

  void _toggleSelect(GalleryItem item) {
    final accepted = widget.controller.toggleAlbumSelection(item.id);
    if (!accepted) {
      _toast(
        '한 번에 최대 ${NestController.albumSelectionLimit}장까지 선택할 수 있습니다.',
      );
      return;
    }
    NestHaptics.selection();
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    final outcome = await widget.controller.downloadAlbumSelection();
    if (!mounted) return;
    setState(() => _downloading = false);
    _toast(albumDownloadMessage(outcome));
  }

  Future<void> _delete() async {
    final count = widget.controller.albumSelectedIds.length;
    final confirmed = await showNestConfirm(
      context: context,
      title: '사진 삭제',
      message: '선택한 $count장을 삭제할까요?\n삭제하면 되돌릴 수 없습니다.',
      confirmLabel: '삭제',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    try {
      await widget.controller.deleteAlbumSelection();
    } catch (_) {
      // 상태 메시지로 이미 안내된다.
    }
    if (mounted) _toast(widget.controller.statusMessage);
  }

  Future<void> _openAlbumCard(AlbumSummary summary) async {
    final controller = widget.controller;

    if (summary.isTerm) {
      if (summary.scopeId != controller.selectedTermId) {
        await widget.onSelectTerm?.call(summary.scopeId);
      }
      setState(() => _openAlbum = summary);
      await _setMode(AlbumViewMode.timeline);
      return;
    }

    setState(() => _openAlbum = summary);
    if (summary.isFolder) {
      await controller.setAlbumFolderFilter(summary.scopeId);
    } else if (summary.isCourse) {
      await controller.setAlbumCourseFilter(summary.scopeId);
    } else {
      await controller.setAlbumClassGroupFilter(summary.scopeId);
    }
    await _setMode(AlbumViewMode.timeline);
  }

  Future<void> _closeAlbumCard() async {
    setState(() => _openAlbum = null);
    await widget.controller.clearAlbumFilters();
    await _setMode(AlbumViewMode.folder);
  }

  void _toast(String message) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final selecting = controller.isAlbumSelecting;

        return PopScope(
          canPop: _openAlbum == null && !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (selecting) {
              controller.clearAlbumSelection();
            } else if (_openAlbum != null) {
              unawaited(_closeAlbumCard());
            }
          },
          child: Scaffold(
            backgroundColor: NestColors.creamyWhite,
            floatingActionButton: _buildFab(controller, selecting),
            bottomNavigationBar: selecting
                ? AlbumSelectionBar(
                    selectedCount: controller.albumSelectedIds.length,
                    allSelected:
                        controller.albumSelectedIds.length ==
                        controller.galleryItems.length,
                    onSelectAll: controller.selectVisibleAlbumItems,
                    onClear: controller.clearAlbumSelection,
                    onDownload: _download,
                    onDelete: controller.canUploadMedia ? _delete : null,
                    busy: _downloading || controller.isBusy,
                  )
                : null,
            body: LayoutBuilder(
              builder: (context, constraints) {
                return NestRefreshable(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    // 기본 250은 이미지 그리드에 너무 빠듯하다. 세 줄쯤 미리
                    // 지어 두면 빠르게 내릴 때 빈 칸이 스쳐 지나가지 않는다.
                    cacheExtent: 600,
                    slivers: [
                      if (controller.isAlbumActive)
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _AlbumHeaderDelegate(
                            controller: controller,
                            mode: _mode,
                            openAlbum: _openAlbum,
                            onPickMode: _pickMode,
                            onCloseAlbum: _closeAlbumCard,
                            onOpenDriveSetup: _openDriveSetup,
                          ),
                        ),
                      ..._buildBody(controller, constraints.maxWidth),
                      if (controller.isAlbumActive)
                        SliverToBoxAdapter(
                          child: _buildFooter(controller, selecting),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget? _buildFab(NestController controller, bool selecting) {
    if (!controller.canUploadMedia || !controller.isAlbumActive) return null;

    return AnimatedScale(
      scale: selecting ? 0 : 1,
      duration: nestReduceMotion(context) ? Duration.zero : NestMotion.fade,
      curve: NestMotion.appearCurve,
      child: FloatingActionButton(
        onPressed: selecting ? null : _openUploadSheet,
        backgroundColor: NestColors.dustyRose,
        tooltip: '사진 올리기',
        child: const Icon(Icons.add_photo_alternate, color: Colors.white),
      ),
    );
  }

  List<Widget> _buildBody(NestController controller, double width) {
    if (!controller.isAlbumActive) {
      return [_buildActivationGate(controller, width)];
    }

    if (controller.albumLoading && controller.galleryItems.isEmpty) {
      return [_buildSkeleton(width)];
    }

    if (controller.albumErrorMessage.isNotEmpty &&
        controller.galleryItems.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: NestErrorState(
            message: '사진을 불러오지 못했습니다',
            detail: '네트워크 상태를 확인하고 다시 시도해 주세요.',
            onRetry: () => unawaited(_refresh()),
          ),
        ),
      ];
    }

    if (_mode == AlbumViewMode.folder) {
      if (controller.albumSummaries.isEmpty) {
        return [_buildEmpty(controller, folder: true)];
      }
      return buildAlbumFolderSlivers(
        ctx: _sliverContext(controller, width),
        summaries: controller.albumSummaries,
        onOpenAlbum: (summary) => unawaited(_openAlbumCard(summary)),
      );
    }

    if (controller.galleryItems.isEmpty && controller.albumUploads.isEmpty) {
      return [_buildEmpty(controller)];
    }

    final ctx = _sliverContext(controller, width);
    return switch (_mode) {
      AlbumViewMode.grid => buildAlbumGridSlivers(ctx),
      AlbumViewMode.timeline => buildAlbumTimelineSlivers(ctx),
      AlbumViewMode.large => buildAlbumLargeSlivers(ctx),
      AlbumViewMode.folder => const [],
    };
  }

  AlbumSliverContext _sliverContext(NestController controller, double width) {
    return AlbumSliverContext(
      width: width,
      mode: _mode,
      items: controller.galleryItems,
      uploads: controller.albumUploads,
      resolveUrl: controller.mediaPublicUrl,
      onOpen: _openViewer,
      onToggleSelect: _toggleSelect,
      selecting: controller.isAlbumSelecting,
      selectedIds: controller.albumSelectedIds,
      classGroupNameOf: controller.findClassGroupName,
    );
  }

  Widget _buildSkeleton(double width) {
    final columns = AlbumOrganizer.gridColumnsFor(width, _mode);
    return SliverPadding(
      padding: const EdgeInsets.all(2),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const NestSkeleton(
            height: double.infinity,
            borderRadius: 4,
          ),
          childCount: columns * 3,
        ),
      ),
    );
  }

  Widget _buildActivationGate(NestController controller, double width) {
    final isAdmin = controller.isAdminLike;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: isAdmin
                ? _AdminAlbumActivationCard(
                    onConnect: _openDriveSetup,
                  )
                : const _MemberAlbumWaitingCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(NestController controller, {bool folder = false}) {
    if (folder) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: NestEmptyState(
          icon: Icons.photo_album_outlined,
          title: '아직 앨범이 없습니다',
          subtitle: '사진을 올리면 학기와 수업별로 자동으로 묶입니다.',
          actionLabel: controller.canUploadMedia ? '사진 올리기' : null,
          onAction: controller.canUploadMedia
              ? () => unawaited(_openUploadSheet())
              : null,
        ),
      );
    }

    final filtered =
        controller.albumClassGroupId != null ||
        controller.albumCourseId != null ||
        controller.albumFolderId != null ||
        controller.albumMediaType != null;

    if (filtered) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: NestEmptyState(
          icon: Icons.filter_alt_off_outlined,
          title: '이 조건에는 사진이 없습니다',
          subtitle: '다른 수업이나 반을 골라보세요.',
          actionLabel: '필터 지우기',
          onAction: () => unawaited(controller.clearAlbumFilters()),
          compact: true,
        ),
      );
    }

    return SliverFillRemaining(
      hasScrollBody: false,
      child: controller.canUploadMedia
          ? NestEmptyState(
              icon: Icons.photo_library_outlined,
              title: '아직 올린 사진이 없습니다',
              subtitle: '수업 사진이나 영상을 올려 아이들의 한 학기를 남겨보세요.',
              actionLabel: '사진 올리기',
              onAction: () => unawaited(_openUploadSheet()),
            )
          : const NestEmptyState(
              icon: Icons.photo_library_outlined,
              title: '아직 올라온 사진이 없습니다',
              subtitle: '선생님이 사진을 올리면 여기에 모입니다.',
            ),
    );
  }

  Widget _buildFooter(NestController controller, bool selecting) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        // FAB와 선택 바에 마지막 줄이 가리지 않도록 아래를 비워 둔다.
        selecting ? 24 : 96,
      ),
      child: Center(
        child: controller.albumLoadingMore
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : (!controller.albumHasMore && controller.galleryItems.isNotEmpty)
            ? Text(
                '사진 ${controller.galleryItems.length}장을 모두 봤습니다',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.5),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _AlbumHeaderDelegate extends SliverPersistentHeaderDelegate {
  _AlbumHeaderDelegate({
    required this.controller,
    required this.mode,
    required this.openAlbum,
    required this.onPickMode,
    required this.onCloseAlbum,
    required this.onOpenDriveSetup,
  });

  final NestController controller;
  final AlbumViewMode mode;
  final AlbumSummary? openAlbum;
  final VoidCallback onPickMode;
  final Future<void> Function() onCloseAlbum;
  final VoidCallback onOpenDriveSetup;

  @override
  double get minExtent => 92;

  @override
  double get maxExtent => 92;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final summary = openAlbum;
    final driveConnected = controller.driveIntegration?.isConnected ?? false;

    // Container가 아니라 DecoratedBox를 쓴다. Container는 테두리 두께만큼
    // 자식에 패딩을 넣어서, 선언한 maxExtent보다 1pt 더 커지고 슬리버가
    // "layoutExtent가 paintExtent를 넘는다"며 레이아웃을 거부한다.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NestColors.creamyWhite,
        border: Border(
          bottom: BorderSide(
            color: NestColors.roseMist.withValues(alpha: 0.9),
          ),
        ),
      ),
      child: SizedBox(
        height: maxExtent,
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: 46,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 4, 0),
                    child: Row(
                      children: [
                        if (summary != null)
                          Flexible(
                            child: TextButton.icon(
                              onPressed: () => unawaited(onCloseAlbum()),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                              ),
                              label: Text(
                                summary.scopeName.isEmpty
                                    ? '앨범 목록'
                                    : summary.scopeName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                        else
                          Expanded(child: _MetricRow(controller: controller)),
                        if (summary != null) const Spacer(),
                        if (controller.isAdminLike)
                          IconButton(
                            tooltip: '사진 저장 위치',
                            onPressed: onOpenDriveSetup,
                            icon: Icon(
                              driveConnected
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_off_outlined,
                              size: 20,
                              color: driveConnected
                                  ? NestColors.mutedSage
                                  : NestColors.deepWood.withValues(alpha: 0.5),
                            ),
                          ),
                        IconButton(
                          tooltip: '보기 방식',
                          onPressed: onPickMode,
                          icon: Icon(mode.icon, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _FilterRow(controller: controller, theme: theme),
                ),
              ],
            ),
            // 진행 바는 높이를 차지하지 않도록 겹쳐 둔다. 나타났다 사라질 때마다
            // 헤더 높이가 흔들리면 그 아래 격자가 통째로 다시 배치된다.
            if (controller.albumLoading || controller.isAlbumUploading)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_AlbumHeaderDelegate oldDelegate) => true;
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    final termSummary = controller.albumSummaries
        .where(
          (summary) =>
              summary.isTerm && summary.scopeId == controller.selectedTermId,
        )
        .firstOrNull;

    final photos =
        termSummary?.photoCount ??
        controller.galleryItems.where((item) => !item.isVideo).length;
    final videos =
        termSummary?.videoCount ??
        controller.galleryItems.where((item) => item.isVideo).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _metric(Icons.image_outlined, '사진 $photos'),
          const SizedBox(width: 6),
          _metric(Icons.videocam_outlined, '영상 $videos'),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 14),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.controller, required this.theme});

  final NestController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // 만들어진 모든 반·수업이 아니라, 사진이 실제로 들어 있는 것만 세운다.
    // 빈 태그가 줄줄이 늘어서면 정작 누를 게 뭔지 보이지 않는다.
    final folders = controller.albumFilterFolders;
    final groups = controller.albumFilterClassGroups;
    final courses = controller.albumFilterCourses;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Row(
        children: [
          _chip(
            label: '전체',
            selected:
                controller.albumClassGroupId == null &&
                controller.albumCourseId == null &&
                controller.albumFolderId == null &&
                controller.albumMediaType == null,
            onSelected: () => controller.clearAlbumFilters(),
          ),
          for (final folder in folders)
            _chip(
              label: folder.name,
              icon: Icons.folder_outlined,
              selected: controller.albumFolderId == folder.id,
              onSelected: () => controller.setAlbumFolderFilter(
                controller.albumFolderId == folder.id ? null : folder.id,
              ),
            ),
          for (final course in courses)
            _chip(
              label: course.name,
              icon: Icons.menu_book_outlined,
              selected: controller.albumCourseId == course.id,
              onSelected: () => controller.setAlbumCourseFilter(
                controller.albumCourseId == course.id ? null : course.id,
              ),
            ),
          for (final group in groups)
            _chip(
              label: group.name,
              icon: Icons.groups_outlined,
              selected: controller.albumClassGroupId == group.id,
              onSelected: () => controller.setAlbumClassGroupFilter(
                controller.albumClassGroupId == group.id ? null : group.id,
              ),
            ),
          const SizedBox(width: 6),
          _chip(
            label: '사진',
            selected: controller.albumMediaType == 'PHOTO',
            onSelected: () => controller.setAlbumMediaTypeFilter(
              controller.albumMediaType == 'PHOTO' ? null : 'PHOTO',
            ),
          ),
          _chip(
            label: '영상',
            selected: controller.albumMediaType == 'VIDEO',
            onSelected: () => controller.setAlbumMediaTypeFilter(
              controller.albumMediaType == 'VIDEO' ? null : 'VIDEO',
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required Future<void> Function() onSelected,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: 15),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        selected: selected,
        onSelected: (_) {
          NestHaptics.selection();
          unawaited(onSelected());
        },
      ),
    );
  }
}

class _AdminAlbumActivationCard extends StatelessWidget {
  const _AdminAlbumActivationCard({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: NestColors.roseMist.withValues(alpha: 0.9),
          width: 1.5,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Nest3dIcon.studyBooks(
              size: 76,
              floating: true,
            ),
            const SizedBox(height: 20),
            Text(
              '앨범을 시작하려면\nGoogle Drive를 연동해 주세요',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: NestColors.deepWood,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '홈스쿨 사진과 동영상을 관리자님의 Google Drive에 안전하고 무제한으로 보관합니다. 1회 연동 시 앨범 기능이 즉시 활성화됩니다.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NestColors.roseMist.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: NestColors.roseMist,
                ),
              ),
              child: const Column(
                children: [
                  _FeatureBenefitRow(
                    icon: Icons.cloud_done_rounded,
                    iconColor: NestColors.dustyRose,
                    title: '관리자 Drive 원본 보관',
                    subtitle: '용량 걱정 없이 고화질 원본 그대로 평생 안전 보관',
                  ),
                  SizedBox(height: 12),
                  _FeatureBenefitRow(
                    icon: Icons.auto_awesome_motion_rounded,
                    iconColor: NestColors.clay,
                    title: '학기·수업·날짜별 자동 정리',
                    subtitle: '올리기만 하면 Nest가 알아서 폴더를 만들고 분류',
                  ),
                  SizedBox(height: 12),
                  _FeatureBenefitRow(
                    icon: Icons.shield_rounded,
                    iconColor: NestColors.mutedSage,
                    title: '가족 및 구성원 실시간 안전 공유',
                    subtitle: '홈스쿨에 초대된 가족만 볼 수 있는 프라이빗 앨범',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: NestPressable(
                haptic: true,
                onPressed: onConnect,
                child: FilledButton.icon(
                  onPressed: onConnect,
                  style: FilledButton.styleFrom(
                    backgroundColor: NestColors.dustyRose,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    shadowColor: NestColors.dustyRose.withValues(alpha: 0.4),
                  ),
                  icon: const Icon(Icons.add_to_drive, size: 20),
                  label: const Text(
                    'Google Drive 연동하고 앨범 시작하기',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '관리자 계정 1회 연동으로 모든 가족이 앨범을 이용할 수 있습니다.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureBenefitRow extends StatelessWidget {
  const _FeatureBenefitRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: NestColors.deepWood,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberAlbumWaitingCard extends StatelessWidget {
  const _MemberAlbumWaitingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: NestColors.roseMist.withValues(alpha: 0.9),
          width: 1.5,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Nest3dIcon.emptyNest(
              size: 76,
              floating: true,
            ),
            const SizedBox(height: 20),
            Text(
              '앨범 준비 중',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: NestColors.deepWood,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '홈스쿨 관리자가 사진 보관용 Google Drive를 연동하면 앨범 기능이 활성화됩니다.\n관리자에게 앨범 활성화를 요청해 주세요.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: NestColors.pastelSky.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: NestColors.pastelSky.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: NestColors.clay,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '관리자가 Drive를 연동하면 모든 가족이 수업별 사진을 함께 확인하고 다운로드할 수 있어요.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

