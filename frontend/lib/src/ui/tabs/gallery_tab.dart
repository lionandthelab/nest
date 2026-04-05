import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../widgets/nest_empty_state.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key, required this.controller, this.title = '갤러리'});

  final NestController controller;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: GalleryTab(controller: controller),
      ),
    );
  }
}

class GalleryTab extends StatefulWidget {
  const GalleryTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends State<GalleryTab> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final items = controller.galleryItems.toList()
      ..sort((a, b) {
        final left = a.capturedAt?.millisecondsSinceEpoch ?? 0;
        final right = b.capturedAt?.millisecondsSinceEpoch ?? 0;
        return right.compareTo(left);
      });

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: controller.canUploadMedia
          ? FloatingActionButton(
              onPressed: () => _openUploadModal(controller),
              backgroundColor: NestColors.dustyRose,
              child: const Icon(Icons.add_photo_alternate, color: Colors.white),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _reloadGallery,
        child: items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  NestEmptyState(
                    icon: Icons.photo_library_outlined,
                    title: '사진이 없습니다',
                    subtitle: '오른쪽 아래 + 버튼으로 사진이나 영상을 올려보세요.',
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 600
                          ? 3
                          : 2;

                  return GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(2),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _GooglePhotosTile(
                        item: item,
                        imageUrl: controller.mediaPublicUrl(item.storagePath),
                        onTap: () => _showDetailDialog(item, controller),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  // ── Upload Modal ──

  void _openUploadModal(NestController controller) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final file = controller.pendingMediaFile;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: NestColors.deepWood.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '새 미디어 업로드',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  // File picker area
                  GestureDetector(
                    onTap: controller.isBusy
                        ? null
                        : () async {
                            await _pickFile();
                            setModalState(() {});
                          },
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: NestColors.roseMist,
                          width: 2,
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
                        color: file == null
                            ? NestColors.creamyWhite
                            : NestColors.mutedSage.withValues(alpha: 0.14),
                      ),
                      child: Center(
                        child: file == null
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 36,
                                    color: NestColors.deepWood
                                        .withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '탭하여 파일 선택',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: NestColors.deepWood
                                              .withValues(alpha: 0.5),
                                        ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.task_alt,
                                      color: NestColors.deepWood),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      file.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '제목',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '설명',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: controller.isBusy
                        ? null
                        : () async {
                            final navigator = Navigator.of(ctx);
                            await _upload();
                            if (mounted) navigator.pop();
                          },
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('업로드'),
                    style: FilledButton.styleFrom(
                      backgroundColor: NestColors.dustyRose,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Detail Dialog ──

  void _showDetailDialog(GalleryItem item, NestController controller) {
    final dateLabel = item.capturedAt == null
        ? '촬영일 미정'
        : DateFormat('yyyy년 M월 d일 HH:mm').format(item.capturedAt!);
    final title = item.title.trim().isEmpty ? '제목 없음' : item.title.trim();
    final description = item.description.trim().isEmpty
        ? ''
        : item.description.trim();
    final classGroupName = controller.findClassGroupName(item.classGroupId);
    final taggedCount = controller.findTaggedChildren(item.id).length;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Media preview
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Container(
                    height: 280,
                    color: NestColors.creamyWhite,
                    child: _buildPreview(item, controller),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateLabel,
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.5),
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(description,
                            style: Theme.of(ctx).textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _DetailChip(
                            icon: item.isVideo
                                ? Icons.videocam_outlined
                                : Icons.image_outlined,
                            label: item.isVideo ? '영상' : '사진',
                          ),
                          _DetailChip(
                            icon: Icons.groups_2_outlined,
                            label: classGroupName,
                          ),
                          if (taggedCount > 0)
                            _DetailChip(
                              icon: Icons.sell_outlined,
                              label: '태그 $taggedCount명',
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('닫기'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Business Logic ──

  Future<void> _pickFile() async {
    try {
      await widget.controller.pickMediaFile();
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _upload() async {
    try {
      await widget.controller.uploadPendingMedia(
        title: _titleController.text,
        description: _descriptionController.text,
        childIdsCsv: '',
      );
      _titleController.clear();
      _descriptionController.clear();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _reloadGallery() async {
    try {
      await widget.controller.loadGalleryItems();
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Widget _buildPreview(GalleryItem item, NestController controller) {
    final url = controller.mediaPublicUrl(item.storagePath);
    if (url != null && !item.isVideo) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (_, _, _) => Center(
          child: Icon(Icons.broken_image_outlined, size: 48,
              color: NestColors.deepWood.withValues(alpha: 0.3)),
        ),
      );
    }
    return Center(
      child: Icon(
        item.isVideo ? Icons.play_circle_outline : Icons.photo_outlined,
        size: 56,
        color: NestColors.deepWood.withValues(alpha: 0.4),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

// ── Google Photos-style grid tile ──

class _GooglePhotosTile extends StatelessWidget {
  const _GooglePhotosTile({
    required this.item,
    required this.imageUrl,
    required this.onTap,
  });

  final GalleryItem item;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image or placeholder
          if (imageUrl != null)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(),
            )
          else
            _placeholder(),
          // Video badge
          if (item.isVideo)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.videocam, size: 14, color: Colors.white),
              ),
            ),
          // Title overlay at bottom
          if (item.title.trim().isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 16, 6, 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.4),
                    ],
                  ),
                ),
                child: Text(
                  item.title.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: item.isVideo
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
      child: Center(
        child: Icon(
          item.isVideo ? Icons.play_circle_outline : Icons.photo_outlined,
          size: 32,
          color: NestColors.deepWood.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: NestColors.creamyWhite,
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: NestColors.deepWood),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.84),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
