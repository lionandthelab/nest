import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/nest_models.dart';
import '../../../state/nest_controller.dart';
import 'album_messages.dart';
import 'album_tile.dart';

/// 사진 한 장을 크게 보는 화면. 좌우로 넘기고, 확대하고, 내려받는다.
class AlbumViewerPage extends StatefulWidget {
  const AlbumViewerPage({
    super.key,
    required this.controller,
    required this.items,
    required this.initialIndex,
  });

  final NestController controller;
  final List<GalleryItem> items;
  final int initialIndex;

  @override
  State<AlbumViewerPage> createState() => _AlbumViewerPageState();
}

class _AlbumViewerPageState extends State<AlbumViewerPage> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _busy = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  GalleryItem get _current => widget.items[_index];

  Future<void> _download() async {
    final controller = widget.controller;
    setState(() => _busy = true);

    // 뷰어의 내려받기는 지금 보고 있는 한 장만 대상으로 한다. 컨트롤러의
    // 선택 집합을 잠시 이 한 장으로 바꿔 같은 경로를 태운다.
    final restore = Set<String>.from(controller.albumSelectedIds);
    controller.albumSelectedIds
      ..clear()
      ..add(_current.id);

    final outcome = await controller.downloadAlbumSelection();

    controller.albumSelectedIds
      ..clear()
      ..addAll(restore);

    if (!mounted) return;
    setState(() => _busy = false);
    _toast(albumDownloadMessage(outcome));
  }

  Future<void> _openInDrive() async {
    final link = _current.driveWebViewLink;
    if (link == null || link.isEmpty) return;
    final opened = await launchUrl(
      Uri.parse(link),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _toast('파일을 열지 못했습니다.');
    }
  }

  Future<void> _openVideo() async {
    final url = widget.controller.mediaPublicUrl(_current.storagePath);
    if (url == null) return;
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _toast('파일을 열지 못했습니다.');
    }
  }

  void _toast(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;
    final title = item.title.trim().isEmpty ? '제목 없음' : item.title.trim();
    final date = item.capturedAt;
    final dateLabel = date == null
        ? '촬영일 미정'
        : DateFormat('yyyy년 M월 d일').format(date);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: '닫기',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: '다운로드',
            onPressed: _busy ? null : _download,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded),
          ),
          if ((item.driveWebViewLink ?? '').isNotEmpty)
            IconButton(
              tooltip: 'Drive에서 열기',
              onPressed: _openInDrive,
              icon: const Icon(Icons.open_in_new_rounded),
            ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              final pageItem = widget.items[index];
              return _ViewerPage(
                item: pageItem,
                // 뷰어는 원본을 쓴다. 그리드와 달리 확대해서 보는 화면이다.
                imageUrl: widget.controller.mediaPublicUrl(
                  pageItem.storagePath,
                ),
                onOpenVideo: _openVideo,
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _InfoPanel(
              title: title,
              meta: [
                item.isVideo ? '영상' : '사진',
                dateLabel,
                '${_index + 1} / ${widget.items.length}',
              ].join(' · '),
              description: item.description.trim(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerPage extends StatelessWidget {
  const _ViewerPage({
    required this.item,
    required this.imageUrl,
    required this.onOpenVideo,
  });

  final GalleryItem item;
  final String? imageUrl;
  final VoidCallback onOpenVideo;

  @override
  Widget build(BuildContext context) {
    if (item.isVideo) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.play_circle_outline,
              size: 72,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOpenVideo,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('영상 열기'),
            ),
          ],
        ),
      );
    }

    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return const Center(child: AlbumTilePlaceholder());
    }

    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: Colors.white38,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.title,
    required this.meta,
    required this.description,
  });

  final String title;
  final String meta;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: Colors.black.withValues(alpha: 0.45),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meta,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
