import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/nest_models.dart';
import '../../../state/nest_controller.dart';
import '../../nest_theme.dart';
import '../../widgets/announcement_attachments.dart';
import '../../widgets/nest_motion.dart';
import '../../widgets/nest_quiet_card.dart';
import '../../widgets/nest_sheet.dart';
import '../../widgets/search_select_field.dart';

/// 업로드 시트가 돌려주는 값. 시트는 모으기만 하고, 실제 업로드는 호출부가
/// 한다 — 공지 편집 시트와 같은 방식이다. 업로드가 도는 동안 사용자는 앨범을
/// 계속 볼 수 있어야 하므로 시트를 붙잡아 두지 않는다.
class AlbumUploadDraft {
  const AlbumUploadDraft({
    required this.files,
    required this.capturedAt,
    this.classGroupId,
    this.courseId,
    this.albumFolderId,
    this.description = '',
  });

  final List<PendingMediaFile> files;
  final DateTime capturedAt;
  final String? classGroupId;
  final String? courseId;
  final String? albumFolderId;
  final String description;
}

Future<AlbumUploadDraft?> showAlbumUploadSheet({
  required BuildContext context,
  required NestController controller,
}) {
  return showNestSheet<AlbumUploadDraft>(
    context: context,
    maxWidth: 560,
    builder: (sheetContext) =>
        _AlbumUploadSheet(controller: controller),
  );
}

class _AlbumUploadSheet extends StatefulWidget {
  const _AlbumUploadSheet({required this.controller});

  final NestController controller;

  @override
  State<_AlbumUploadSheet> createState() => _AlbumUploadSheetState();
}

class _AlbumUploadSheetState extends State<_AlbumUploadSheet> {
  final _descriptionController = TextEditingController();
  final _files = <PendingMediaFile>[];

  late String? _classGroupId = widget.controller.selectedClassGroupId;
  String? _courseId;
  late String? _folderId = widget.controller.albumFolderId;
  DateTime _capturedAt = DateTime.now();
  bool _isPicking = false;

  /// 한 번에 고를 수 있는 장수. 웹에서는 고른 파일 전부가 메모리에 올라오므로
  /// (file_picker의 withData) 상한이 없으면 탭이 죽는다.
  static const int _maxFiles = 20;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  int get _totalBytes =>
      _files.fold<int>(0, (sum, file) => sum + file.sizeBytes);

  Future<void> _pick() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final picked = await widget.controller.pickAlbumMediaFiles();
      if (!mounted) return;
      if (picked.isEmpty) return;

      final room = _maxFiles - _files.length;
      setState(() => _files.addAll(picked.take(room)));

