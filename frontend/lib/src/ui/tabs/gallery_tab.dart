import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';

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

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Media Upload',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '선생님/관리자가 사진과 영상을 Google Drive로 업로드하고 갤러리에 공유합니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: controller.isBusy ? null : _pickFile,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('파일 선택'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: controller.isBusy ? null : _reloadGallery,
                      icon: const Icon(Icons.refresh),
                      label: const Text('갤러리 갱신'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SelectedFileLabel(controller: controller),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: '제목'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '설명'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _childIdsController,
                  decoration: const InputDecoration(
                    labelText: 'Child ID 태그 (콤마 구분)',
                    hintText: 'uuid1, uuid2',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: controller.isBusy ? null : _upload,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Drive 업로드'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gallery', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                if (controller.galleryItems.isEmpty)
                  const Text('표시할 갤러리 항목이 없습니다.')
                else
                  ...controller.galleryItems.map((item) {
                    final taggedCount = controller
                        .findTaggedChildren(item.id)
                        .length;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: NestColors.roseMist),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: item.isVideo
                                    ? NestColors.mutedSage.withValues(
                                        alpha: 0.24,
                                      )
                                    : NestColors.dustyRose.withValues(
                                        alpha: 0.2,
                                      ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                item.isVideo
                                    ? Icons.videocam_rounded
                                    : Icons.photo_camera_back_rounded,
                                color: NestColors.deepWood,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title.isEmpty ? '제목 없음' : item.title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description.isEmpty
                                        ? '설명 없음'
                                        : item.description,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '태그된 child: $taggedCount · '
                                    '${item.capturedAt == null ? '-' : DateFormat('yyyy-MM-dd HH:mm').format(item.capturedAt!)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (item.driveWebViewLink != null &&
                                item.driveWebViewLink!.isNotEmpty)
                              FilledButton.tonal(
                                onPressed: () =>
                                    _openLink(item.driveWebViewLink!),
                                child: const Text('Drive 열기'),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    try {
      await widget.controller.pickMediaFile();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.controller.statusMessage)));
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

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.controller.statusMessage)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.controller.statusMessage)));
    }
  }

  Future<void> _reloadGallery() async {
    try {
      await widget.controller.loadGalleryItems();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('갤러리를 새로고침했습니다.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.controller.statusMessage)));
    }
  }

  Future<void> _openLink(String url) async {
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('링크를 열지 못했습니다.')));
    }
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
        borderRadius: BorderRadius.circular(12),
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
              onPressed: controller.isBusy
                  ? null
                  : () {
                      controller.clearPendingFile();
                    },
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
    );
  }
}
