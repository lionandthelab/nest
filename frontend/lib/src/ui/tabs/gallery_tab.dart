import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key, required this.controller, this.title = '갤러리'});

  final NestController controller;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: GalleryTab(controller: controller),
        ),
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
  final _childIdsController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _childIdsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final totalItems = controller.galleryItems.length;
    final videoCount = controller.galleryItems
        .where((item) => item.isVideo)
        .length;
    final photoCount = totalItems - videoCount;

    return RefreshIndicator(
      onRefresh: _reloadGallery,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildHeroCard(
            totalItems: totalItems,
            photoCount: photoCount,
            videoCount: videoCount,
          ),
          if (controller.canUploadMedia) ...[
            const SizedBox(height: 12),
            _buildUploadCard(controller),
          ],
          const SizedBox(height: 12),
          _buildGalleryBoard(controller),
        ],
      ),
    );
  }

  Widget _buildHeroCard({
    required int totalItems,
    required int photoCount,
    required int videoCount,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    NestColors.dustyRose.withValues(alpha: 0.22),
                    NestColors.mutedSage.withValues(alpha: 0.14),
                    Colors.white,
                  ],
                ),
                border: Border.all(color: NestColors.roseMist),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                        child: const Icon(Icons.photo_library_outlined),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gallery',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '반별 사진과 영상을 타임라인처럼 확인하고, 필요한 경우 바로 Drive 원본을 엽니다.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: NestColors.deepWood.withValues(
                                      alpha: 0.74,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _GalleryMetricChip(
                        icon: Icons.collections_outlined,
                        label: '전체 $totalItems개',
                      ),
                      _GalleryMetricChip(
                        icon: Icons.photo_camera_back_outlined,
                        label: '사진 $photoCount개',
                      ),
                      _GalleryMetricChip(
                        icon: Icons.videocam_outlined,
                        label: '영상 $videoCount개',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: widget.controller.isBusy
                            ? null
                            : _reloadGallery,
                        icon: const Icon(Icons.refresh),
                        label: const Text('새로고침'),
                      ),
                      if (widget.controller.canUploadMedia)
                        ElevatedButton.icon(
                          onPressed: widget.controller.isBusy
                              ? null
                              : _pickFile,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('업로드 준비'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(NestController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('업로드', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '사진과 영상을 고른 뒤 제목과 설명을 붙여 바로 갤러리에 올립니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            _SelectedFileLabel(controller: controller),
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
            const SizedBox(height: 8),
            TextField(
              controller: _childIdsController,
              decoration: const InputDecoration(
                labelText: 'Child ID 태그',
                hintText: 'uuid1, uuid2',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: controller.isBusy ? null : _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('파일 선택'),
                ),
                FilledButton.icon(
                  onPressed: controller.isBusy ? null : _upload,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Drive 업로드'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryBoard(NestController controller) {
    final items = controller.galleryItems.toList(growable: false)
      ..sort((a, b) {
        final left = a.capturedAt?.millisecondsSinceEpoch ?? 0;
        final right = b.capturedAt?.millisecondsSinceEpoch ?? 0;
        return right.compareTo(left);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('최근 기록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (items.isEmpty)
              _buildEmptyState()
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columnCount = constraints.maxWidth >= 860
                      ? 3
                      : constraints.maxWidth >= 560
                      ? 2
                      : 1;
                  final itemWidth =
                      (constraints.maxWidth - ((columnCount - 1) * 10)) /
                      columnCount;

                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: items
                        .map(
                          (item) => SizedBox(
                            width: itemWidth,
                            child: _GalleryTile(
                              item: item,
                              taggedCount: controller
                                  .findTaggedChildren(item.id)
                                  .length,
                              classGroupName: controller.findClassGroupName(
                                item.classGroupId,
                              ),
                              onOpenLink: _openLink,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: NestColors.roseMist.withValues(alpha: 0.34),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 32,
            color: NestColors.deepWood.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 8),
          const Text('표시할 갤러리 항목이 없습니다.'),
        ],
      ),
    );
  }

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
        childIdsCsv: _childIdsController.text,
      );

      _titleController.clear();
      _descriptionController.clear();
      _childIdsController.clear();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _reloadGallery() async {
    try {
      await widget.controller.loadGalleryItems();
      _showMessage('갤러리를 새로고침했습니다.');
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _openLink(String url) async {
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
    );

    if (!launched) {
      _showMessage('링크를 열지 못했습니다.');
    }
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _GalleryMetricChip extends StatelessWidget {
  const _GalleryMetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.88),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: NestColors.deepWood),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.item,
    required this.taggedCount,
    required this.classGroupName,
    required this.onOpenLink,
  });

  final GalleryItem item;
  final int taggedCount;
  final String classGroupName;
  final Future<void> Function(String url) onOpenLink;

  @override
  Widget build(BuildContext context) {
    final dateLabel = item.capturedAt == null
        ? '촬영일 미정'
        : DateFormat('yyyy-MM-dd HH:mm').format(item.capturedAt!);
    final title = item.title.trim().isEmpty ? '제목 없음' : item.title.trim();
    final description = item.description.trim().isEmpty
        ? '설명이 아직 없습니다.'
        : item.description.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: NestColors.roseMist),
        boxShadow: [
          BoxShadow(
            color: NestColors.deepWood.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 132,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: item.isVideo
                    ? [
                        NestColors.mutedSage.withValues(alpha: 0.34),
                        NestColors.mutedSage.withValues(alpha: 0.14),
                      ]
                    : [
                        NestColors.dustyRose.withValues(alpha: 0.34),
                        NestColors.roseMist.withValues(alpha: 0.24),
                      ],
              ),
            ),
            child: Center(
              child: Icon(
                item.isVideo
                    ? Icons.videocam_rounded
                    : Icons.photo_camera_back_rounded,
                size: 36,
                color: NestColors.deepWood,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _GalleryLabelChip(
                icon: item.isVideo
                    ? Icons.play_circle_outline
                    : Icons.image_outlined,
                label: item.isVideo ? '영상' : '사진',
              ),
              _GalleryLabelChip(
                icon: Icons.groups_2_outlined,
                label: classGroupName,
              ),
              _GalleryLabelChip(
                icon: Icons.sell_outlined,
                label: '태그 $taggedCount명',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.76),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.58),
            ),
          ),
          if (item.driveWebViewLink != null &&
              item.driveWebViewLink!.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => onOpenLink(item.driveWebViewLink!),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Drive 열기'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GalleryLabelChip extends StatelessWidget {
  const _GalleryLabelChip({required this.icon, required this.label});

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

class _SelectedFileLabel extends StatelessWidget {
  const _SelectedFileLabel({required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    final file = controller.pendingMediaFile;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NestColors.roseMist),
        color: file == null
            ? Colors.white
            : NestColors.mutedSage.withValues(alpha: 0.14),
      ),
      child: Row(
        children: [
          Icon(
            file == null ? Icons.file_present_outlined : Icons.task_alt,
            color: NestColors.deepWood,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file == null
                  ? '선택된 파일 없음'
                  : '${file.name} (${file.sizeBytes} bytes)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (file != null)
            IconButton(
              onPressed: controller.isBusy ? null : controller.clearPendingFile,
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
    );
  }
}
