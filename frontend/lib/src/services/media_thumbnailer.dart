import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 그리드에 붙일 축소본의 긴 변(px). 실제 타일은 180pt 안팎이고 DPR 2를 감안해도
/// 360px면 충분하지만, 타임라인·폴더 커버가 더 크게 쓰므로 여유를 둔다.
const int kThumbnailMaxEdge = 512;

/// JPEG 품질. 72 언저리가 512px에서 눈에 띄는 열화 없이 40~50KB로 떨어진다.
const int kThumbnailQuality = 72;

/// 인코딩된 바이트의 헤더만 읽어 원본 크기를 알아낸다. 모르면 null.
///
/// `ui.ImageDescriptor`로도 크기를 알 수 있지만 **웹에서는 width/height 게터가
/// UnsupportedError를 던진다**. 그것 때문에 웹에서 썸네일이 통째로 만들어지지
/// 않았고, 원본이 Drive로 가는 하이브리드 저장에서는 그리드에 아무것도 남지
/// 않았다. 헤더 몇 바이트만 보는 쪽이 플랫폼을 타지 않는다.
({int width, int height})? probeImageSize(Uint8List bytes) {
  final png = _probePng(bytes);
  if (png != null) return png;
  return _probeJpeg(bytes);
}

({int width, int height})? _probePng(Uint8List b) {
  // 8바이트 시그니처 + IHDR 길이(4) + 'IHDR'(4) + width(4) + height(4)
  if (b.length < 24) return null;
  const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < sig.length; i++) {
    if (b[i] != sig[i]) return null;
  }
  if (b[12] != 0x49 || b[13] != 0x48 || b[14] != 0x44 || b[15] != 0x52) {
    return null;
  }
  final w = _be32(b, 16);
  final h = _be32(b, 20);
  return (w > 0 && h > 0) ? (width: w, height: h) : null;
}

({int width, int height})? _probeJpeg(Uint8List b) {
  if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return null;

  var i = 2;
  while (i + 9 < b.length) {
    if (b[i] != 0xFF) {
      i += 1;
      continue;
    }
    final marker = b[i + 1];
    // SOF0~SOF15 중 크기를 담는 것들. DHT(C4)·JPG(C8)·DAC(CC)는 제외한다.
    final isSof =
        (marker >= 0xC0 && marker <= 0xCF) &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (isSof) {
      final h = (b[i + 5] << 8) | b[i + 6];
      final w = (b[i + 7] << 8) | b[i + 8];
      return (w > 0 && h > 0) ? (width: w, height: h) : null;
    }
    if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    final segment = (b[i + 2] << 8) | b[i + 3];
    if (segment < 2) return null;
    i += 2 + segment;
  }
  return null;
}

int _be32(Uint8List b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

/// 원본 크기에 맞는 축소 목표 크기. 긴 변을 [maxEdge]에 맞추고 비율을 지키며,
/// 원본이 이미 작으면 키우지 않는다.
({int width, int height}) thumbnailTargetSize({
  required int srcWidth,
  required int srcHeight,
  required int maxEdge,
}) {
  if (srcWidth <= 0 || srcHeight <= 0) {
    return (width: maxEdge, height: maxEdge);
  }

  final longest = srcWidth > srcHeight ? srcWidth : srcHeight;
  if (longest <= maxEdge) {
    return (width: srcWidth, height: srcHeight);
  }

  final scale = maxEdge / longest;
  // 아주 납작한 이미지에서 짧은 변이 0으로 내려가면 디코더가 던진다.
  final width = (srcWidth * scale).round().clamp(1, maxEdge);
  final height = (srcHeight * scale).round().clamp(1, maxEdge);
  return (width: width, height: height);
}

/// 업로드 직전 원본 바이트에서 그리드용 축소본을 만든다.
///
/// 디코딩과 축소는 `dart:ui`가 한다 — 플랫폼 코덱(Android Bitmap / iOS
/// ImageIO / 웹 브라우저)이라 12MP 사진도 수십 ms에 끝나고, 순수 Dart 디코더처럼
/// UI 아이솔레이트를 1~2초씩 잡아먹지 않는다. `package:image`는 이미 512px로
/// 줄어든 RGBA 버퍼를 JPEG로 감싸는 마지막 한 단계에만 쓴다.
class MediaThumbnailer {
  const MediaThumbnailer();

  /// 실패하면 null. 썸네일은 부가 기능이라, 여기서 던지면 업로드 자체가 깨진다.
  /// 영상·손상된 파일·지원하지 않는 포맷은 모두 조용히 null로 떨어진다.
  Future<Uint8List?> buildJpeg(
    Uint8List source, {
    int maxEdge = kThumbnailMaxEdge,
    int quality = kThumbnailQuality,
  }) async {
    if (source.isEmpty) {
      return null;
    }

    ui.Image? image;
    try {
      final size = probeImageSize(source);

      final ui.Codec codec;
      if (size != null) {
        final target = thumbnailTargetSize(
          srcWidth: size.width,
          srcHeight: size.height,
          maxEdge: maxEdge,
        );
        codec = await ui.instantiateImageCodec(
          source,
          targetWidth: target.width,
          targetHeight: target.height,
        );
      } else {
        // 헤더를 못 읽는 포맷(HEIC 등)은 긴 변을 모르니 가로만 맞춘다.
        // 세로 사진이면 높이가 maxEdge를 조금 넘을 수 있지만, 원본을 그대로
        // 붙이는 것보다는 훨씬 낫다.
        codec = await ui.instantiateImageCodec(
          source,
          targetWidth: maxEdge,
          allowUpscaling: false,
        );
      }

      final frame = await codec.getNextFrame();
      image = frame.image;

      final rgba = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (rgba == null) {
        return null;
      }

      final resized = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: rgba.buffer,
        numChannels: 4,
      );

      return img.encodeJpg(resized, quality: quality);
    } catch (error) {
      debugPrint('[Album] thumbnail skipped: $error');
      return null;
    } finally {
      image?.dispose();
    }
  }
}
