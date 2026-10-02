import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/nest_models.dart';
import '../nest_theme.dart';

/// 공지 첨부를 소식 카드 안에서 바로 볼 수 있게 보여준다.
///
/// 이미지는 카드에 바로 그리고, 누르면 크게 본다. PDF와 텍스트는 앱 안
/// 미리보기로 연다. 한글·오피스·압축 파일은 기기의 기본 앱으로 연다.
/// [onDelete]가 있으면 편집 화면용 삭제 버튼이 붙는다.
class AnnouncementAttachmentList extends StatelessWidget {
  const AnnouncementAttachmentList({
    super.key,
    required this.attachments,
    required this.resolveUrl,
    required this.downloadBytes,
    this.onDelete,
  });

  final List<AnnouncementAttachment> attachments;
  final String? Function(String storagePath) resolveUrl;
  final AnnouncementBytesLoader downloadBytes;
  final void Function(AnnouncementAttachment attachment)? onDelete;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    final images = <AnnouncementAttachment>[];
    final files = <AnnouncementAttachment>[];
    for (final attachment in attachments) {
      if (announcementPreviewKind(
            mimeType: attachment.mimeType,
            fileName: attachment.fileName,
          ) ==
          AnnouncementPreviewKind.image) {
        images.add(attachment);
      } else {
        files.add(attachment);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          _ImageStrip(
            images: [
              for (final attachment in images)
                _PreviewImage(
                  key: ValueKey('announcement-attachment-${attachment.id}'),
                  fileName: attachment.fileName,
                  url: resolveUrl(attachment.storagePath),
                ),
            ],
            onDeleteAt: onDelete == null
                ? null
                : (index) => onDelete!(images[index]),
          ),
        if (images.isNotEmpty && files.isNotEmpty) const SizedBox(height: 8),
        for (var index = 0; index < files.length; index++) ...[
          if (index > 0) const SizedBox(height: 6),
          _FilePreviewTile(
            fileName: files[index].fileName,
            mimeType: files[index].mimeType,
            sizeLabel: formatAttachmentSize(files[index].sizeBytes),
            onDelete: onDelete == null ? null : () => onDelete!(files[index]),
            onOpen: () => _openStoredFile(
              context,
              attachment: files[index],
              resolveUrl: resolveUrl,
              downloadBytes: downloadBytes,
            ),
          ),
        ],
      ],
    );
  }
}

/// 아직 올리지 않은 첨부. 이미지와 PDF는 기기에 있는 바이트로 바로 보여준다.
class PendingAnnouncementAttachments extends StatelessWidget {
  const PendingAnnouncementAttachments({
    super.key,
    required this.files,
    required this.onRemove,
  });

  final List<PendingMediaFile> files;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const SizedBox.shrink();
    }

    final imageIndexes = <int>[];
    final fileIndexes = <int>[];
    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final kind = announcementPreviewKind(
        mimeType: file.mimeType,
        fileName: file.name,
      );
      if (kind == AnnouncementPreviewKind.image) {
        imageIndexes.add(index);
      } else {
        fileIndexes.add(index);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageIndexes.isNotEmpty)
          _ImageStrip(
            images: [
              for (final index in imageIndexes)
                _PreviewImage(
                  key: ValueKey('pending-attachment-$index'),
                  fileName: files[index].name,
                  bytes: files[index].bytes,
                ),
            ],
            onDeleteAt: (visualIndex) => onRemove(imageIndexes[visualIndex]),
          ),
        if (imageIndexes.isNotEmpty && fileIndexes.isNotEmpty)
          const SizedBox(height: 8),
        for (var slot = 0; slot < fileIndexes.length; slot++) ...[
          if (slot > 0) const SizedBox(height: 6),
          _PendingFileTile(
            file: files[fileIndexes[slot]],
            onDelete: () => onRemove(fileIndexes[slot]),
          ),
        ],
      ],
    );
  }
}

typedef AnnouncementBytesLoader =
    Future<Uint8List> Function(String storagePath);

enum AnnouncementPreviewKind { image, pdf, text, other }

