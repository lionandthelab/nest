import 'package:flutter/material.dart';

import 'svg_path.dart';

/// 소셜 공급자 로고(심볼)를 각 사 공식 패스 그대로 그린다.
///
/// 글자(G·카·N)로 대신하면 브랜드 가이드 위반이고 사용자도 무슨 버튼인지
/// 덜 알아본다. 이미지 에셋 대신 벡터로 두는 이유는 어떤 크기에서도
/// 뭉개지지 않고, 원본 패스 문자열이 코드에 남아 대조가 가능해서다.
///
/// 색은 각 사가 지정한 브랜드 색이라 NestColors 로 바꾸면 안 된다.

/// 여러 색 조각으로 이루어진 마크를 viewBox 기준으로 그린다.
class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.viewBox, required this.parts});

  /// 원본 SVG 의 viewBox 한 변(정사각 기준).
  final double viewBox;

  /// (패스 문자열, 색) 조각들. 선언 순서대로 겹쳐 그린다.
  final List<(String, Color)> parts;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / viewBox;
    canvas.save();
    canvas.translate(
      (size.width - viewBox * scale) / 2,
      (size.height - viewBox * scale) / 2,
    );
    canvas.scale(scale);
    for (final (d, color) in parts) {
      canvas.drawPath(
        parseSvgPath(d),
        Paint()
          ..color = color
          ..isAntiAlias = true,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.viewBox != viewBox || old.parts != parts;
}

/// Google 'G' — 공식 4색 심볼.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 22});

  final double size;

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _MarkPainter(
        viewBox: 24,
        parts: [
          (
            'M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 '
                '2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z',
            _blue,
          ),
          (
            'M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 '
                '1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 '
                '20.53 7.7 23 12 23z',
            _green,
          ),
          (
            'M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18'
                'C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z',
            _yellow,
          ),
          (
            'M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 '
                '1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 '
                '6.16-4.53z',
            _red,
          ),
        ],
      ),
    );
  }
}

/// 카카오 말풍선 심볼. 노란 배경 위에 올리는 용도라 단색이다.
class KakaoMark extends StatelessWidget {
  const KakaoMark({super.key, this.size = 22, this.color = const Color(0xFF191919)});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(
        viewBox: 18,
        parts: [
          (
            'M9 1C4.58 1 1 3.85 1 7.36c0 2.28 1.52 4.28 3.8 5.4-.17.62-.6 '
                '2.2-.69 2.54-.11.42.15.42.32.3.13-.09 2.08-1.41 '
                '2.93-1.99.53.08 1.08.12 1.64.12 4.42 0 8-2.85 '
                '8-6.37S13.42 1 9 1z',
            color,
          ),
        ],
      ),
    );
  }
}

/// 네이버 'N' 로고마크. 초록 배경 위 흰색이 공식 조합이다.
class NaverMark extends StatelessWidget {
  const NaverMark({super.key, this.size = 18, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(
        viewBox: 20,
        parts: [
          ('M13.5 10.7 6.2 0H0v20h6.5V9.3L13.8 20H20V0h-6.5z', color),
        ],
      ),
    );
  }
}