      if (picked.length > room) {
        _toast('한 번에 최대 $_maxFiles개까지 올릴 수 있습니다.');
      }
    } catch (_) {
      if (mounted) _toast('파일을 읽지 못했습니다. 다시 선택해 주세요.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _capturedAt,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: '촬영일 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked != null && mounted) {
      setState(() => _capturedAt = picked);
    }
  }

  Future<void> _pickClassGroup() async {
    final groups = widget.controller.classGroups;
    final selected = await showSelectSheet<String?>(
      context: context,
      title: '반 선택',
      helpText: '이 학기의 반 중에서 고르세요.',
      currentValue: _classGroupId,
      options: [
        const SelectSheetOption(
          value: null,
          title: '반 없음',
          subtitle: '앨범의 미분류에 들어갑니다',
        ),
        for (final group in groups)
          SelectSheetOption(
            value: group.id,
            title: group.name,
            keywords: group.name,
          ),
      ],
    );
    if (!mounted) return;
    setState(() => _classGroupId = selected);
  }

  /// 폴더 고르기. 목록 맨 위에 "새 폴더 만들기"를 둬서, Drive에서 폴더를
  /// 만들고 오는 왕복 없이 여기서 끝나게 한다.
  Future<void> _pickFolder() async {
    const createValue = '__create__';
    final folders = widget.controller.visibleAlbumFolders;

    final picked = await showSelectSheet<String?>(
      context: context,
      title: '폴더 선택',
      helpText: '행사나 주제별로 묶어 둘 폴더를 고르세요.',
      currentValue: _folderId,
      options: [
        const SelectSheetOption(
          value: createValue,
          title: '+ 새 폴더 만들기',
          subtitle: '예: 가을 소풍, 김장 체험',
        ),
        const SelectSheetOption(
          value: null,
          title: '폴더 없음',
          subtitle: '학기·수업·날짜로만 묶입니다',
        ),
        for (final folder in folders)
          SelectSheetOption(
            value: folder.id,
            title: folder.name,
            keywords: folder.name,
          ),
      ],
    );

    if (!mounted || picked == null && _folderId == null) return;

    if (picked == createValue) {
      await _createFolder();
      return;
    }
    setState(() => _folderId = picked);
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showNestSheet<String>(
      context: context,
      maxWidth: 420,
      builder: (sheetContext) => NestSheet(
        title: '새 폴더',
        subtitle: 'Google Drive에도 같은 이름의 폴더가 생깁니다.',
        icon: Icons.create_new_folder_outlined,
        iconColor: NestColors.clay,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(sheetContext).pop(controller.text.trim()),
            child: const Text('만들기'),
          ),
        ],
        child: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) =>
              Navigator.of(sheetContext).pop(value.trim()),
          decoration: const InputDecoration(
            labelText: '폴더 이름',
            hintText: '예: 조이홈스쿨 2026 가을 소풍',
            prefixIcon: Icon(Icons.folder_outlined, size: 20),
          ),
        ),
      ),
    );
    controller.dispose();

    if (name == null || name.isEmpty || !mounted) return;

    try {
      final folder = await widget.controller.createAlbumFolder(name);
      if (!mounted) return;
      setState(() => _folderId = folder.id);
    } on StateError catch (error) {
      _toast(error.message);
    } catch (_) {
      _toast('폴더를 만들지 못했습니다.');
    }
  }

  Future<void> _pickCourse() async {
    final courses = widget.controller.courses;
    final selected = await showSelectSheet<String?>(
      context: context,
      title: '수업 선택',
      helpText: '어떤 수업에서 찍은 사진인지 고르세요.',
      currentValue: _courseId,
      options: [
        const SelectSheetOption(
          value: null,
          title: '수업 없음',
          subtitle: '학기 앨범에만 들어갑니다',
        ),
        for (final course in courses)
          SelectSheetOption(
            value: course.id,
            title: course.name,
            keywords: course.name,
          ),
      ],
    );
    if (!mounted) return;
    setState(() => _courseId = selected);
  }

  void _submit() {
    if (_files.isEmpty) {
      _toast('올릴 파일을 먼저 선택하세요.');
      return;
    }

    Navigator.of(context).pop(
      AlbumUploadDraft(
        files: List.unmodifiable(_files),
        capturedAt: _capturedAt,
        classGroupId: _classGroupId,
        courseId: _courseId,
        albumFolderId: _folderId,
        description: _descriptionController.text.trim(),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final driveConnected = controller.driveIntegration?.isConnected ?? false;

    return NestSheet(
      title: '사진 올리기',
      subtitle: '한 번에 여러 장을 고를 수 있습니다.',
      icon: Icons.add_photo_alternate_outlined,
      iconColor: NestColors.dustyRose,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
          label: const Text('업로드'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NestPressable(
            onPressed: _isPicking ? null : _pick,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: NestColors.roseMist,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
                color: _files.isEmpty
                    ? NestColors.creamyWhite
                    : NestColors.mutedSage.withValues(alpha: 0.14),
              ),
              child: Center(
                child: _files.isEmpty
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 36,
                            color: NestColors.deepWood.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '탭하여 사진·영상 선택',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: NestColors.deepWood.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.task_alt, color: NestColors.deepWood),
                          const SizedBox(width: 8),
                          Text(
                            '${_files.length}개 선택됨 · '
                            '${formatAttachmentSize(_totalBytes)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
              ),
            ),
          ),
          if (_files.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final file in _files)
                  InputChip(
                    avatar: Icon(
                      file.isVideo ? Icons.videocam : Icons.image,
                      size: 16,
                    ),
                    label: Text(
                      '${file.name} (${formatAttachmentSize(file.sizeBytes)})',
                    ),
                    onDeleted: () => setState(() => _files.remove(file)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SelectFieldCard(
            label: '폴더',
            hintText: '폴더를 고르거나 새로 만드세요',
            icon: Icons.folder_outlined,
            enabled: true,
            onTap: _pickFolder,
            value: controller.albumFolderName(_folderId).isEmpty
                ? null
                : controller.albumFolderName(_folderId),
            helpText: 'Drive에도 같은 이름의 폴더로 저장됩니다.',
          ),
          const SizedBox(height: 10),
          SelectFieldCard(
            label: '수업',
            hintText: '수업을 선택하세요',
            icon: Icons.menu_book_outlined,
            enabled: true,
            onTap: _pickCourse,
            value: controller.courses
                .where((course) => course.id == _courseId)
                .map((course) => course.name)
                .firstOrNull,
          ),
          const SizedBox(height: 10),
          SelectFieldCard(
            label: '반',
            hintText: '반을 선택하세요',
            icon: Icons.groups_outlined,
            enabled: true,
            onTap: _pickClassGroup,
            value: controller.classGroups
                .where((group) => group.id == _classGroupId)
                .map((group) => group.name)
                .firstOrNull,
          ),
          const SizedBox(height: 10),
          SelectFieldCard(
            label: '촬영일',
            hintText: '촬영일을 선택하세요',
            icon: Icons.event_outlined,
            enabled: true,
            onTap: _pickDate,
            value: DateFormat('yyyy년 M월 d일').format(_capturedAt),
            helpText: '앨범과 Drive 폴더가 이 날짜로 묶입니다.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '설명 (선택)',
              hintText: '어떤 순간인지 한 줄로 남겨보세요.',
              prefixIcon: Icon(Icons.notes_outlined, size: 20),
            ),
          ),
          if (driveConnected) ...[
            const SizedBox(height: 12),
            const NestQuietCard(
              '사진 원본은 관리자 Google Drive에 저장됩니다. 40MB가 넘는 파일은 Nest에 저장됩니다.',
            ),
          ],
        ],
      ),
    );
  }
}
