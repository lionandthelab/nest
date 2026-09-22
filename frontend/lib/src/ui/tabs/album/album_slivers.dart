import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/nest_models.dart';
import '../../../services/album_organizer.dart';
import '../../nest_theme.dart';
import '../../widgets/nest_motion.dart';
import 'album_tile.dart';

/// 앨범 본문을 그리는 데 필요한 것들. 인자가 열 개 넘게 늘어나는 걸 막으려고
/// 한 덩어리로 묶었다.
class AlbumSliverContext {
  const AlbumSliverContext({
    required this.width,
    required this.mode,
    required this.items,
    required this.uploads,
    required this.resolveUrl,
    required this.onOpen,
    required this.onToggleSelect,
    required this.selecting,
    required this.selectedIds,
    required this.classGroupNameOf,
  });

  /// 반드시 `LayoutBuilder`의 `constraints.maxWidth`. 데스크톱 셸의 왼쪽
  /// 레일이 220pt 가까이 먹어서, 화면 전체 폭으로 계산하면 늘 한 단계 빽빽해진다.
  final double width;
  final AlbumViewMode mode;
  final List<GalleryItem> items;
  final List<AlbumUploadTask> uploads;
  final String? Function(String? storagePath) resolveUrl;
  final void Function(GalleryItem item) onOpen;
  final void Function(GalleryItem item) onToggleSelect;
  final bool selecting;
  final Set<String> selectedIds;
  final String Function(String? classGroupId) classGroupNameOf;

  int get columns => AlbumOrganizer.gridColumnsFor(width, mode);

  String? urlFor(GalleryItem item) => resolveUrl(item.previewPath);
}

/// 격자 보기: 평평한 정사각 격자, 최신순.
List<Widget> buildAlbumGridSlivers(AlbumSliverContext ctx) {
  return [
    SliverPadding(
      padding: const EdgeInsets.all(2),
      sliver: _tileGrid(ctx, spacing: 2, radius: BorderRadius.zero),
    ),
  ];
}

/// 타임라인 보기: 날짜 머리글 + 성긴 격자.
List<Widget> buildAlbumTimelineSlivers(AlbumSliverContext ctx) {
  final sections = AlbumOrganizer.groupByDate(ctx.items);
  final uploads = ctx.uploads;

  return [
    if (uploads.isNotEmpty)
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: ctx.columns,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => AlbumUploadTile(
              task: uploads[index],
              borderRadius: BorderRadius.circular(12),
            ),
            childCount: uploads.length,
          ),
        ),
      ),
    for (var i = 0; i < sections.length; i++)
      SliverMainAxisGroup(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _AlbumDateHeaderDelegate(section: sections[i]),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            sliver: _tileGrid(
              ctx,
              spacing: 6,
              radius: BorderRadius.circular(12),
              items: sections[i].items,
              showTitle: true,
              includeUploads: false,
            ),
          ),
        ],
      ),
  ];
}

/// 폴더 보기: 학기·수업·반 카드.
List<Widget> buildAlbumFolderSlivers({
  required AlbumSliverContext ctx,
  required List<AlbumSummary> summaries,
  required void Function(AlbumSummary summary) onOpenAlbum,
}) {
  return [
    SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ctx.columns,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.82,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final summary = summaries[index];
          return NestAppear(
            index: index,
            child: _AlbumFolderCard(
              summary: summary,
              coverUrl: ctx.resolveUrl(summary.coverPath),
              onTap: () => onOpenAlbum(summary),
            ),
          );
        }, childCount: summaries.length),
      ),
    ),
  ];
}

/// 크게 보기: 한 장씩 큰 카드 + 메타데이터.
List<Widget> buildAlbumLargeSlivers(AlbumSliverContext ctx) {
  final columns = ctx.columns;

  return [
    SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          // 4:3 미리보기 + 본문 두세 줄이 들어가는 비율.
          childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = ctx.items[index];
          return _AlbumLargeCard(
            item: item,
            imageUrl: ctx.urlFor(item),
            classGroupName: ctx.classGroupNameOf(item.classGroupId),
            selecting: ctx.selecting,
            selected: ctx.selectedIds.contains(item.id),
            onTap: () => ctx.selecting
                ? ctx.onToggleSelect(item)
                : ctx.onOpen(item),
            onLongPress: () => ctx.onToggleSelect(item),
          );
        }, childCount: ctx.items.length),
      ),
    ),
  ];
}

