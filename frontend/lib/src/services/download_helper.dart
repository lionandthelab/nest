import 'dart:typed_data';

import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

abstract class DownloadHelper {
  /// 이 플랫폼에서 파일 저장이 실제로 동작하는지. 웹이 아닌 빌드에서는
  /// [downloadBytes]가 아무 일도 하지 않으므로, 호출부는 이 값을 먼저 보고
  /// "저장했습니다"라고 잘못 안내하지 않도록 한다.
  bool get isSupported;

  void downloadBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  });
}

DownloadHelper createDownloadHelper() => createHelper();
