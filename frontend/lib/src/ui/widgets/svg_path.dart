import 'dart:ui';

/// 최소 SVG 패스 파서 — 브랜드 로고를 공식 패스 문자열 그대로 그리기 위한 것.
///
/// 손으로 Path 호출로 옮겨 적으면 원본과 대조할 수 없어 로고가 조금씩
/// 틀어져도 잡히지 않는다. 공식 패스를 문자열로 두고 여기서 해석한다.
///
/// 지원: M m L l H h V v C c S s Z z (로고에 필요한 것만).
/// 원호(A)와 2차 베지어(Q)는 쓰지 않으므로 지원하지 않는다 — 조용히
/// 무시하면 모양이 깨지므로 [FormatException] 으로 알린다.
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = _Tokenizer(d);

  var current = Offset.zero;
  var start = Offset.zero;
  Offset? lastCubicControl; // S 가 반사할 직전 제어점
  String? command;

  while (true) {
    final next = tokens.peekCommand();
    if (next != null) {
      command = next;
      tokens.takeCommand();
    } else if (!tokens.hasNumber) {
      break;
    } else if (command == null) {
      throw const FormatException('패스가 명령 없이 시작합니다');
    } else if (command == 'M') {
      command = 'L'; // SVG 규칙: M 뒤 추가 좌표는 L
    } else if (command == 'm') {
      command = 'l';
    }

    final cmd = command;
    final relative = cmd == cmd.toLowerCase();
    Offset resolve(double x, double y) =>
        relative ? Offset(current.dx + x, current.dy + y) : Offset(x, y);

    switch (cmd.toUpperCase()) {
      case 'M':
        current = resolve(tokens.number(), tokens.number());
        start = current;
        path.moveTo(current.dx, current.dy);
        lastCubicControl = null;
      case 'L':
        current = resolve(tokens.number(), tokens.number());
        path.lineTo(current.dx, current.dy);
        lastCubicControl = null;
      case 'H':
        final x = tokens.number();
        current = Offset(relative ? current.dx + x : x, current.dy);
        path.lineTo(current.dx, current.dy);
        lastCubicControl = null;
      case 'V':
        final y = tokens.number();
        current = Offset(current.dx, relative ? current.dy + y : y);
        path.lineTo(current.dx, current.dy);
        lastCubicControl = null;
      case 'C':
        final c1 = resolve(tokens.number(), tokens.number());
        final c2 = resolve(tokens.number(), tokens.number());
        final end = resolve(tokens.number(), tokens.number());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        lastCubicControl = c2;
        current = end;
      case 'S':
        // 직전 제어점을 현재 점 기준으로 반사한 것이 첫 제어점이 된다.
        final c1 = lastCubicControl == null
            ? current
            : Offset(
                2 * current.dx - lastCubicControl.dx,
                2 * current.dy - lastCubicControl.dy,
              );
        final c2 = resolve(tokens.number(), tokens.number());
        final end = resolve(tokens.number(), tokens.number());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        lastCubicControl = c2;
        current = end;
      case 'Z':
        path.close();
        current = start;
        lastCubicControl = null;
      default:
        throw FormatException('지원하지 않는 패스 명령: $cmd');
    }
  }
  return path;
}

/// 숫자와 명령을 뽑아내는 스캐너.
///
/// 공식 패스는 공백을 아낀 축약형이 흔하다 — `-.17.62` 는 -0.17 과 0.62
/// 두 수이고, 쉼표·부호·소수점이 구분자 역할을 겸한다.
class _Tokenizer {
  _Tokenizer(this.source);

  final String source;
  int _pos = 0;

  static const _commands = 'MmLlHhVvCcSsZzQqTtAa';

  void _skipSeparators() {
    while (_pos < source.length) {
      final c = source[_pos];
      if (c == ' ' || c == ',' || c == '\n' || c == '\t' || c == '\r') {
        _pos++;
      } else {
        break;
      }
    }
  }

  String? peekCommand() {
    _skipSeparators();
    if (_pos >= source.length) return null;
    final c = source[_pos];
    return _commands.contains(c) ? c : null;
  }

  void takeCommand() => _pos++;

  bool get hasNumber {
    _skipSeparators();
    if (_pos >= source.length) return false;
    final c = source[_pos];
    return c == '-' || c == '+' || c == '.' || (c.codeUnitAt(0) ^ 0x30) <= 9;
  }

  double number() {
    _skipSeparators();
    final startPos = _pos;
    if (_pos < source.length && (source[_pos] == '-' || source[_pos] == '+')) {
      _pos++;
    }
    var seenDot = false;
    while (_pos < source.length) {
      final c = source[_pos];
      if ((c.codeUnitAt(0) ^ 0x30) <= 9) {
        _pos++;
      } else if (c == '.' && !seenDot) {
        seenDot = true;
        _pos++;
      } else if ((c == 'e' || c == 'E') && _pos + 1 < source.length) {
        _pos++;
        if (source[_pos] == '-' || source[_pos] == '+') _pos++;
      } else {
        break;
      }
    }
    final text = source.substring(startPos, _pos);
    final value = double.tryParse(text);
    if (value == null) {
      throw FormatException('숫자를 읽지 못했습니다: "$text" (위치 $startPos)');
    }
    return value;
  }
}
