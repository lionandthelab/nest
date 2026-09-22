import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 그리드에 붙일 축소본의 긴 변(px). 실제 타일은 180pt 안팎이고 DPR 2를 감안해도
/// 360px면 충분하지만, 타임라인·폴더 커버가 더 크게 쓰므로 여유를 둔다.
const int kThumbnailMaxEdge = 512;

/// JPEG 품질. 72 언저리가 512px에서 눈에 띄는 열화 없이 40~50KB로 떨어진다.
const int kThumbnailQuality = 72;

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
      final buffer = await ui.ImmutableBuffer.fromUint8List(source);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);

      final target = thumbnailTargetSize(
        srcWidth: descriptor.width,
        srcHeight: descriptor.height,
        maxEdge: maxEdge,
      );

      final codec = await descriptor.instantiateCodec(
        targetWidth: target.width,
        targetHeight: target.height,
      );
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