SliverGrid _tileGrid(
  AlbumSliverContext ctx, {
  required double spacing,
  required BorderRadius radius,
  List<GalleryItem>? items,
  bool showTitle = false,
  bool includeUploads = true,
}) {
  final tiles = items ?? ctx.items;
  final uploads = includeUploads ? ctx.uploads : const <AlbumUploadTask>[];

  return SliverGrid(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: ctx.columns,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
    ),
    delegate: SliverChildBuilderDelegate(
      (context, index) {
        if (index < uploads.length) {
          return AlbumUploadTile(
            task: uploads[index],
            borderRadius: radius,
          );
        }

        final item = tiles[index - uploads.length];
        return AlbumTile(
          item: item,
          imageUrl: ctx.urlFor(item),
          borderRadius: radius,
          showTitle: showTitle,
          selecting: ctx.selecting,
          selected: ctx.selectedIds.contains(item.id),
          onTap: () =>
              ctx.selecting ? ctx.onToggleSelect(item) : ctx.onOpen(item),
          onLongPress: () => ctx.onToggleSelect(item),
        );
      },
      childCount: tiles.length + uploads.length,
      // 타일은 상태가 없다. KeepAlive는 요소를 붙잡아 둘 뿐 디코딩된 픽셀을
      // 지켜 주지 않아서, 메모리만 쓰고 얻는 게 없다.
      addAutomaticKeepAlives: false,
    ),
  );
}

class _AlbumDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  _AlbumDateHeaderDelegate({required this.section});

  final AlbumDateSection section;

  static final _format = DateFormat('M월 d일 (E)', 'ko');

  @override
  double get minExtent => 40;

  @override
  double get maxExtent => 40;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final date = section.date;
    final label = date == null ? '촬영일 미정' : _format.format(date);

    return Container(
      color: NestColors.creamyWhite.withValues(alpha: 0.94),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: NestColors.deepWood,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${section.items.length}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_AlbumDateHeaderDelegate oldDelegate) {
    return oldDelegate.section != section;
  }
}

class _AlbumFolderCard extends StatelessWidget {
  const _AlbumFolderCard({
    required this.summary,
    required this.coverUrl,
    required this.onTap,
  });

  final AlbumSummary summary;
  final String? coverUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <String>[
      if (summary.photoCount > 0) '사진 ${summary.photoCount}',
      if (summary.videoCount > 0) '영상 ${summary.videoCount}',
    ];

    return NestPressable(
      onPressed: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NestColors.roseMist),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: AlbumTileImage(
                  item: null,
                  imageUrl: coverUrl,
                  cacheWidth: 480,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    summary.scopeName.isEmpty ? '이름 없음' : summary.scopeName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    counts.isEmpty ? '비어 있음' : counts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.72),
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

class _AlbumLargeCard extends StatelessWidget {
  const _AlbumLargeCard({
    required this.item,
    required this.imageUrl,
    required this.classGroupName,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final GalleryItem item;
  final String? imageUrl;
  final String classGroupName;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = item.title.trim().isEmpty ? '제목 없음' : item.title.trim();
    final description = item.description.trim();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: AlbumTile(
                  item: item,
                  imageUrl: imageUrl,
                  selecting: selecting,
                  selected: selected,
                  onTap: onTap,
                  onLongPress: onLongPress,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      AlbumMetaChip(
                        icon: item.isVideo
                            ? Icons.videocam_outlined
                            : Icons.image_outlined,
                        label: item.isVideo ? '영상' : '사진',
                      ),
                      AlbumMetaChip(
                        icon: Icons.groups_2_outlined,
                        label: classGroupName,
                      ),
                      if (item.capturedAt != null)
                        AlbumMetaChip(
                          icon: Icons.event_outlined,
                          label: DateFormat(
                            'yyyy년 M월 d일',
                          ).format(item.capturedAt!),
                        ),
                      if ((item.driveWebViewLink ?? '').isNotEmpty)
                        const AlbumMetaChip(
                          icon: Icons.cloud_done_outlined,
                          label: 'Drive 저장됨',
                        ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.85),
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 앨범 곳곳에서 쓰는 메타 알약. 공지 탭의 _MetaChip과 같은 치수를 쓴다.
class AlbumMetaChip extends StatelessWidget {
  const AlbumMetaChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: NestColors.creamyWhite,
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: NestColors.clay),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: NestColors.deepWood.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}