AnnouncementPreviewKind announcementPreviewKind({
  required String mimeType,
  required String fileName,
}) {
  final mime = mimeType.toLowerCase();
  final name = fileName.toLowerCase();
  if (mime.startsWith('image/') ||
      _hasExtension(name, const [
        '.png',
        '.jpg',
        '.jpeg',
        '.gif',
        '.webp',
        '.heic',
      ])) {
    return AnnouncementPreviewKind.image;
  }
  if (mime == 'application/pdf' || name.endsWith('.pdf')) {
    return AnnouncementPreviewKind.pdf;
  }
  if (mime.startsWith('text/') || name.endsWith('.txt')) {
    return AnnouncementPreviewKind.text;
  }
  return AnnouncementPreviewKind.other;
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

class _PreviewImage {
  const _PreviewImage({
    required this.key,
    required this.fileName,
    this.url,
    this.bytes,
  });

  final Key key;
  final String fileName;
  final String? url;
  final Uint8List? bytes;

  bool get hasSource => bytes != null || (url != null && url!.isNotEmpty);
}

class _ImageStrip extends StatelessWidget {
  const _ImageStrip({required this.images, required this.onDeleteAt});

  final List<_PreviewImage> images;
  final ValueChanged<int>? onDeleteAt;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return _ImageFrame(
        image: images.single,
        height: 220,
        onOpen: () => _openImagePreview(context, images, 0),
        onDelete: onDeleteAt == null ? null : () => onDeleteAt!(0),
      );
    }

    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return _ImageFrame(
            image: images[index],
            width: 210,
            height: 150,
            onOpen: () => _openImagePreview(context, images, index),
            onDelete: onDeleteAt == null ? null : () => onDeleteAt!(index),
          );
        },
      ),
    );
  }
}

class _ImageFrame extends StatelessWidget {
  const _ImageFrame({
    required this.image,
    required this.height,
    required this.onOpen,
    this.width,
    this.onDelete,
  });

  final _PreviewImage image;
  final double height;
  final double? width;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: width ?? double.infinity,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: Material(
                  color: NestColors.roseMist.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: image.key,
                    onTap: image.hasSource ? onOpen : null,
                    child: SizedBox.expand(child: _buildImage()),
                  ),
                ),
              ),
              if (onDelete != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _RemoveButton(onPressed: onDelete!),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: width,
          child: Text(
            image.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.72),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImage() {
    const fit = BoxFit.contain;
    if (image.bytes != null) {
      return Image.memory(
        image.bytes!,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _BrokenPreview(fileName: image.fileName),
      );
    }
    final url = image.url;
    if (url == null || url.isEmpty) {
      return _BrokenPreview(fileName: image.fileName);
    }
    return Image.network(
      url,
      fit: fit,
      cacheWidth: 960,
      errorBuilder: (_, _, _) => _BrokenPreview(fileName: image.fileName),
    );
  }
}

class _BrokenPreview extends StatelessWidget {
  const _BrokenPreview({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_not_supported_outlined,
              color: NestColors.deepWood,
            ),
            const SizedBox(height: 6),
            Text(
              fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingFileTile extends StatelessWidget {
  const _PendingFileTile({required this.file, required this.onDelete});

  final PendingMediaFile file;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final kind = announcementPreviewKind(
      mimeType: file.mimeType,
      fileName: file.name,
    );
    final canPreview =
        kind == AnnouncementPreviewKind.pdf ||
        kind == AnnouncementPreviewKind.text;
    return _FilePreviewTile(
      fileName: file.name,
      mimeType: file.mimeType,
      sizeLabel: formatAttachmentSize(file.sizeBytes),
      onDelete: onDelete,
      onOpen: canPreview ? () => _openPendingFile(context, file) : null,
    );
  }
}

class _FilePreviewTile extends StatelessWidget {
  const _FilePreviewTile({
    required this.fileName,
    required this.mimeType,
    required this.sizeLabel,
    required this.onOpen,
    this.onDelete,
  });

  final String fileName;
  final String mimeType;
  final String sizeLabel;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final kind = announcementPreviewKind(
      mimeType: mimeType,
      fileName: fileName,
    );
    final actionLabel = switch (kind) {
      AnnouncementPreviewKind.pdf => '눌러서 미리보기',
      AnnouncementPreviewKind.text => '눌러서 내용 보기',
      AnnouncementPreviewKind.image => '눌러서 미리보기',
      AnnouncementPreviewKind.other => onOpen == null ? null : '눌러서 열기',
    };

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NestColors.roseMist),
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Row(
            children: [
              Icon(_iconFor(mimeType, fileName), color: NestColors.dustyRose),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      actionLabel == null
                          ? sizeLabel
                          : '$actionLabel · $sizeLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                _RemoveButton(onPressed: onDelete!)
              else if (onOpen != null)
                const Icon(Icons.chevron_right, color: NestColors.clay),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '첨부 삭제',
      child: Material(
        color: NestColors.creamyWhite.withValues(alpha: 0.94),
        shape: const CircleBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: 28,
            height: 28,
            child: Icon(Icons.close, size: 16, color: NestColors.deepWood),
          ),
        ),
      ),
    );
  }
}

