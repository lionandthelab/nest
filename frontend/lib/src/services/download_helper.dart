import 'dart:typed_data';

import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

abstract class DownloadHelper {
  void downloadBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  });
}

DownloadHelper createDownloadHelper() => createHelper();
