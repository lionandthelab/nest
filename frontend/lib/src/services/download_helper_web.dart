// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

import 'download_helper.dart';

DownloadHelper createHelper() => const _DownloadHelperWeb();

class _DownloadHelperWeb implements DownloadHelper {
  const _DownloadHelperWeb();

  @override
  void downloadBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
