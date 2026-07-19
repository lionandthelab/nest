import 'package:flutter_test/flutter_test.dart';

import 'package:nest_frontend/src/services/auth_validation.dart';

void main() {
  group('validateEmailField', () {
    test('정상 이메일은 통과한다', () {
      expect(validateEmailField('goa0517@naver.com'), isNull);
      expect(validateEmailField('  user.name+tag@example.co.kr  '), isNull);
    });

    test('빈 값은 입력 안내를 돌려준다', () {
      expect(validateEmailField(null), '이메일을 입력하세요.');
      expect(validateEmailField('   '), '이메일을 입력하세요.');
    });

    test('도메인의 연속된 점(naver..com)을 걸러낸다', () {
      // 실사용자 가입 실패 사례: goa0517@naver..com
      expect(validateEmailField('goa0517@naver..com'), isNotNull);
    });

    test('로컬 파트의 연속된 점도 걸러낸다', () {
      expect(validateEmailField('a..b@naver.com'), isNotNull);
    });

    test('형식 오류들을 걸러낸다', () {
      for (final bad in [
        'plain',
        'no-at.naver.com',
        'user@',
        '@naver.com',
        'user@naver',
        'user@naver.c',
        'user name@naver.com',
        'user@na ver.com',
        'user@@naver.com',
        'user@.com',
        'user@naver.com.',
      ]) {
        expect(validateEmailField(bad), isNotNull, reason: bad);
      }
    });
  });

  group('koreanAuthMessage', () {
    test('이메일 형식 오류를 한국어로 안내한다', () {
      final msg =
          koreanAuthMessage('Unable to validate email address: invalid format');
      expect(msg, contains('이메일'));
      expect(msg.contains('Unable'), isFalse);
    });

    test('잘못된 로그인 정보를 한국어로 안내한다', () {
      expect(
        koreanAuthMessage('Invalid login credentials'),
        contains('비밀번호'),
      );
    });

    test('이미 가입된 이메일을 한국어로 안내한다', () {
      expect(koreanAuthMessage('User already registered'), contains('가입'));
    });

    test('이메일 미인증을 한국어로 안내한다', () {
      expect(koreanAuthMessage('Email not confirmed'), contains('인증'));
    });

    test('요청 제한을 한국어로 안내한다', () {
      expect(
        koreanAuthMessage(
          'For security purposes, you can only request this after 60 seconds.',
        ),
        contains('잠시 후'),
      );
      expect(
        koreanAuthMessage('Email rate limit exceeded'),
        contains('잠시 후'),
      );
    });

    test('모르는 메시지는 원문을 유지한다', () {
      expect(koreanAuthMessage('Something novel'), 'Something novel');
    });
  });
}
