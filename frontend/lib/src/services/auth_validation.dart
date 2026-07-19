/// 인증 폼 검증과 인증 오류 메시지 한국어화(순수 함수).
///
/// 실사용자 가입 실패 사례(`goa0517@naver..com` — 도메인의 연속된 점)가
/// 약한 클라이언트 검증(`@`/`.` 포함 여부만 확인)을 통과해 서버의 영어
/// 오류가 그대로 노출됐다. 제출 전에 형식을 걸러 한국어로 안내한다.
library;

/// 간이 이메일 형식: 로컬파트@도메인. 도메인 라벨은 비어 있을 수 없고
/// 최상위 도메인은 알파벳 2자 이상이어야 한다.
final RegExp _emailPattern = RegExp(
  r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~.\-]+@(?:[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,}$",
);

/// 로그인/가입 폼의 이메일 필드 검증. 통과하면 null, 아니면 한국어 안내.
String? validateEmailField(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return '이메일을 입력하세요.';
  }
  // 연속된 점(naver..com, a..b@ 등)은 형식상 유효하지 않은 대표적 오타.
  if (email.contains('..') || !_emailPattern.hasMatch(email)) {
    return '이메일 형식이 올바르지 않습니다. 오타가 없는지 확인해 주세요.';
  }
  return null;
}

/// Supabase 인증 오류(영어)를 사용자 안내용 한국어로 바꾼다.
/// 모르는 메시지는 원문을 그대로 돌려준다.
String koreanAuthMessage(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('unable to validate email address') ||
      lower.contains('invalid email')) {
    return '이메일 주소 형식이 올바르지 않습니다. 오타가 없는지 확인해 주세요.';
  }
  if (lower.contains('invalid login credentials')) {
    return '이메일 또는 비밀번호가 올바르지 않습니다.';
  }
  if (lower.contains('user already registered') ||
      lower.contains('already been registered')) {
    return '이미 가입된 이메일입니다. 로그인하거나 비밀번호 재설정을 이용해 주세요.';
  }
  if (lower.contains('email not confirmed')) {
    return '이메일 인증이 완료되지 않았습니다. 메일함의 인증 링크를 확인해 주세요.';
  }
  if (lower.contains('password should be at least')) {
    return '비밀번호가 너무 짧습니다. 8자 이상으로 입력해 주세요.';
  }
  if (lower.contains('for security purposes') ||
      lower.contains('rate limit')) {
    return '요청이 너무 잦습니다. 잠시 후 다시 시도해 주세요.';
  }
  return message;
}
