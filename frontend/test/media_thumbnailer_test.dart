import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nest_frontend/src/services/media_thumbnailer.dart';

Uint8List _jpeg({required int width, required int height}) {
  final source = img.Image(width: width, height: height);
  // 단색이면 JPEG가 극단적으로 잘 압축돼 "줄었다" 검증이 무의미해진다.
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      source.setPixelRgb(x, y, (x * 7) % 256, (y * 13) % 256, (x + y) % 256);
    }
  }
  return img.encodeJpg(source, quality: 95);
}

void main() {
  group('thumbnailTargetSize', () {
    test('긴 변을 maxEdge에 맞추고 비율을 지킨다', () {
      expect(
        thumbnailTargetSize(srcWidth: 4000, srcHeight: 3000, maxEdge: 512),
        (width: 512, height: 384),
      );
      expect(
        thumbnailTargetSize(srcWidth: 3000, srcHeight: 4000, maxEdge: 512),
        (width: 384, height: 512),
      );
    });

    test('이미 작은 이미지는 키우지 않는다', () {
      expect(
        thumbnailTargetSize(srcWidth: 300, srcHeight: 200, maxEdge: 512),
        (width: 300, height: 200),
      );
    });

    test('아주 납작한 이미지도 짧은 변이 0이 되지 않는다', () {
      final size = thumbnailTargetSize(
        srcWidth: 4000,
        srcHeight: 3,
        maxEdge: 512,
      );
      expect(size.width, 512);
      expect(size.height, greaterThanOrEqualTo(1));
    });

    test('크기를 알 수 없으면 정사각 maxEdge로 떨어진다', () {
      expect(
        thumbnailTargetSize(srcWidth: 0, srcHeight: 0, maxEdge: 512),
        (width: 512, height: 512),
      );
    });
  });

  group('MediaThumbnailer.buildJpeg', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    test('큰 사진을 512px 이하 JPEG으로 줄인다', () async {
      final source = _jpeg(width: 1600, height: 1200);

      final thumb = await const MediaThumbnailer().buildJpeg(source);

      expect(thumb, isNotNull);
      expect(thumb!.length, lessThan(source.length));

      final decoded = img.decodeJpg(thumb);
      expect(decoded, isNotNull);
      expect(decoded!.width, 512);
      expect(decoded.height, 384);
    });

    test('이미 작은 사진은 크기를 유지한 채 다시 인코딩한다', () async {
      final source = _jpeg(width: 200, height: 150);

      final thumb = await const MediaThumbnailer().buildJpeg(source);

      final decoded = img.decodeJpg(thumb!);
      expect(decoded!.width, 200);
      expect(decoded.height, 150);
    });

    test('이미지가 아닌 바이트는 null을 돌려준다 (업로드는 계속되어야 한다)', () async {
      final notAnImage = Uint8List.fromList(
        List<int>.generate(2048, (i) => i % 256),
      );

      expect(await const MediaThumbnailer().buildJpeg(notAnImage), isNull);
    });

    test('빈 바이트도 던지지 않는다', () async {
      expect(await const MediaThumbnailer().buildJpeg(Uint8List(0)), isNull);
    });
  });

  group('probeImageSize', () {
    test('PNG 헤더에서 크기를 읽는다', () {
      final png = img.encodePng(img.Image(width: 640, height: 360));
      expect(probeImageSize(png), (width: 640, height: 360));
    });

    test('JPEG 헤더에서 크기를 읽는다', () {
      final jpg = _jpeg(width: 321, height: 123);
      expect(probeImageSize(jpg), (width: 321, height: 123));
    });

    test('이미지가 아니면 null (호출부가 다른 경로로 떨어진다)', () {
      expect(probeImageSize(Uint8List.fromList(List.filled(64, 7))), isNull);
      expect(probeImageSize(Uint8List(0)), isNull);
    });

    test('잘린 PNG 헤더에도 던지지 않는다', () {
      final png = img.encodePng(img.Image(width: 64, height: 64));
      expect(probeImageSize(Uint8List.fromList(png.take(12).toList())), isNull);
    });
  });

  group('MediaThumbnailer.buildJpeg — 세로 사진', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    test('세로 사진은 긴 변(높이)이 maxEdge에 맞는다', () async {
      final source = _jpeg(width: 1200, height: 1600);

      final thumb = await const MediaThumbnailer().buildJpeg(source);

      final decoded = img.decodeJpg(thumb!);
      expect(decoded!.height, 512);
      expect(decoded.width, 384);
    });
  });
}
