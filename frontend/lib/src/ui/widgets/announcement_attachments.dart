import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/nest_models.dart';
import '../nest_theme.dart';

/// 공지 첨부파일을 칩으로 보여주고 탭하면 새 창/앱에서 연다.
///
/// [onDelete]가 주어지면 각 칩에 삭제 버튼이 붙는다(작성자/관리자 편집 화면 전용).
/// 읽기 전용 화면(학부모·학생 홈)에서는 [onDelete]를 생략한다.
class AnnouncementAttachmentList extends StatelessWidget {
  const AnnouncementAttachmentList({
    super.key,
    required this.attachments,
    required this.resolveUrl,
    this.onDelete,
  });

  final List<AnnouncementAttachment> attachments;
  final String? Function(String storagePath) resolveUrl;
  final void Function(AnnouncementAttachment attachment)? onDelete;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: attachments
          .map(
            (attachment) => _AttachmentChip(
              attachment: attachment,
              resolveUrl: resolveUrl,
              onDelete: onDelete == null
                  ? null
                  : () => onDelete!(attachment),
            ),
          )
          .toList(),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.attachment,
    required this.resolveUrl,
    this.onDelete,
  });

  final AnnouncementAttachment attachment;
  final String? Function(String storagePath) resolveUrl;
  final VoidCallback? onDelete;

  Future<void> _open(BuildContext context) async {
    final url = resolveUrl(attachment.storagePath);
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('파일을 열 수 없습니다.')));
      return;
    }

    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('파일을 열지 못했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: Icon(
        _iconFor(attachment.mimeType),
        size: 16,
        color: NestColors.deepWood,
      ),
      label: Text(
        '${attachment.fileName} (${formatAttachmentSize(attachment.sizeBytes)})',
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: () => _open(context),
      onDeleted: onDelete,
      backgroundColor: NestColors.roseMist.withValues(alpha: 0.4),
      side: const BorderSide(color: NestColors.roseMist),
    );
  }
}

IconData _iconFor(String mimeType) {
  if (mimeType.startsWith('image/')) {
    return Icons.image_outlined;
  }
  if (mimeType == 'application/pdf') {
    return Icons.picture_as_pdf_outlined;
  }
  if (mimeType.contains('zip')) {
    return Icons.folder_zip_outlined;
  }
  if (mimeType.contains('sheet') || mimeType.contains('excel')) {
    return Icons.table_chart_outlined;
  }
  if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
    return Icons.slideshow_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

String formatAttachmentSize(int bytes) {
  if (bytes <= 0) {
    return '0KB';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).ceil()}KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}
