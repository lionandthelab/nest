import 'package:flutter/material.dart';

import '../../../models/nest_models.dart';
import '../../nest_theme.dart';
import '../../widgets/nest_motion.dart';

/// 그리드 타일이 실제로 요청할 픽셀 폭.
///
/// 타일은 180pt 안팎이고 DPR 2를 감안하면 360px이면 충분하다. 이 값을
/// [Image.network]의 `cacheWidth`로 넘겨 디코딩된 비트맵을 360x360x4 ≈ 0.5MB로
/// 묶는다. 넘기지 않으면 4000x3000 원본이 48MB짜리 ARGB로 풀려, Flutter 이미지
/// 캐시(기본 100MiB)가 사진 두 장마다 비워진다.
const int kAlbumTileCacheWidth = 360;

/// 앨범 격자·타임라인의 타일 한 칸.
class AlbumTile extends StatelessWidget {
  const AlbumTile({
    super.key,
    required this.item,
    required this.imageUrl,
    required this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
    this.borderRadius = BorderRadius.zero,
    this.showTitle = false,
  });

  final GalleryItem item;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;
  final BorderRadius borderRadius;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = nestReduceMotion(context);
    final title = item.title.trim();

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedScale(
                // 고른 칸이 살짝 줄어드는 건 사진첩의 공통 신호다. 체크 표시만
                // 붙이는 것보다 "덜어냈다"가 훨씬 빨리 읽힌다.
                scale: selected ? 0.88 : 1,
                duration: reduceMotion ? Duration.zero : NestMotion.fade,
                curve: NestMotion.appearCurve,
                child: AlbumTileImage(item: item, imageUrl: imageUrl),
              ),
              if (item.isVideo) const _VideoBadge(),
              if (showTitle && title.isNotEmpty) _TitleStrip(title: title),
              if (selecting)
                Positioned(
                  top: 6,
                  left: 6,
                  child: _SelectionDot(
                    selected: selected,
                    reduceMotion: reduceMotion,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 타일 이미지 하나. 커버·폴더 카드에서도 쓴다.
class AlbumTileImage extends StatelessWidget {
  const AlbumTileImage({
    super.key,
    required this.item,
    required this.imageUrl,
    this.cacheWidth = kAlbumTileCacheWidth,
  });

  final GalleryItem? item;
  final String? imageUrl;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final isVideo = item?.isVideo ?? false;

    if (url == null || url.isEmpty) {
      return AlbumTilePlaceholder(isVideo: isVideo);
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      // 180pt 칸에서 medium/high는 래스터 시간만 더 쓰고 눈에 띄는 차이가 없다.
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      // loadingBuilder는 청크마다 다시 빌드한다. 한 화면에 12칸이 동시에 받는
      // 상황에서는 그 자체가 프레임을 떨군다. frameBuilder는 한 번만 불린다.
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return AlbumTilePlaceholder(isVideo: isVideo, quiet: true);
      },
      errorBuilder: (_, _, _) => AlbumTilePlaceholder(isVideo: isVideo),
    );
  }
}

/// 이미지가 없거나 아직 도착하지 않았을 때의 자리. 회색 사각형 대신 앱의
/// 색으로 채워 그리드가 로딩 중에도 무너져 보이지 않게 한다.
class AlbumTilePlaceholder extends StatelessWidget {
  const AlbumTilePlaceholder({
    super.key,
    this.isVideo = false,
    this.quiet = false,
  });

  final bool isVideo;

  /// 로딩 중(아직 실패가 아님)이면 아이콘 없이 배경만 둔다.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isVideo
              ? [
                  NestColors.mutedSage.withValues(alpha: 0.28),
                  NestColors.mutedSage.withValues(alpha: 0.10),
                ]
              : [
                  NestColors.roseMist.withValues(alpha: 0.36),
                  NestColors.dustyRose.withValues(alpha: 0.12),
                ],
        ),
      ),
      child: quiet
          ? const SizedBox.expand()
          : Center(
              child: Icon(
                isVideo ? Icons.play_circle_outline : Icons.photo_outlined,
                size: 28,
                color: NestColors.deepWood.withValues(alpha: 0.35),
              ),
            ),
    );
  }
}

class _VideoBadge extends StatelessWidget {
  const _VideoBadge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.videocam, size: 14, color: Colors.white),
      ),
    );
  }
}

class _TitleStrip extends StatelessWidget {
  const _TitleStrip({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 16, 6, 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
          ),
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected, required this.reduceMotion});

  final bool selected;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : NestMotion.fade,
      curve: NestMotion.appearCurve,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? NestColors.dustyRose : Colors.black.withValues(alpha: 0.18),
        border: Border.all(
          color: selected
              ? NestColors.dustyRose
              : Colors.white.withValues(alpha: 0.85),
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}

/// 업로드 중인 파일의 낙관적 타일. 네트워크를 기다리지 않고 로컬 썸네일을
/// 바로 그린다.
class AlbumUploadTile extends StatelessWidget {
  const AlbumUploadTile({
    super.key,
    required this.task,
    this.borderRadius = BorderRadius.zero,
  });

  final AlbumUploadTask task;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final bytes = task.thumbnailBytes;
    final failed = task.status == AlbumUploadStatus.failed;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(
                bytes,
                fit: BoxFit.cover,
                cacheWidth: kAlbumTileCacheWidth,
                filterQuality: FilterQuality.low,
              )
            else
              AlbumTilePlaceholder(isVideo: task.file.isVideo),
            ColoredBox(
              color: Colors.white.withValues(alpha: failed ? 0.24 : 0.46),
            ),
            Center(
              child: failed
                  ? Icon(
                      Icons.error_outline,
                      size: 24,
                      color: Theme.of(context).colorScheme.error,
                    )
                  : const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
