import 'dart:typed_data';

import 'download_helper.dart';

DownloadHelper createHelper() => const _DownloadHelperStub();

class _DownloadHelperStub implements DownloadHelper {
  const _DownloadHelperStub();

  @override
  void downloadBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) {
    // No-op on non-web platforms.
  }
}