Future<void> _openStoredFile(
  BuildContext context, {
  required AnnouncementAttachment attachment,
  required String? Function(String storagePath) resolveUrl,
  required Future<Uint8List> Function(String storagePath) downloadBytes,
}) async {
  final url = resolveUrl(attachment.storagePath);
  final kind = announcementPreviewKind(
    mimeType: attachment.mimeType,
    fileName: attachment.fileName,
  );
  switch (kind) {
    case AnnouncementPreviewKind.pdf:
      await _openPdfPreview(
        context,
        fileName: attachment.fileName,
        externalUrl: url,
        loadBytes: () => downloadBytes(attachment.storagePath),
      );
    case AnnouncementPreviewKind.text:
      await _openTextPreview(
        context,
        fileName: attachment.fileName,
        externalUrl: url,
        loadBytes: () => downloadBytes(attachment.storagePath),
      );
    case AnnouncementPreviewKind.image:
    case AnnouncementPreviewKind.other:
      await _launchExternal(context, url);
  }
}

Future<void> _openPendingFile(
  BuildContext context,
  PendingMediaFile file,
) async {
  final kind = announcementPreviewKind(
    mimeType: file.mimeType,
    fileName: file.name,
  );
  switch (kind) {
    case AnnouncementPreviewKind.pdf:
      await _openPdfPreview(
        context,
        fileName: file.name,
        loadBytes: () async => file.bytes,
      );
    case AnnouncementPreviewKind.text:
      await _openTextPreview(
        context,
        fileName: file.name,
        loadBytes: () async => file.bytes,
      );
    case AnnouncementPreviewKind.image:
    case AnnouncementPreviewKind.other:
      return;
  }
}

Future<void> _openImagePreview(
  BuildContext context,
  List<_PreviewImage> images,
  int initialIndex,
) {
  final tapped = images[initialIndex];
  if (!tapped.hasSource) {
    _snack(context, '사진을 열 수 없습니다.');
    return Future.value();
  }
  final sources = images.where((image) => image.hasSource).toList();
  final start = sources.indexOf(tapped);
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xE6000000),
    builder: (context) => _ImageLightbox(images: sources, initialIndex: start),
  );
}

class _ImageLightbox extends StatefulWidget {
  const _ImageLightbox({required this.images, required this.initialIndex});

  final List<_PreviewImage> images;
  final int initialIndex;

  @override
  State<_ImageLightbox> createState() => _ImageLightboxState();
}

class _ImageLightboxState extends State<_ImageLightbox> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.images[_index];
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final page = widget.images[index];
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(child: _lightboxImage(page)),
                );
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            image.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        if ((image.url ?? '').isNotEmpty)
                          IconButton(
                            tooltip: '브라우저에서 열기',
                            onPressed: () =>
                                _launchExternal(context, image.url),
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    if (widget.images.length > 1)
                      Text(
                        '${_index + 1} / ${widget.images.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lightboxImage(_PreviewImage image) {
    if (image.bytes != null) {
      return Image.memory(
        image.bytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const _BrokenPreview(fileName: ''),
      );
    }
    return Image.network(
      image.url!,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _BrokenPreview(fileName: image.fileName),
    );
  }
}

Future<void> _openPdfPreview(
  BuildContext context, {
  required String fileName,
  required Future<Uint8List> Function() loadBytes,
  String? externalUrl,
}) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (context) => _PdfPreviewDialog(
      fileName: fileName,
      loadBytes: loadBytes,
      externalUrl: externalUrl,
    ),
  );
}

class _PdfPreviewDialog extends StatefulWidget {
  const _PdfPreviewDialog({
    required this.fileName,
    required this.loadBytes,
    this.externalUrl,
  });

