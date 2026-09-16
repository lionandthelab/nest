import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/ui/widgets/svg_path.dart';

/// 소셜 로고는 각 사의 공식 SVG 패스를 그대로 쓴다. 손으로 Path 호출로
/// 옮기면 원본과 대조가 불가능해지므로, 패스 문자열을 그대로 두고 파싱한다.
/// 파서가 틀리면 로고가 미묘하게 찌그러지는데 눈으로는 잘 안 잡힌다.
void main() {
  Rect boundsOf(String d) => parseSvgPath(d).getBounds();

  /// 패스의 마지막 점. getBounds() 는 제어점까지 감싼 경계를 주므로
  /// 곡선의 실제 끝점 확인에는 쓸 수 없다.
  Offset endOf(String d) {
    final metrics = parseSvgPath(d).computeMetrics().toList();
    final last = metrics.last;
    return last.getTangentForOffset(last.length)!.position;
  }

  test('절대 좌표 M/L/Z 를 읽는다', () {
    expect(boundsOf('M0 0 L10 0 L10 10 Z'), const Rect.fromLTRB(0, 0, 10, 10));
  });

  test('상대 좌표 m/l 은 직전 점 기준이다', () {
    expect(boundsOf('m5 5 l5 0 l0 5 z'), const Rect.fromLTRB(5, 5, 10, 10));
  });

  test('H/V 와 h/v 로 축 이동한다', () {
    expect(boundsOf('M0 0 H10 V10 Z'), const Rect.fromLTRB(0, 0, 10, 10));
    expect(boundsOf('M0 0 h10 v10 z'), const Rect.fromLTRB(0, 0, 10, 10));
  });

  test('C 3차 베지어의 제어점과 끝점을 모두 읽는다', () {
    // getBounds 는 제어점까지 포함하므로 (0,0)-(10,10) 이 나온다.
    expect(boundsOf('M0 0 C0 10 10 10 10 0'), const Rect.fromLTRB(0, 0, 10, 10));
    final e = endOf('M0 0 C0 10 10 10 10 0');
    expect(e.dx, closeTo(10, 1e-3));
    expect(e.dy, closeTo(0, 1e-3));
  });

  test('하나의 명령에 좌표쌍이 반복되면 같은 명령을 이어서 적용한다', () {
    // l 5 0  5 0  → 오른쪽으로 총 10 이동
    expect(boundsOf('M0 0 l5 0 5 0').right, 10);
  });

  test('S 는 직전 C 의 제어점을 반사해 이어 그린다', () {
    final b = boundsOf('M0 0 C0 5 5 5 5 0 S10 -5 10 0');
    expect(b.right, 10);
    expect(b.top, lessThan(0)); // 반사된 제어점이 위로 뻗는다
    final e = endOf('M0 0 C0 5 5 5 5 0 S10 -5 10 0');
    expect(e.dx, closeTo(10, 1e-3));
  });

  test('음수와 소수점이 붙어 있어도 분리해 읽는다', () {
    // "-.17.62" 는 -0.17 과 0.62 두 수다 (공식 패스에 흔한 축약)
    // Path 는 32비트 float 로 저장하므로 오차 허용치를 그에 맞춘다.
    expect(boundsOf('M0 0 l-.17.62').left, closeTo(-0.17, 1e-6));
    expect(boundsOf('M0 0 l-.17.62').bottom, closeTo(0.62, 1e-6));
  });

  test('지수 표기와 쉼표 구분자를 처리한다', () {
    expect(boundsOf('M0,0 L1e1,0').right, 10);
  });

  test('모르는 명령은 조용히 넘어가지 않고 실패한다', () {
    expect(() => parseSvgPath('M0 0 Q5 5 10 0'), throwsFormatException);
  });
}
