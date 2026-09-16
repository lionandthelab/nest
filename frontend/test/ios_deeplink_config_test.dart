import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 소셜 로그인은 전부 브라우저에서 커스텀 스킴으로 앱에 돌아온다.
/// 스킴 등록이 하나라도 빠지면 그 공급자만 조용히 "로그인은 됐는데 앱으로
/// 돌아오지 않는" 상태가 된다 — 빌드도 테스트도 통과하므로 눈으로는 못 잡는다.
void main() {
  test('iOS 에 소셜 로그인 복귀 스킴이 모두 등록되어 있다', () {
    final source = File('ios/Runner/Info.plist').readAsStringSync();
    for (final scheme in [
      'com.lionandthelab.nest', // Supabase OAuth 복귀 (구글/카카오 리다이렉트)
      'nestnaverlogin', // 네이버 브릿지 복귀
      'kakao0a51d6ea6e78e3565b8a45655bca8142', // 카카오 SDK 복귀
    ]) {
      expect(source, contains(scheme), reason: '$scheme 스킴이 없다');
    }
  });

  test('Android 에 소셜 로그인 복귀 스킴이 모두 등록되어 있다', () {
    final source =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(source, contains('nestnaverlogin'));
    expect(source, contains('kakao0a51d6ea6e78e3565b8a45655bca8142'));
    expect(source, contains(r'${appAuthRedirectScheme}'));
  });
}