  final String fileName;
  final Future<Uint8List> Function() loadBytes;
  final String? externalUrl;

  @override
  State<_PdfPreviewDialog> createState() => _PdfPreviewDialogState();
}

class _PdfPreviewDialogState extends State<_PdfPreviewDialog> {
  late final Future<Uint8List> _bytes = widget.loadBytes();

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: NestColors.creamyWhite,
        appBar: AppBar(
          backgroundColor: NestColors.creamyWhite,
          foregroundColor: NestColors.deepWood,
          title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
          leading: IconButton(
            tooltip: '닫기',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: PdfPreview(
          build: (_) => _bytes,
          pdfFileName: widget.fileName,
          allowPrinting: true,
          allowSharing: true,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          loadingWidget: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('파일을 불러오는 중...'),
              ],
            ),
          ),
          onError: (context, error) => _PreviewError(
            message: 'PDF를 미리볼 수 없습니다.',
            onOpenExternal: (widget.externalUrl ?? '').isEmpty
                ? null
                : () => _launchExternal(context, widget.externalUrl),
          ),
        ),
      ),
    );
  }
}

Future<void> _openTextPreview(
  BuildContext context, {
  required String fileName,
  required Future<Uint8List> Function() loadBytes,
  String? externalUrl,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _TextPreviewDialog(
      fileName: fileName,
      loadBytes: loadBytes,
      externalUrl: externalUrl,
    ),
  );
}

class _TextPreviewDialog extends StatefulWidget {
  const _TextPreviewDialog({
    required this.fileName,
    required this.loadBytes,
    this.externalUrl,
  });

  final String fileName;
  final Future<Uint8List> Function() loadBytes;
  final String? externalUrl;

  @override
  State<_TextPreviewDialog> createState() => _TextPreviewDialogState();
}

class _TextPreviewDialogState extends State<_TextPreviewDialog> {
  late final Future<String> _text = widget.loadBytes().then(_decodePreviewText);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: width < 600 ? 520 : 640,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<String>(
                  future: _text,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return _PreviewError(
                        message: '내용을 불러오지 못했습니다.',
                        onOpenExternal: (widget.externalUrl ?? '').isEmpty
                            ? null
                            : () =>
                                  _launchExternal(context, widget.externalUrl),
                      );
                    }
                    return Scrollbar(
                      child: SingleChildScrollView(
                        child: SelectableText(snapshot.data!),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.message, this.onOpenExternal});

  final String message;
  final VoidCallback? onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: NestColors.clay),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onOpenExternal != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onOpenExternal,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('브라우저에서 열기'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _decodePreviewText(Uint8List bytes) {
  const limit = 200000;
  final truncated = bytes.length > limit;
  final slice = truncated ? Uint8List.sublistView(bytes, 0, limit) : bytes;
  final text = utf8.decode(slice, allowMalformed: true);
  if (!truncated) return text;
  return '$text\n\n… 파일이 길어 앞부분만 보여줍니다.';
}

Future<void> _launchExternal(BuildContext context, String? url) async {
  if (url == null || url.isEmpty) {
    _snack(context, '파일을 열 수 없습니다.');
    return;
  }
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    _snack(context, '파일을 열 수 없습니다.');
    return;
  }
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    _snack(context, '파일을 열지 못했습니다.');
  }
}

void _snack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

bool _hasExtension(String fileName, List<String> extensions) {
  for (final extension in extensions) {
    if (fileName.endsWith(extension)) return true;
  }
  return false;
}

IconData _iconFor(String mimeType, String fileName) {
  final kind = announcementPreviewKind(mimeType: mimeType, fileName: fileName);
  if (kind == AnnouncementPreviewKind.image) return Icons.image_outlined;
  if (kind == AnnouncementPreviewKind.pdf) return Icons.picture_as_pdf_outlined;
  if (kind == AnnouncementPreviewKind.text) return Icons.description_outlined;
  final mime = mimeType.toLowerCase();
  if (mime.contains('zip') || fileName.toLowerCase().endsWith('.zip')) {
    return Icons.folder_zip_outlined;
  }
  if (mime.contains('sheet') || mime.contains('excel')) {
    return Icons.table_chart_outlined;
  }
  if (mime.contains('presentation') || mime.contains('powerpoint')) {
    return Icons.slideshow_outlined;
  }
  return Icons.insert_drive_file_outlined;
}
